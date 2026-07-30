import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/main_shell.dart' show MainShell;
import 'package:zelp/screens/store_item_detail_screen.dart';
import 'package:zelp/screens/widgets/compact_watch_picker.dart';
import 'package:zelp/screens/widgets/error_banner.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_notification_service.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/file_download_notifier.dart';
import 'package:zelp/services/file_share_service.dart';
import 'package:zelp/services/firmware_file_downloader.dart';
import 'package:zelp/services/store_browse_prefs.dart';
import 'package:zelp/services/store_catalog_service.dart';

/// Browse / download apps or watchfaces saved on this device for a watch model.
class StoreCatalogScreen extends StatefulWidget {
  const StoreCatalogScreen({
    required this.entryType,
    super.key,
    this.catalog,
    this.catalogService,
    this.deviceUsageStore,
    this.downloadStorage,
    this.downloader,
    this.notificationService,
    this.browsePrefs,
    this.loadIcons = true,
    this.deviceUsageEpoch = 0,
  });

  final StoreEntryType entryType;
  final DeviceCatalog? catalog;
  final StoreCatalogService? catalogService;
  final DeviceUsageStore? deviceUsageStore;
  final DownloadStorage? downloadStorage;
  final FirmwareFileDownloader? downloader;
  final DownloadNotificationService? notificationService;
  final StoreBrowsePrefs? browsePrefs;

  /// When false, list tiles skip [NetworkImage] (unit tests).
  final bool loadIcons;

  /// Bumped by [MainShell] when this tab is opened so selection re-syncs to
  /// the shared most-recently-used watch.
  final int deviceUsageEpoch;

  @override
  State<StoreCatalogScreen> createState() => _StoreCatalogScreenState();
}

class _StoreCatalogScreenState extends State<StoreCatalogScreen> {
  late final DeviceCatalog _devices = widget.catalog ?? DeviceCatalog();
  late final StoreCatalogService _catalog = widget.catalogService ?? StoreCatalogService();
  late final DeviceUsageStore _usage = widget.deviceUsageStore ?? DeviceUsageStore();
  late final DownloadStorage _downloads = widget.downloadStorage ?? DownloadStorage();
  late final FirmwareFileDownloader _downloader = widget.downloader ?? FirmwareFileDownloader(storage: _downloads);
  late final FileDownloadNotifier _downloadNotifier = FileDownloadNotifier.store(
    widget.notificationService ?? const NoopDownloadNotificationService(),
    singular: widget.entryType.singular,
  );
  late final StoreBrowsePrefs _browsePrefs = widget.browsePrefs ?? StoreBrowsePrefs();
  final FileShareService _share = const FileShareService();
  final TextEditingController _itemSearch = TextEditingController();
  Timer? _searchDebounce;
  int _reloadGeneration = 0;

  List<WatchModel> _watches = <WatchModel>[];
  WatchModel? _selected;
  List<StoreItem> _items = <StoreItem>[];
  StoreCatalogQuery _query = const StoreCatalogQuery();
  List<String> _categories = <String>[];
  List<String> _publishers = <String>[];
  bool _loadingDevices = true;
  bool _loadingItems = false;
  bool _refreshing = false;
  bool _downloading = false;
  String? _status;
  String? _error;
  String? _outputFolderLabel;
  final Map<String, ExistingDownloadMatch> _existingByKey = <String, ExistingDownloadMatch>{};
  final List<SavedExport> _downloaded = <SavedExport>[];

  String get _title => widget.entryType.label;

  AssetKind get _assetKind => switch (widget.entryType) {
    StoreEntryType.lightapp => AssetKind.app,
    StoreEntryType.watch => AssetKind.watchface,
  };

  @override
  void initState() {
    super.initState();
    _itemSearch.addListener(_onSearchChanged);
    unawaited(_loadDevices());
    unawaited(_loadOutputLabel());
    unawaited(_loadBrowsePrefs());
  }

  @override
  void didUpdateWidget(covariant StoreCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceUsageEpoch != widget.deviceUsageEpoch) {
      unawaited(_syncToSharedMru());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _itemSearch
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadBrowsePrefs() async {
    final StoreCatalogQuery saved = await _browsePrefs.load(widget.entryType);
    if (!mounted) return;
    setState(() => _query = saved);
  }

  Future<void> _persistQuery() async {
    await _browsePrefs.save(widget.entryType, _query);
  }

  void _onSearchChanged() {
    final String text = _itemSearch.text;
    if (text == _query.text) return;
    setState(() => _query = _query.copyWith(text: text));
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      unawaited(_reloadItems(showLoading: false));
    });
  }

  Future<void> _loadOutputLabel() async {
    try {
      final OutputFolder folder = await _downloads.loadSettings().timeout(
        const Duration(seconds: 3),
      );
      if (!mounted) return;
      setState(() => _outputFolderLabel = folder.label);
    } on Exception catch (_) {
      // Folder resolution can hang in tests without path_provider mocks.
    }
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loadingDevices = true;
      _error = null;
    });
    try {
      final List<WatchModel> watches = await _devices.load();
      final List<WatchModel> ordered = await _usage.sortWatches(
        watches: watches,
        deviceIdOf: (WatchModel w) => w.deviceId,
      );
      final WatchModel? preferred = await _usage.preferMostRecentWatch(
        watches: ordered,
        deviceIdOf: (WatchModel w) => w.deviceId,
      );
      if (!mounted) return;
      setState(() {
        _watches = ordered;
        _loadingDevices = false;
      });
      if (preferred != null) {
        await _applyWatch(preferred, recordUsage: false);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDevices = false;
        _error = e is ZelpException ? e.message : e.toString();
      });
    }
  }

  Future<void> _syncToSharedMru() async {
    if (_watches.isEmpty) return;
    final List<WatchModel> ordered = await _usage.sortWatches(
      watches: _watches,
      deviceIdOf: (WatchModel w) => w.deviceId,
    );
    final WatchModel? preferred = await _usage.preferMostRecentWatch(
      watches: ordered,
      deviceIdOf: (WatchModel w) => w.deviceId,
    );
    if (!mounted) return;
    setState(() => _watches = ordered);
    if (preferred != null && preferred.deviceId != _selected?.deviceId) {
      await _applyWatch(preferred, recordUsage: false);
    }
  }

  Future<void> _selectWatch(WatchModel watch) => _applyWatch(watch, recordUsage: true);

  Future<void> _applyWatch(
    WatchModel watch, {
    required bool recordUsage,
  }) async {
    if (recordUsage) await _usage.touchWatch(watch.deviceId);
    if (!mounted) return;
    setState(() {
      if (recordUsage) {
        _watches = List<WatchModel>.of(_watches)
          ..removeWhere((WatchModel w) => w.deviceId == watch.deviceId)
          ..insert(0, watch);
      }
      _selected = watch;
      _error = null;
      _status = null;
    });
    await _reloadItems();
  }

  Future<void> _reloadItems({bool showLoading = true}) async {
    final WatchModel? watch = _selected;
    if (watch == null) return;
    if (showLoading) _searchDebounce?.cancel();
    final int generation = ++_reloadGeneration;
    if (showLoading) {
      setState(() {
        _loadingItems = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }
    try {
      final List<StoreItem> items = await _catalog.browse(
        entryType: widget.entryType,
        deviceId: watch.deviceId,
        query: _query,
      );
      final DateTime? refreshed = await _catalog.lastRefreshedAt(
        entryType: widget.entryType,
        deviceId: watch.deviceId,
      );
      final List<String> categories = await _catalog.categories(
        entryType: widget.entryType,
        deviceId: watch.deviceId,
      );
      final List<String> publishers = await _catalog.publishers(
        entryType: widget.entryType,
        deviceId: watch.deviceId,
      );
      if (!mounted || generation != _reloadGeneration) return;
      setState(() {
        _items = items;
        _categories = categories;
        _publishers = publishers;
        _loadingItems = false;
        _status = items.isEmpty && !_query.hasActiveFilters
            ? 'Nothing saved for this watch yet. Tap Update list '
                  '(uses your signed-in account).'
            : '${items.length} shown'
                  '${refreshed == null ? '' : ' · last updated ${_formatTime(refreshed)}'}';
      });
      // Do not block catalog browse on folder scans / path_provider.
      unawaited(_refreshExistingMatches(items));
    } on Exception catch (e) {
      if (!mounted || generation != _reloadGeneration) return;
      setState(() {
        _loadingItems = false;
        _error = e is ZelpException ? e.message : e.toString();
      });
    }
  }

  Future<void> _refreshExistingMatches(List<StoreItem> items) async {
    final Map<String, ExistingDownloadMatch> map = <String, ExistingDownloadMatch>{};
    for (final StoreItem item in items) {
      if (!item.hasDownload) continue;
      try {
        final ExistingDownloadMatch? match = await _downloads
            .findExistingDownload(
              expectedFileName: item.suggestedFileName,
              kind: _assetKind,
            )
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (match != null) {
          map[_itemKey(item)] = match;
        }
      } on Exception catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _existingByKey
        ..clear()
        ..addAll(map);
    });
  }

  String _itemKey(StoreItem item) => '${item.appId}|${item.version}|${item.deviceId}';

  Future<void> _refreshCatalog() async {
    final WatchModel? watch = _selected;
    if (watch == null) {
      setState(() => _error = 'Choose a watch before updating the list.');
      return;
    }

    setState(() {
      _refreshing = true;
      _error = null;
      _status = 'Signing in and updating ${widget.entryType.label.toLowerCase()}…';
    });

    try {
      await _usage.touchWatch(watch.deviceId);
      final StoreRefreshResult result = await _catalog.refreshForWatch(
        watch: watch,
        entryType: widget.entryType,
        onProgress:
            ({
              required int listed,
              required int detailed,
              required int skipped,
              required int total,
            }) {
              if (!mounted) return;
              setState(() {
                if (detailed == 0 && skipped == 0) {
                  _status = 'Reading list… $listed ${widget.entryType.label.toLowerCase()}';
                } else {
                  _status = 'Updating details $detailed · skipped $skipped / $total';
                }
              });
            },
      );
      if (!mounted) return;
      setState(() {
        _status =
            'Saved ${result.itemCount} ${widget.entryType.label.toLowerCase()} '
            'for ${watch.name}'
            '${result.skippedDetailCount > 0 ? ' (${result.skippedDetailCount} unchanged)' : ''}.';
      });
      await _reloadItems();
    } on ZelpException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = null;
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _toggleStar(StoreItem item) async {
    final WatchModel? watch = _selected;
    if (watch == null) return;
    final StoreItem? updated = await _catalog.db.setStarred(
      appId: item.appId,
      entryType: item.entryType,
      deviceId: watch.deviceId,
      starred: !item.isStarred,
      seenVersion: item.version,
    );
    if (!mounted || updated == null) return;
    await _reloadItems();
  }

  Future<void> _markStarSeen(StoreItem item) async {
    await _catalog.db.markStarSeen(item);
    if (!mounted) return;
    await _reloadItems();
  }

  Future<void> _openDetail(StoreItem item) async {
    final WatchModel? watch = _selected;
    final List<String> deviceIds = await _catalog.compatibleDeviceIds(
      appId: item.appId,
      entryType: item.entryType,
    );
    final Map<String, String> nameById = <String, String>{for (final WatchModel w in _watches) w.deviceId: w.name};
    final List<String> alsoOn = compatibleWatchLabels(
      deviceIds: deviceIds,
      currentDeviceId: watch?.deviceId ?? item.deviceId,
      nameByDeviceId: nameById,
    );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _StoreDetailHost(
          initial: item,
          entryType: widget.entryType,
          sizeLabel: _formatSize(item.downloadSize),
          existing: _existingByKey[_itemKey(item)],
          busy: _refreshing || _downloading,
          loadIcon: widget.loadIcons,
          compatibleWatchNames: alsoOn,
          onDownload: (StoreItem current) {
            Navigator.of(context).pop();
            unawaited(_confirmAndDownload(current));
          },
          onShareExisting: _shareExisting,
          onCopyLink: (StoreItem current) => _copy(current.downloadUrl, 'Download link'),
          onToggleStar: (StoreItem current) async {
            await _toggleStar(current);
            final WatchModel? selected = _selected;
            if (selected == null) return current;
            return await _catalog.db.getLatestByAppId(
                  appId: current.appId,
                  entryType: current.entryType,
                  deviceId: selected.deviceId,
                ) ??
                current;
          },
          onMarkUpdateSeen: (StoreItem current) async {
            await _markStarSeen(current);
            final WatchModel? selected = _selected;
            if (selected == null) return current;
            return await _catalog.db.getLatestByAppId(
                  appId: current.appId,
                  entryType: current.entryType,
                  deviceId: selected.deviceId,
                ) ??
                current;
          },
        ),
      ),
    );
    await _reloadItems();
  }

  Future<void> _confirmAndDownload(StoreItem item) async {
    final WatchModel? watch = _selected;
    if (watch == null) return;
    final WatchVariant variant = watch.canonicalVariant;
    if (!item.isFree) {
      setState(() => _error = 'Paid items can’t be downloaded here.');
      return;
    }

    await _usage.touchWatch(watch.deviceId);

    setState(() {
      _downloading = true;
      _error = null;
      _status = 'Preparing ${item.name}…';
    });

    StoreItem resolved;
    try {
      resolved = await _catalog.ensureDownloadUrl(item: item, variant: variant);
    } on ZelpException catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.message;
        _status = null;
      });
      return;
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString();
        _status = null;
      });
      return;
    }

    if (!resolved.hasDownload) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'No download is available for ${resolved.name}.';
        _status = null;
      });
      return;
    }

    final OutputFolder folder = await _downloads.loadSettings();
    if (!mounted) return;

    final String fileName = resolved.suggestedFileName;
    final ExistingDownloadMatch? existing = await _downloads.findExistingDownload(
      expectedFileName: fileName,
      kind: _assetKind,
    );
    if (!mounted) return;

    final bool isRedownload = existing != null;
    final String kind = widget.entryType.singular;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(isRedownload ? 'Download again?' : 'Download $kind?'),
        content: Text(
          isRedownload
              ? '“${existing.file.fileName}” is already in ${folder.label}.\n\n'
                    'Downloading again will replace it. Continue?'
              : 'Download ${resolved.name} (${resolved.version}) as $fileName '
                    'into ${folder.label}?\n\n'
                    'Nothing is downloaded until you confirm.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isRedownload ? 'Replace' : 'Download'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      setState(() => _downloading = false);
      return;
    }

    setState(() {
      _status = 'Downloading $fileName…';
      _outputFolderLabel = folder.label;
    });

    try {
      await _downloadNotifier.begin(
        fileName: fileName,
        version: resolved.version,
      );
      final SavedExport export = await _downloader.downloadToOutputFolder(
        url: Uri.parse(resolved.downloadUrl),
        fileName: fileName,
        kind: _assetKind,
        onProgress: (int received, int? total) {
          unawaited(
            _downloadNotifier.reportProgress(
              fileName: fileName,
              version: resolved.version,
              received: received,
              total: total,
            ),
          );
        },
      );
      await _downloadNotifier.complete(
        fileName: fileName,
        version: resolved.version,
      );
      if (!mounted) return;
      setState(() {
        _downloaded.insert(0, export);
        _status = 'Saved $fileName to ${folder.label}';
        _existingByKey[_itemKey(resolved)] = ExistingDownloadMatch(
          file: StoredOutputFile(
            fileName: export.fileName,
            displayPath: export.displayPath,
            localPath: export.localPath,
          ),
          matchedByChecksum: false,
        );
        final int index = _items.indexWhere(
          (StoreItem e) =>
              e.appId == resolved.appId && e.version == resolved.version && e.deviceId == resolved.deviceId,
        );
        if (index >= 0) {
          _items = List<StoreItem>.of(_items)..[index] = resolved;
        }
      });
      // Downloading auto-stars the item (user can unstar later).
      await _catalog.db.starAfterDownload(
        resolved.copyWith(deviceId: watch.deviceId),
      );
      await _reloadItems();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $fileName'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => _shareExport(export),
          ),
        ),
      );
    } on ZelpException catch (e) {
      await _downloadNotifier.fail(
        fileName: fileName,
        version: resolved.version,
      );
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = null;
      });
    } on Exception catch (e) {
      await _downloadNotifier.fail(
        fileName: fileName,
        version: resolved.version,
      );
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = null;
      });
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareExport(SavedExport export) async {
    try {
      await _share.shareExport(export);
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  Future<void> _shareExisting(ExistingDownloadMatch match) async {
    final String? local = match.file.localPath;
    if (local == null || local.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t find the file to share')),
      );
      return;
    }
    await _shareExport(
      SavedExport(
        fileName: match.file.fileName,
        displayPath: match.file.displayPath,
        localPath: local,
      ),
    );
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _openFilterSheet() async {
    StoreCatalogQuery draft = _query;
    final StoreCatalogQuery? applied = await showModalBottomSheet<StoreCatalogQuery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Filter & sort',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownMenu<StoreSortBy>(
                initialSelection: draft.sortBy,
                label: const Text('Sort by'),
                expandedInsets: EdgeInsets.zero,
                onSelected: (StoreSortBy? v) {
                  if (v == null) return;
                  setModal(() => draft = draft.copyWith(sortBy: v));
                },
                dropdownMenuEntries: StoreSortBy.values
                    .map((StoreSortBy e) => DropdownMenuEntry<StoreSortBy>(value: e, label: e.label))
                    .toList(),
              ),
              const SizedBox(height: 8),
              SegmentedButton<StoreSortDirection>(
                segments: const <ButtonSegment<StoreSortDirection>>[
                  ButtonSegment<StoreSortDirection>(
                    value: StoreSortDirection.ascending,
                    label: Text('A → Z / Low'),
                  ),
                  ButtonSegment<StoreSortDirection>(
                    value: StoreSortDirection.descending,
                    label: Text('Z → A / High'),
                  ),
                ],
                selected: <StoreSortDirection>{draft.sortDirection},
                onSelectionChanged: (Set<StoreSortDirection> s) {
                  setModal(
                    () => draft = draft.copyWith(sortDirection: s.first),
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownMenu<String?>(
                initialSelection: draft.categoryName,
                label: const Text('Category'),
                expandedInsets: EdgeInsets.zero,
                onSelected: (String? v) {
                  setModal(() {
                    draft = v == null || v.isEmpty
                        ? draft.copyWith(clearCategory: true)
                        : draft.copyWith(categoryName: v);
                  });
                },
                dropdownMenuEntries: <DropdownMenuEntry<String?>>[
                  const DropdownMenuEntry<String?>(value: null, label: 'Any'),
                  ..._categories.map(
                    (String c) => DropdownMenuEntry<String?>(value: c, label: c),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownMenu<String?>(
                initialSelection: draft.publisherName,
                label: const Text('Author'),
                expandedInsets: EdgeInsets.zero,
                onSelected: (String? v) {
                  setModal(() {
                    draft = v == null || v.isEmpty
                        ? draft.copyWith(clearPublisher: true)
                        : draft.copyWith(publisherName: v);
                  });
                },
                dropdownMenuEntries: <DropdownMenuEntry<String?>>[
                  const DropdownMenuEntry<String?>(value: null, label: 'Any'),
                  ..._publishers.map(
                    (String p) => DropdownMenuEntry<String?>(value: p, label: p),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Price', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<StorePriceFilter>(
                segments: StorePriceFilter.values
                    .map(
                      (StorePriceFilter e) => ButtonSegment<StorePriceFilter>(value: e, label: Text(e.label)),
                    )
                    .toList(),
                selected: <StorePriceFilter>{draft.price},
                onSelectionChanged: (Set<StorePriceFilter> s) {
                  setModal(() => draft = draft.copyWith(price: s.first));
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Starred only'),
                value: draft.starredOnly,
                onChanged: (bool v) {
                  setModal(() => draft = draft.copyWith(starredOnly: v));
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () {
                      setModal(() {
                        draft = StoreCatalogQuery(
                          text: draft.text,
                        );
                      });
                    },
                    child: const Text('Clear filters'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, draft),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (applied == null || !mounted) return;
    setState(() => _query = applied.copyWith(text: _itemSearch.text));
    await _persistQuery();
    await _reloadItems();
  }

  String _formatTime(DateTime time) {
    final DateTime local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool busy = _refreshing || _downloading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Filter & sort',
            onPressed: _selected == null || busy ? null : _openFilterSheet,
            icon: Badge(
              isLabelVisible: _query.hasSheetFilters || _query.sortBy != StoreSortBy.name,
              child: const Icon(Icons.tune),
            ),
          ),
          IconButton(
            tooltip: 'Update list',
            onPressed: busy || _selected == null ? null : _refreshCatalog,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loadingDevices
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  'Saved on this device for the watch you choose. '
                  'Tap Update list when you want the latest from your account.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                CompactWatchPicker(
                  watches: _watches,
                  selected: _selected,
                  enabled: !busy,
                  onSelected: _selectWatch,
                ),
                if (_outputFolderLabel != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Saving to $_outputFolderLabel',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _error!),
                ],
                if (_status != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_status!, style: theme.textTheme.bodyMedium),
                ],
                if (_selected != null) ...<Widget>[
                  const SizedBox(height: 16),
                  if (_query.hasSheetFilters || _query.sortBy != StoreSortBy.name) ...<Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        if (_query.categoryName != null)
                          InputChip(
                            label: Text(_query.categoryName!),
                            onDeleted: () async {
                              setState(
                                () => _query = _query.copyWith(
                                  clearCategory: true,
                                ),
                              );
                              await _persistQuery();
                              await _reloadItems();
                            },
                          ),
                        if (_query.publisherName != null)
                          InputChip(
                            label: Text(_query.publisherName!),
                            onDeleted: () async {
                              setState(
                                () => _query = _query.copyWith(
                                  clearPublisher: true,
                                ),
                              );
                              await _persistQuery();
                              await _reloadItems();
                            },
                          ),
                        if (_query.price != StorePriceFilter.all)
                          InputChip(
                            label: Text(_query.price.label),
                            onDeleted: () async {
                              setState(
                                () => _query = _query.copyWith(
                                  price: StorePriceFilter.all,
                                ),
                              );
                              await _persistQuery();
                              await _reloadItems();
                            },
                          ),
                        if (_query.starredOnly)
                          InputChip(
                            label: const Text('Starred'),
                            onDeleted: () async {
                              setState(
                                () => _query = _query.copyWith(
                                  starredOnly: false,
                                ),
                              );
                              await _persistQuery();
                              await _reloadItems();
                            },
                          ),
                        InputChip(
                          label: Text(
                            '${_query.sortBy.label} · '
                            '${_query.sortDirection == StoreSortDirection.ascending ? '↑' : '↓'}',
                          ),
                          onPressed: _openFilterSheet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    key: const ValueKey<String>('store_item_search'),
                    controller: _itemSearch,
                    decoration: InputDecoration(
                      labelText: 'Search ${widget.entryType.label.toLowerCase()}',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingItems)
                    const Center(child: CircularProgressIndicator())
                  else if (_items.isEmpty)
                    Text(
                      _query.hasActiveFilters || _itemSearch.text.trim().isNotEmpty
                          ? 'No matches.'
                          : 'Nothing here yet for ${_selected!.name}. Tap Update list.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else ...<Widget>[
                    if (_items.any((StoreItem e) => e.hasStarredUpdate)) ...<Widget>[
                      Text(
                        'Updates for starred',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These starred items have a newer version since you last looked.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      for (final StoreItem item in _items.where(
                        (StoreItem e) => e.hasStarredUpdate,
                      ))
                        _StoreItemTile(
                          item: item,
                          entryType: widget.entryType,
                          loadIcon: widget.loadIcons,
                          existing: _existingByKey[_itemKey(item)],
                          busy: busy,
                          sizeLabel: _formatSize(item.downloadSize),
                          emphasizeUpdate: true,
                          onOpen: () => _openDetail(item),
                          onDownload: () => _confirmAndDownload(item),
                          onToggleStar: () => _toggleStar(item),
                        ),
                      const SizedBox(height: 12),
                      Text('All items', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                    ],
                    for (final StoreItem item in _items)
                      _StoreItemTile(
                        item: item,
                        entryType: widget.entryType,
                        loadIcon: widget.loadIcons,
                        existing: _existingByKey[_itemKey(item)],
                        busy: busy,
                        sizeLabel: _formatSize(item.downloadSize),
                        onOpen: () => _openDetail(item),
                        onDownload: () => _confirmAndDownload(item),
                        onToggleStar: () => _toggleStar(item),
                      ),
                  ],
                  if (_downloaded.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Downloaded this session',
                      style: theme.textTheme.titleSmall,
                    ),
                    for (final SavedExport export in _downloaded)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(export.fileName),
                        subtitle: Text(export.displayPath),
                        trailing: IconButton(
                          tooltip: 'Share',
                          icon: const Icon(Icons.share),
                          onPressed: () => _shareExport(export),
                        ),
                      ),
                  ],
                ],
              ],
            ),
    );
  }
}

class _StoreItemTile extends StatelessWidget {
  const _StoreItemTile({
    required this.item,
    required this.entryType,
    required this.loadIcon,
    required this.existing,
    required this.busy,
    required this.sizeLabel,
    required this.onOpen,
    required this.onDownload,
    required this.onToggleStar,
    this.emphasizeUpdate = false,
  });

  final StoreItem item;
  final StoreEntryType entryType;
  final bool loadIcon;
  final ExistingDownloadMatch? existing;
  final bool busy;
  final String sizeLabel;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onToggleStar;
  final bool emphasizeUpdate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> subtitleParts = <String>[
      if (item.version.isNotEmpty) 'v${item.version}',
      if (item.publisherName.isNotEmpty) item.publisherName,
      if (item.categoryName.isNotEmpty) item.categoryName,
      if (sizeLabel.isNotEmpty) sizeLabel,
      if (item.updatedAt != null) 'Updated ${item.updatedAt!.toLocal().toIso8601String().split('T').first}',
      if (!item.isFree) 'Paid',
      if (item.isRemoved) 'Removed',
      if (existing != null) 'Downloaded',
      if (item.hasStarredUpdate) 'Updated',
    ];

    Widget? leading;
    if (loadIcon && item.iconUrl.isNotEmpty) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(
          entryType == StoreEntryType.watch ? 12 : 8,
        ),
        child: Image.network(
          item.iconUrl,
          width: entryType == StoreEntryType.watch ? 56 : 40,
          height: entryType == StoreEntryType.watch ? 56 : 40,
          fit: BoxFit.cover,
          errorBuilder: (_, Object error, StackTrace? stackTrace) => Icon(
            entryType == StoreEntryType.watch ? Icons.watch : Icons.apps,
          ),
        ),
      );
    } else {
      leading = Icon(
        entryType == StoreEntryType.watch ? Icons.watch : Icons.apps,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: emphasizeUpdate ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.45) : null,
      child: ListTile(
        leading: leading,
        title: Text(item.name),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: item.isStarred ? 'Remove star' : 'Star',
              onPressed: busy ? null : onToggleStar,
              icon: Icon(
                item.isStarred ? Icons.star : Icons.star_border,
                color: item.isStarred ? theme.colorScheme.primary : null,
              ),
            ),
            if (!item.isFree)
              Tooltip(
                message: 'Paid',
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.paid,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              IconButton(
                tooltip: existing != null ? 'Download again' : 'Download',
                onPressed: busy || item.isRemoved ? null : onDownload,
                icon: Icon(existing != null ? Icons.refresh : Icons.download),
              ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _StoreDetailHost extends StatefulWidget {
  const _StoreDetailHost({
    required this.initial,
    required this.entryType,
    required this.sizeLabel,
    required this.existing,
    required this.busy,
    required this.loadIcon,
    required this.compatibleWatchNames,
    required this.onDownload,
    required this.onShareExisting,
    required this.onCopyLink,
    required this.onToggleStar,
    required this.onMarkUpdateSeen,
  });

  final StoreItem initial;
  final StoreEntryType entryType;
  final String sizeLabel;
  final ExistingDownloadMatch? existing;
  final bool busy;
  final bool loadIcon;
  final List<String> compatibleWatchNames;
  final void Function(StoreItem item) onDownload;
  final void Function(ExistingDownloadMatch match) onShareExisting;
  final void Function(StoreItem item) onCopyLink;
  final Future<StoreItem> Function(StoreItem item) onToggleStar;
  final Future<StoreItem> Function(StoreItem item) onMarkUpdateSeen;

  @override
  State<_StoreDetailHost> createState() => _StoreDetailHostState();
}

class _StoreDetailHostState extends State<_StoreDetailHost> {
  late StoreItem _item = widget.initial;

  @override
  Widget build(BuildContext context) => StoreItemDetailScreen(
    item: _item,
    entryType: widget.entryType,
    sizeLabel: widget.sizeLabel,
    existing: widget.existing,
    busy: widget.busy,
    loadIcon: widget.loadIcon,
    compatibleWatchNames: widget.compatibleWatchNames,
    onDownload: () => widget.onDownload(_item),
    onShareExisting: widget.onShareExisting,
    onCopyLink: _item.hasDownload ? () => widget.onCopyLink(_item) : null,
    onToggleStar: () async {
      final StoreItem next = await widget.onToggleStar(_item);
      if (mounted) setState(() => _item = next);
    },
    onMarkUpdateSeen: _item.hasStarredUpdate
        ? () async {
            final StoreItem next = await widget.onMarkUpdateSeen(_item);
            if (mounted) setState(() => _item = next);
          }
        : null,
  );
}
