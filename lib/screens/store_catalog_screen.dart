import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/domain/primitives/byte_size.dart';
import 'package:zelp/domain/primitives/local_datetime.dart';
import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/domain/store/store_device_cache_meta.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/main_shell.dart' show MainShell;
import 'package:zelp/screens/tab_epoch_sync.dart';
import 'package:zelp/screens/widgets/clipboard_actions.dart';
import 'package:zelp/screens/widgets/compact_watch_picker.dart';
import 'package:zelp/screens/widgets/error_banner.dart';
import 'package:zelp/screens/widgets/output_folder_download.dart';
import 'package:zelp/screens/widgets/restorable_scroll_body.dart';
import 'package:zelp/screens/widgets/settings_action.dart';
import 'package:zelp/screens/widgets/store_catalog/collected_data_summary.dart';
import 'package:zelp/screens/widgets/store_catalog/store_catalog_filter_sheet.dart';
import 'package:zelp/screens/widgets/store_catalog/store_detail_host.dart';
import 'package:zelp/screens/widgets/store_catalog/store_item_tile.dart';
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
    this.settingsEpoch = 0,
    this.deviceUsageEpoch = 0,
    this.onOpenSettings,
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

  /// Bumped by [MainShell] when Settings closes so "already downloaded"
  /// matches refresh against the output folder.
  final int settingsEpoch;

  /// Bumped by [MainShell] when this tab is opened so selection re-syncs to
  /// the shared most-recently-used watch.
  final int deviceUsageEpoch;

  /// Opens the Settings screen (account + download folder).
  final VoidCallback? onOpenSettings;

  @override
  State<StoreCatalogScreen> createState() => _StoreCatalogScreenState();
}

class _StoreCatalogScreenState extends State<StoreCatalogScreen> {
  late final DeviceCatalog _devices = widget.catalog ?? DeviceCatalog();

  /// Prefer injecting from [MainShell] so Apps + Watchfaces share one Drift DB.
  late final StoreCatalogService _catalog = widget.catalogService ?? StoreCatalogService();
  late final bool _ownsCatalog = widget.catalogService == null;
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
  List<StoreDeviceCacheMeta> _collectedDevices = <StoreDeviceCacheMeta>[];
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
    applyTabEpochChanges(
      oldSettingsEpoch: oldWidget.settingsEpoch,
      settingsEpoch: widget.settingsEpoch,
      oldDeviceUsageEpoch: oldWidget.deviceUsageEpoch,
      deviceUsageEpoch: widget.deviceUsageEpoch,
      onSettingsEpoch: () {
        unawaited(_loadOutputLabel());
        setState(() {
          _existingByKey.clear();
          _downloaded.clear();
        });
        if (_items.isNotEmpty) {
          unawaited(_refreshExistingMatches(_items));
        }
      },
      onDeviceUsageEpoch: () => unawaited(_syncToSharedMru()),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _itemSearch
      ..removeListener(_onSearchChanged)
      ..dispose();
    if (_ownsCatalog) {
      unawaited(_catalog.close());
    }
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

  Future<void> _applyQuery(StoreCatalogQuery Function(StoreCatalogQuery) update) async {
    setState(() => _query = update(_query));
    await _persistQuery();
    await _reloadItems();
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
      final OutputFolder folder = await _downloads
          .loadSettings(force: true)
          .timeout(
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
      final ({List<WatchModel> ordered, WatchModel? preferred}) mru = await _usage.orderedWatchesWithPreferred(
        watches: watches,
        deviceIdOf: (WatchModel w) => w.deviceId,
      );
      if (!mounted) return;
      setState(() {
        _watches = mru.ordered;
        _loadingDevices = false;
      });
      unawaited(_reloadCollectedDevices());
      if (mru.preferred != null) {
        await _applyWatch(mru.preferred!, recordUsage: false);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDevices = false;
        _error = exceptionMessage(e);
      });
    }
  }

  Future<void> _syncToSharedMru() async {
    final ({List<WatchModel> ordered, WatchModel? preferred})? mru = await orderedWatchesForSharedMru(
      usage: _usage,
      watches: _watches,
    );
    if (mru == null || !mounted) return;
    setState(() => _watches = mru.ordered);
    if (mru.preferred != null && mru.preferred!.deviceId != _selected?.deviceId) {
      await _applyWatch(mru.preferred!, recordUsage: false);
    }
  }

  Future<void> _reloadCollectedDevices() async {
    try {
      final List<StoreDeviceCacheMeta> collected = await _catalog.listCollectedDevices(
        entryType: widget.entryType,
      );
      if (!mounted) return;
      setState(() => _collectedDevices = collected);
    } on Exception catch (_) {
      // Browse can proceed without the summary; keep prior list if any.
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
        _watches = DeviceUsageStore.bringWatchToFront(
          watches: _watches,
          watch: watch,
          deviceIdOf: (WatchModel w) => w.deviceId,
        );
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
                  '${refreshed == null ? '' : ' · last updated ${formatLocalDateTime(refreshed)}'}';
      });
      // Do not block catalog browse on folder scans / path_provider.
      unawaited(_refreshExistingMatches(items));
    } on Exception catch (e) {
      if (!mounted || generation != _reloadGeneration) return;
      setState(() {
        _loadingItems = false;
        _error = exceptionMessage(e);
      });
    }
  }

  Future<void> _refreshExistingMatches(List<StoreItem> items) async {
    final Map<String, ExistingDownloadMatch> map = await _downloads.scanExistingMatches(
      items
          .where((StoreItem item) => item.hasDownload)
          .map(
            (StoreItem item) => ExistingDownloadProbe(
              key: _itemKey(item),
              expectedFileName: item.suggestedFileName(
                semantic: _downloads.semanticNames,
              ),
              kind: _assetKind,
              timeout: const Duration(seconds: 3),
            ),
          ),
    );
    if (!mounted) return;
    setState(() {
      _existingByKey
        ..clear()
        ..addAll(map);
    });
  }

  String _itemKey(StoreItem item) => '${item.appId}|${item.version}|${item.deviceId}';

  Future<void> _onPullRefresh() async {
    if (_selected == null || _refreshing || _downloading) return;
    await _refreshCatalog();
  }

  Future<void> _refreshCatalog() async {
    final WatchModel? watch = _selected;
    if (watch == null) {
      setState(() => _error = 'Choose a watch before updating the list.');
      return;
    }
    if (_refreshing) return;

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
      await _reloadCollectedDevices();
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
        builder: (BuildContext context) => StoreDetailHost(
          initial: item,
          entryType: widget.entryType,
          sizeLabel: formatByteSize(item.downloadSize),
          existing: _existingByKey[_itemKey(item)],
          busy: _refreshing || _downloading,
          loadIcon: widget.loadIcons,
          compatibleWatchNames: alsoOn,
          onDownload: (StoreItem current) {
            Navigator.of(context).pop();
            unawaited(_confirmAndDownload(current));
          },
          onShareExisting: _shareExisting,
          onCopyLink: (StoreItem current) {
            unawaited(
              copyTextWithSnackbar(
                context,
                text: current.downloadUrl,
                label: 'Download link',
              ),
            );
          },
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
      resolved = await _catalog.ensureDownloadUrl(
        item: item,
        variant: variant,
        apiLevel: watch.marketApiLevel,
      );
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
    if (!mounted) return;

    final String fileName = resolved.suggestedFileName(
      semantic: _downloads.semanticNames,
    );
    final String kind = widget.entryType.singular;
    final OutputFolderDownloadResult result = await confirmAndDownloadToOutputFolder(
      context: context,
      downloads: _downloads,
      downloader: _downloader,
      notifier: _downloadNotifier,
      url: resolved.downloadUrl,
      fileName: fileName,
      version: resolved.version,
      kind: _assetKind,
      matchedByChecksumOnSave: false,
      onShare: _shareExport,
      snackbarMessage: (String name) => 'Saved: $name',
      dialogTitle:
          ({
            required bool isRedownload,
            required OutputFolder folder,
            required ExistingDownloadMatch? existing,
          }) => isRedownload ? 'Download again?' : 'Download $kind?',
      dialogContent:
          ({
            required bool isRedownload,
            required OutputFolder folder,
            required ExistingDownloadMatch? existing,
          }) => isRedownload
          ? '“${existing!.file.fileName}” is already in ${folder.label}.\n\n'
                'Downloading again will replace it. Continue?'
          : 'Download ${resolved.name} (${resolved.version}) as $fileName '
                'into ${folder.label}?\n\n'
                'Nothing is downloaded until you confirm.',
      onDownloadStarted: (OutputFolder folder, String name) async {
        if (!mounted) return;
        setState(() {
          _status = 'Downloading $name…';
          _outputFolderLabel = folder.label;
        });
      },
    );
    if (!mounted) return;
    switch (result.status) {
      case OutputFolderDownloadStatus.cancelled:
        setState(() => _downloading = false);
      case OutputFolderDownloadStatus.failed:
        setState(() {
          _downloading = false;
          _error = result.errorMessage;
          _status = null;
        });
      case OutputFolderDownloadStatus.success:
        final SavedExport export = result.export!;
        final OutputFolder folder = result.folder!;
        setState(() {
          _downloaded.insert(0, export);
          _status = 'Saved ${result.fileName} to ${folder.label}';
          _existingByKey[_itemKey(resolved)] = result.match!;
          final int index = _items.indexWhere(
            (StoreItem e) =>
                e.appId == resolved.appId && e.version == resolved.version && e.deviceId == resolved.deviceId,
          );
          if (index >= 0) {
            _items = List<StoreItem>.of(_items)..[index] = resolved;
          }
          _downloading = false;
        });
        // Downloading auto-stars the item (user can unstar later).
        await _catalog.db.starAfterDownload(
          resolved.copyWith(deviceId: watch.deviceId),
        );
        await _reloadItems();
    }
  }

  Future<void> _shareExport(SavedExport export) => shareExportWithSnackbar(
    context,
    share: _share,
    export: export,
  );

  Future<void> _shareExisting(ExistingDownloadMatch match) => shareExistingWithSnackbar(
    context,
    share: _share,
    match: match,
  );

  Future<void> _openFilterSheet() async {
    final StoreCatalogQuery? applied = await showModalBottomSheet<StoreCatalogQuery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => StoreCatalogFilterSheet(
        initial: _query,
        categories: _categories,
        publishers: _publishers,
      ),
    );
    if (applied == null || !mounted) return;
    setState(() => _query = applied.copyWith(text: _itemSearch.text));
    await _persistQuery();
    await _reloadItems();
  }

  StoreItemTile _tileFor(StoreItem item, {required bool busy, bool emphasizeUpdate = false}) => StoreItemTile(
    item: item,
    entryType: widget.entryType,
    loadIcon: widget.loadIcons,
    existing: _existingByKey[_itemKey(item)],
    busy: busy,
    sizeLabel: formatByteSize(item.downloadSize),
    emphasizeUpdate: emphasizeUpdate,
    onOpen: () => _openDetail(item),
    onDownload: () => _confirmAndDownload(item),
    onToggleStar: () => _toggleStar(item),
  );

  List<Widget> _buildCatalogSlivers(ThemeData theme, bool busy) {
    const EdgeInsetsGeometry horizontal = EdgeInsets.symmetric(horizontal: 20);
    final List<StoreItem> starredUpdates = <StoreItem>[
      for (final StoreItem item in _items)
        if (item.hasStarredUpdate) item,
    ];

    final List<Widget> header = <Widget>[
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
      if (_collectedDevices.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        CollectedDataSummary(
          entryType: widget.entryType,
          devices: _collectedDevices,
          watches: _watches,
          selectedDeviceId: _selected?.deviceId,
          enabled: !busy,
          onSelectDeviceId: (String deviceId) {
            WatchModel? match;
            for (final WatchModel watch in _watches) {
              if (watch.deviceId == deviceId) {
                match = watch;
                break;
              }
            }
            if (match != null) unawaited(_selectWatch(match));
          },
        ),
      ],
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
                  onDeleted: () => unawaited(
                    _applyQuery((StoreCatalogQuery q) => q.copyWith(clearCategory: true)),
                  ),
                ),
              if (_query.publisherName != null)
                InputChip(
                  label: Text(_query.publisherName!),
                  onDeleted: () => unawaited(
                    _applyQuery((StoreCatalogQuery q) => q.copyWith(clearPublisher: true)),
                  ),
                ),
              if (_query.price != StorePriceFilter.all)
                InputChip(
                  label: Text(_query.price.label),
                  onDeleted: () => unawaited(
                    _applyQuery((StoreCatalogQuery q) => q.copyWith(price: StorePriceFilter.all)),
                  ),
                ),
              if (_query.starredOnly)
                InputChip(
                  label: const Text('Starred'),
                  onDeleted: () => unawaited(
                    _applyQuery((StoreCatalogQuery q) => q.copyWith(starredOnly: false)),
                  ),
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
        else if (starredUpdates.isNotEmpty) ...<Widget>[
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
        ],
      ],
    ];

    final List<Widget> slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        sliver: SliverList(
          delegate: SliverChildListDelegate(header),
        ),
      ),
    ];

    if (_selected != null && !_loadingItems && _items.isNotEmpty) {
      if (starredUpdates.isNotEmpty) {
        slivers
          ..add(
            SliverPadding(
              padding: horizontal,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) => _tileFor(
                    starredUpdates[index],
                    busy: busy,
                    emphasizeUpdate: true,
                  ),
                  childCount: starredUpdates.length,
                  addAutomaticKeepAlives: false,
                ),
              ),
            ),
          )
          ..add(
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text('All items', style: theme.textTheme.titleSmall),
              ),
            ),
          );
      }

      slivers.add(
        SliverPadding(
          padding: horizontal,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) => _tileFor(
                _items[index],
                busy: busy,
              ),
              childCount: _items.length,
              addAutomaticKeepAlives: false,
            ),
          ),
        ),
      );
    }

    if (_selected != null && _downloaded.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
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
                    onPressed: () => unawaited(_shareExport(export)),
                  ),
                ),
            ]),
          ),
        ),
      );
    }

    slivers.add(
      const SliverPadding(
        padding: EdgeInsets.only(bottom: 20),
        sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
      ),
    );
    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool busy = _refreshing || _downloading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: <Widget>[
          if (widget.onOpenSettings != null) SettingsAction(onPressed: widget.onOpenSettings!),
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
          : RestorableScrollBody.slivers(
              storageId: 'store_${widget.entryType.apiValue}_${_selected?.deviceId ?? 'none'}',
              showJumpControls: true,
              onRefresh: _onPullRefresh,
              slivers: _buildCatalogSlivers(theme, busy),
            ),
    );
  }
}
