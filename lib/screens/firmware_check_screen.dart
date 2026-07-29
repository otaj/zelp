import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/main_shell.dart' show MainShell;
import 'package:zelp/screens/widgets/compact_watch_picker.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_notification_service.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/file_share_service.dart';
import 'package:zelp/services/firmware_client.dart';
import 'package:zelp/services/firmware_download_notifier.dart';
import 'package:zelp/services/firmware_file_downloader.dart';
import 'package:zelp/services/firmware_store.dart';
import 'package:zelp/services/zepp_version_client.dart';

class FirmwareCheckScreen extends StatefulWidget {
  const FirmwareCheckScreen({
    super.key,
    this.catalog,
    this.versionClient,
    this.firmwareStore,
    this.downloadStorage,
    this.firmwareDownloader,
    this.deviceUsageStore,
    this.notificationService,
    this.deviceUsageEpoch = 0,
  });

  /// Optional overrides for tests (seeded catalog / prefs — no network).
  final DeviceCatalog? catalog;
  final ZeppVersionClient? versionClient;
  final FirmwareStore? firmwareStore;
  final DownloadStorage? downloadStorage;
  final FirmwareFileDownloader? firmwareDownloader;
  final DeviceUsageStore? deviceUsageStore;
  final DownloadNotificationService? notificationService;

  /// Bumped by [MainShell] when this tab is opened so selection re-syncs to
  /// the shared most-recently-used watch.
  final int deviceUsageEpoch;

  @override
  State<FirmwareCheckScreen> createState() => _FirmwareCheckScreenState();
}

class _FirmwareCheckScreenState extends State<FirmwareCheckScreen> {
  late final DeviceCatalog _catalog = widget.catalog ?? DeviceCatalog();
  late final ZeppVersionClient _versionClient = widget.versionClient ?? ZeppVersionClient();
  late final FirmwareClient _client = FirmwareClient(zeppVersionClient: _versionClient);
  late final FirmwareStore _store = widget.firmwareStore ?? FirmwareStore();
  late final DownloadStorage _downloads = widget.downloadStorage ?? DownloadStorage();
  late final FirmwareFileDownloader _downloader =
      widget.firmwareDownloader ?? FirmwareFileDownloader(storage: _downloads);
  late final DeviceUsageStore _usage = widget.deviceUsageStore ?? DeviceUsageStore();
  late final FirmwareDownloadNotifier _downloadNotifier = FirmwareDownloadNotifier(
    widget.notificationService ?? const NoopDownloadNotificationService(),
  );
  final FileShareService _share = const FileShareService();

  List<WatchModel> _watches = <WatchModel>[];
  Map<String, StoredFirmwareHistory> _histories = <String, StoredFirmwareHistory>{};
  WatchModel? _selected;
  WatchVariant? _selectedVariant;
  StoredFirmwareHistory? _history;
  bool _loadingCatalog = true;
  bool _checking = false;
  bool _refreshingZepp = false;
  bool _downloadingFirmware = false;
  bool _zeppFromCache = false;
  String? _zeppVersion;
  DateTime? _zeppCheckedAt;
  String? _status;
  String? _error;
  final List<SavedExport> _downloadedFirmware = <SavedExport>[];
  String? _outputFolderLabel;
  final Map<String, ExistingDownloadMatch> _existingByVersion = <String, ExistingDownloadMatch>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
    unawaited(_loadOutputLabel());
  }

  @override
  void didUpdateWidget(covariant FirmwareCheckScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceUsageEpoch != widget.deviceUsageEpoch) {
      unawaited(_syncToSharedMru());
    }
  }

  Future<void> _loadOutputLabel() async {
    final OutputFolder folder = await _downloads.loadSettings();
    if (!mounted) return;
    setState(() => _outputFolderLabel = folder.label);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadZeppVersionInfo() async {
    final String version = await _client.loadCachedZeppVersion();
    final String? cached = await _versionClient.getCached();
    final DateTime? checkedAt = await _versionClient.getCachedAt();
    if (!mounted) return;
    setState(() {
      _zeppVersion = version;
      _zeppFromCache = cached != null && cached.isNotEmpty;
      _zeppCheckedAt = checkedAt;
    });
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    try {
      final List<WatchModel> watches = await _catalog.load();
      final List<WatchModel> ordered = await _usage.sortWatches(
        watches: watches,
        deviceIdOf: (WatchModel w) => w.deviceId,
      );
      final WatchModel? preferred = await _usage.preferMostRecentWatch(
        watches: ordered,
        deviceIdOf: (WatchModel w) => w.deviceId,
      );
      final Map<String, StoredFirmwareHistory> histories = await _store.getAll();
      await _loadZeppVersionInfo();
      if (!mounted) return;
      setState(() {
        _watches = ordered;
        _histories = histories;
        _loadingCatalog = false;
      });
      if (preferred != null) {
        await _applyWatch(preferred, recordUsage: false);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _error = e is ZelpException ? e.message : e.toString();
      });
    }
  }

  /// Re-sort and select the globally preferred watch (tab re-opened).
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

  Future<void> _refreshZeppVersion() async {
    setState(() {
      _refreshingZepp = true;
      _error = null;
      _status = 'Looking up the latest Zepp app version…';
    });
    try {
      final String version = await _client.refreshZeppVersion();
      final DateTime? checkedAt = await _versionClient.getCachedAt();
      if (!mounted) return;
      setState(() {
        _zeppVersion = version;
        _zeppFromCache = true;
        _zeppCheckedAt = checkedAt;
        _status = 'Using Zepp app $version';
      });
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
      if (mounted) setState(() => _refreshingZepp = false);
    }
  }

  String? _historyKeyFor(WatchModel watch, WatchVariant variant) =>
      StoredFirmwareHistory.storageKey(watch.deviceId, variant.deviceSource);

  StoredFirmwareHistory? _historyFor(WatchModel watch, WatchVariant variant) =>
      _histories[_historyKeyFor(watch, variant)!];

  /// Best stored firmware among all variants for list subtitle.
  String? _anyStoredLatest(WatchModel watch) {
    String? best;
    for (final WatchVariant variant in watch.variants) {
      final StoredFirmwareHistory? history = _historyFor(watch, variant);
      final String? version = history?.latestVersion;
      if (version == null || version == '0') continue;
      best ??= version;
      if (version.compareTo(best) > 0) best = version;
    }
    return best;
  }

  /// Watch name, plus device source when this model has multiple sources.
  String? get _firmwareVersionsSubtitle {
    final WatchModel? watch = _selected;
    final WatchVariant? variant = _selectedVariant;
    if (watch == null || variant == null) return null;
    if (watch.variants.length <= 1) return watch.name;
    return '${watch.name} · ${variant.label}';
  }

  Future<void> _refreshExistingForHistory(
    StoredFirmwareHistory? history,
  ) async {
    final Map<String, ExistingDownloadMatch> map = <String, ExistingDownloadMatch>{};
    if (history != null) {
      for (final FirmwareInfo info in history.versions) {
        if (!info.hasFirmware) continue;
        final String fileName = FirmwareFileDownloader.suggestedFileName(
          firmwareVersion: info.firmwareVersion,
          firmwareUrl: info.firmwareUrl,
        );
        try {
          final ExistingDownloadMatch? match = await _downloads.findExistingDownload(
            expectedFileName: fileName,
            checksum: info.firmwareChecksum,
            kind: AssetKind.firmware,
          );
          if (match != null) {
            map[info.firmwareVersion] = match;
          }
        } on Exception catch (_) {
          // Folder listing can fail on unsupported platforms; ignore.
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _existingByVersion
        ..clear()
        ..addAll(map);
    });
  }

  Future<void> _selectWatch(WatchModel watch) => _applyWatch(watch, recordUsage: true);

  Future<void> _applyWatch(
    WatchModel watch, {
    required bool recordUsage,
  }) async {
    final WatchVariant variant = watch.variants.first;
    final StoredFirmwareHistory? history = _historyFor(watch, variant);
    if (recordUsage) await _usage.touchWatch(watch.deviceId);
    if (!mounted) return;
    setState(() {
      if (recordUsage) {
        _watches = List<WatchModel>.of(_watches)
          ..removeWhere((WatchModel w) => w.deviceId == watch.deviceId)
          ..insert(0, watch);
      }
      _selected = watch;
      _selectedVariant = variant;
      _history = history;
      _status = history == null
          ? null
          : 'Stored latest: ${history.latestVersion}'
                '${history.checkedAt == null ? '' : ' · checked ${_formatTime(history.checkedAt!)}'}';
      _error = null;
    });
    await _refreshExistingForHistory(history);
  }

  Future<void> _selectVariant(WatchVariant variant) async {
    final WatchModel? watch = _selected;
    if (watch == null) return;
    final StoredFirmwareHistory? history = _historyFor(watch, variant);
    setState(() {
      _selectedVariant = variant;
      _history = history;
      _status = history == null
          ? null
          : 'Stored latest: ${history.latestVersion}'
                '${history.checkedAt == null ? '' : ' · checked ${_formatTime(history.checkedAt!)}'}';
      _error = null;
    });
    await _refreshExistingForHistory(history);
  }

  Future<void> _checkFirmware() async {
    final WatchModel? watch = _selected;
    final WatchVariant? variant = _selectedVariant;
    if (watch == null || variant == null) return;

    await _usage.touchWatch(watch.deviceId);
    final String fromVersion = _history?.latestVersion ?? '0';

    setState(() {
      _checking = true;
      _error = null;
      _status = fromVersion == '0'
          ? 'Checking ${watch.name}…'
          : 'Checking ${watch.name} for updates newer than $fromVersion…';
    });

    try {
      final List<FirmwareInfo> discovered = await _client.checkUpdates(
        variant: variant,
        fromVersion: fromVersion,
      );
      final StoredFirmwareHistory history = await _store.merge(
        watch: watch,
        variant: variant,
        discovered: discovered,
      );
      if (!mounted) return;
      final String key = _historyKeyFor(watch, variant)!;
      setState(() {
        _histories = <String, StoredFirmwareHistory>{..._histories, key: history};
        _history = history;
        if (discovered.isEmpty) {
          _status = history.versions.isEmpty
              ? 'No firmware found for ${watch.name}.'
              : 'Already up to date at ${history.latestVersion}.';
        } else {
          _status =
              'Found ${discovered.length} new version(s). '
              'Latest: ${history.latestVersion}';
        }
      });
      await _refreshExistingForHistory(history);
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
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _clearHistory() async {
    final WatchModel? watch = _selected;
    final WatchVariant? variant = _selectedVariant;
    if (watch == null || variant == null) return;
    await _store.clearVariant(
      deviceId: watch.deviceId,
      deviceSource: variant.deviceSource,
    );
    if (!mounted) return;
    setState(() {
      _histories = Map<String, StoredFirmwareHistory>.of(_histories)..remove(_historyKeyFor(watch, variant));
      _history = null;
      _existingByVersion.clear();
      _status = watch.variants.length > 1
          ? 'Cleared stored versions for ${watch.name} (${variant.label}).'
          : 'Cleared stored versions for ${watch.name}.';
      _error = null;
    });
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _confirmAndDownloadFirmware(FirmwareInfo info) async {
    final String? url = info.firmwareUrl;
    if (url == null || url.isEmpty) return;

    final WatchModel? watch = _selected;
    if (watch != null) await _usage.touchWatch(watch.deviceId);

    final OutputFolder folder = await _downloads.loadSettings();
    if (!mounted) return;

    final String fileName = FirmwareFileDownloader.suggestedFileName(
      firmwareVersion: info.firmwareVersion,
      firmwareUrl: url,
    );
    final ExistingDownloadMatch? existing = await _downloads.findExistingDownload(
      expectedFileName: fileName,
      checksum: info.firmwareChecksum,
      kind: AssetKind.firmware,
    );
    if (!mounted) return;

    final bool isRedownload = existing != null;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          isRedownload ? 'Redownload firmware?' : 'Download firmware?',
        ),
        content: Text(
          isRedownload
              ? '“${existing.file.fileName}” is already in ${folder.label}'
                    '${existing.matchedByChecksum ? ' (file verified)' : ''}.\n\n'
                    'Redownloading will replace the existing file. Continue?'
              : 'Download firmware ${info.firmwareVersion} ($fileName) into '
                    '${folder.label}?\n\n'
                    'This can be a large file. Nothing is downloaded until you confirm.',
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
    if (confirmed != true || !mounted) return;

    setState(() {
      _downloadingFirmware = true;
      _error = null;
      _status = 'Downloading $fileName…';
      _outputFolderLabel = folder.label;
    });

    try {
      await _downloadNotifier.begin(
        fileName: fileName,
        firmwareVersion: info.firmwareVersion,
      );

      final SavedExport export = await _downloader.downloadToOutputFolder(
        url: Uri.parse(url),
        fileName: fileName,
        expectedChecksum: info.firmwareChecksum,
        kind: AssetKind.firmware,
        onProgress: (int received, int? total) {
          unawaited(
            _downloadNotifier.reportProgress(
              fileName: fileName,
              firmwareVersion: info.firmwareVersion,
              received: received,
              total: total,
            ),
          );
        },
      );
      await _downloadNotifier.complete(
        fileName: fileName,
        firmwareVersion: info.firmwareVersion,
      );
      if (!mounted) return;
      setState(() {
        _downloadedFirmware.insert(0, export);
        _status = 'Saved $fileName to ${folder.label}';
        _existingByVersion[info.firmwareVersion] = ExistingDownloadMatch(
          file: StoredOutputFile(
            fileName: export.fileName,
            displayPath: export.displayPath,
            localPath: export.localPath,
          ),
          matchedByChecksum: info.firmwareChecksum != null,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firmware saved: $fileName'),
          persist: false,
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => _shareExport(export),
          ),
        ),
      );
    } on ZelpException catch (e) {
      await _downloadNotifier.fail(
        fileName: fileName,
        firmwareVersion: info.firmwareVersion,
      );
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = null;
      });
    } on Exception catch (e) {
      await _downloadNotifier.fail(
        fileName: fileName,
        firmwareVersion: info.firmwareVersion,
      );
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = null;
      });
    } finally {
      if (mounted) setState(() => _downloadingFirmware = false);
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
        const SnackBar(content: Text('Local file path unavailable to share')),
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

  String _formatTime(DateTime time) {
    final DateTime local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<WatchVariant> variants = _selected?.variants ?? const <WatchVariant>[];
    final bool showSourcePicker = variants.length > 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Firmware check')),
      body: _loadingCatalog
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text('Choose a watch', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Recently used watches appear first. Firmware checks use the '
                  'saved Zepp app version; tap refresh on that card to update it.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.android),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Zepp app in use',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SelectableText(
                                _zeppVersion ?? _versionClient.fallbackVersion,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                _zeppFromCache
                                    ? (_zeppCheckedAt == null
                                          ? 'Saved on this device'
                                          : 'Saved · ${_formatTime(_zeppCheckedAt!)}')
                                    : 'Built-in default — refresh for the latest',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Update Zepp app version',
                          onPressed: (_checking || _refreshingZepp) ? null : _refreshZeppVersion,
                          icon: _refreshingZepp
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CompactWatchPicker(
                  watches: _watches,
                  selected: _selected,
                  enabled: !_checking,
                  onSelected: _selectWatch,
                  subtitleBuilder: (WatchModel watch) {
                    final String? storedLatest = _anyStoredLatest(watch);
                    return storedLatest == null ? null : 'FW $storedLatest';
                  },
                ),
                if (_selected != null && _selectedVariant != null) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(_selected!.name, style: theme.textTheme.titleSmall),
                  if (showSourcePicker) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'This watch has more than one device source. '
                      'Pick the source that matches your hardware.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownMenu<WatchVariant>(
                      key: ValueKey<String>(
                        '${_selected!.deviceId}:${_selectedVariant!.deviceSource}',
                      ),
                      enabled: !_checking,
                      initialSelection: _selectedVariant,
                      label: const Text('Device source'),
                      expandedInsets: EdgeInsets.zero,
                      onSelected: (WatchVariant? value) {
                        if (value != null) unawaited(_selectVariant(value));
                      },
                      dropdownMenuEntries: variants
                          .map(
                            (WatchVariant v) => DropdownMenuEntry<WatchVariant>(value: v, label: v.label),
                          )
                          .toList(),
                    ),
                  ],
                  if (_history?.latest != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Will check for versions newer than '
                      '${_history!.latestVersion}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _checking ? null : _checkFirmware,
                          icon: _checking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.system_update_alt),
                          label: Text(
                            _checking ? 'Checking…' : 'Check for updates',
                          ),
                        ),
                      ),
                      if (_history != null && _history!.versions.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: showSourcePicker
                              ? 'Clear stored versions for this device source'
                              : 'Clear stored versions for this watch',
                          onPressed: _checking ? null : _clearHistory,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                ],
                if (_status != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(_status!, style: theme.textTheme.bodyMedium),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Material(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_history != null && _history!.versions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    'Stored versions'
                    '${_firmwareVersionsSubtitle == null ? '' : ' · $_firmwareVersionsSubtitle'}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._history!.versions.reversed.map(
                    (FirmwareInfo info) => _FirmwareVersionCard(
                      info: info,
                      isLatest: info.firmwareVersion == _history!.latestVersion,
                      downloading: _downloadingFirmware,
                      existing: _existingByVersion[info.firmwareVersion],
                      onCopy: _copy,
                      onDownloadFirmware: info.hasFirmware ? () => _confirmAndDownloadFirmware(info) : null,
                      onShareExisting: _shareExisting,
                    ),
                  ),
                ],
                if (_downloadedFirmware.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    'Downloaded firmware files',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saved to ${_outputFolderLabel ?? 'output folder'}. '
                    'Share opens the system share sheet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._downloadedFirmware.map(
                    (SavedExport export) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.system_update_alt),
                      title: Text(export.fileName),
                      subtitle: Text(export.displayPath, maxLines: 2),
                      trailing: IconButton(
                        tooltip: 'Share',
                        onPressed: () => _shareExport(export),
                        icon: const Icon(Icons.share_outlined),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _FirmwareVersionCard extends StatelessWidget {
  const _FirmwareVersionCard({
    required this.info,
    required this.isLatest,
    required this.onCopy,
    required this.downloading,
    this.existing,
    this.onDownloadFirmware,
    this.onShareExisting,
  });

  final FirmwareInfo info;
  final bool isLatest;
  final bool downloading;
  final ExistingDownloadMatch? existing;
  final Future<void> Function(String value, String label) onCopy;
  final VoidCallback? onDownloadFirmware;
  final Future<void> Function(ExistingDownloadMatch match)? onShareExisting;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? readme = info.readmeOrChangelog;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    info.firmwareVersion,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (isLatest)
                  Chip(
                    label: const Text('Latest'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
              ],
            ),
            if (readme != null) ...<Widget>[
              const SizedBox(height: 4),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    'Release notes',
                    style: theme.textTheme.labelLarge,
                  ),
                  children: <Widget>[
                    Align(alignment: Alignment.centerLeft, child: Text(readme)),
                  ],
                ),
              ),
            ],
            if (existing != null) ...<Widget>[
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Already downloaded'),
                subtitle: Text(
                  '${existing!.file.fileName}'
                  '${existing!.matchedByChecksum ? ' · verified' : ''}',
                  maxLines: 2,
                ),
                trailing: onShareExisting == null
                    ? null
                    : IconButton(
                        tooltip: 'Share existing file',
                        onPressed: () => onShareExisting!(existing!),
                        icon: const Icon(Icons.share_outlined),
                      ),
              ),
            ],
            if (info.firmwareUrl != null && info.firmwareUrl!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Firmware file'),
                subtitle: Text(info.firmwareUrl!, maxLines: 2),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Copy URL',
                      onPressed: () => onCopy(info.firmwareUrl!, 'Firmware URL'),
                      icon: const Icon(Icons.copy),
                    ),
                    IconButton(
                      tooltip: existing == null ? 'Download to output folder' : 'Redownload (replace existing)',
                      onPressed: downloading ? null : onDownloadFirmware,
                      icon: downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              existing == null ? Icons.download_outlined : Icons.refresh,
                            ),
                    ),
                  ],
                ),
              ),
            if (info.gpsVersion != null && info.gpsUrl != null && info.gpsUrl!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('GPS ${info.gpsVersion}'),
                subtitle: Text(info.gpsUrl!, maxLines: 2),
                trailing: IconButton(
                  onPressed: () => onCopy(info.gpsUrl!, 'GPS URL'),
                  icon: const Icon(Icons.copy),
                ),
              ),
            if (info.resourceVersion != null && info.resourceUrl != null && info.resourceUrl!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Resources ${info.resourceVersion}'),
                subtitle: Text(info.resourceUrl!, maxLines: 2),
                trailing: IconButton(
                  onPressed: () => onCopy(info.resourceUrl!, 'Resource URL'),
                  icon: const Icon(Icons.copy),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
