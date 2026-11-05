import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/domain/primitives/byte_size.dart';
import 'package:zelp/domain/primitives/firmware_version.dart';
import 'package:zelp/domain/primitives/local_datetime.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/main_shell.dart' show MainShell;
import 'package:zelp/screens/tab_epoch_sync.dart';
import 'package:zelp/screens/widgets/clipboard_actions.dart';
import 'package:zelp/screens/widgets/compact_watch_picker.dart';
import 'package:zelp/screens/widgets/error_banner.dart';
import 'package:zelp/screens/widgets/firmware/firmware_history_section.dart';
import 'package:zelp/screens/widgets/firmware/firmware_zepp_version_card.dart';
import 'package:zelp/screens/widgets/firmware/zepp_version_edit_dialog.dart';
import 'package:zelp/screens/widgets/output_folder_download.dart';
import 'package:zelp/screens/widgets/restorable_scroll_body.dart';
import 'package:zelp/screens/widgets/settings_action.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_notification_service.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/expert_mode_store.dart';
import 'package:zelp/services/file_download_notifier.dart';
import 'package:zelp/services/file_share_service.dart';
import 'package:zelp/services/firmware_client.dart';
import 'package:zelp/services/firmware_file_downloader.dart';
import 'package:zelp/services/firmware_store.dart';
import 'package:zelp/services/zepp_version_client.dart';

class FirmwareCheckScreen extends StatefulWidget {
  const FirmwareCheckScreen({
    super.key,
    this.catalog,
    this.versionClient,
    this.firmwareClient,
    this.firmwareStore,
    this.downloadStorage,
    this.firmwareDownloader,
    this.deviceUsageStore,
    this.expertModeStore,
    this.notificationService,
    this.settingsEpoch = 0,
    this.deviceUsageEpoch = 0,
    this.onOpenSettings,
  });

  /// Optional overrides for tests (seeded catalog / prefs — no network).
  final DeviceCatalog? catalog;
  final ZeppVersionClient? versionClient;
  final FirmwareClient? firmwareClient;
  final FirmwareStore? firmwareStore;
  final DownloadStorage? downloadStorage;
  final FirmwareFileDownloader? firmwareDownloader;
  final DeviceUsageStore? deviceUsageStore;
  final ExpertModeStore? expertModeStore;
  final DownloadNotificationService? notificationService;

  /// Bumped by [MainShell] when Settings closes so "already downloaded"
  /// matches refresh against the output folder.
  final int settingsEpoch;

  /// Bumped by [MainShell] when this tab is opened so selection re-syncs to
  /// the shared most-recently-used watch.
  final int deviceUsageEpoch;

  /// Opens the Settings screen (account + download folder).
  final VoidCallback? onOpenSettings;

  @override
  State<FirmwareCheckScreen> createState() => _FirmwareCheckScreenState();
}

class _FirmwareCheckScreenState extends State<FirmwareCheckScreen> {
  late final DeviceCatalog _catalog = widget.catalog ?? DeviceCatalog();
  late final ZeppVersionClient _versionClient = widget.versionClient ?? ZeppVersionClient();
  late final FirmwareClient _client = widget.firmwareClient ?? FirmwareClient(zeppVersionClient: _versionClient);
  late final FirmwareStore _store = widget.firmwareStore ?? FirmwareStore();
  late final DownloadStorage _downloads = widget.downloadStorage ?? DownloadStorage();
  late final FirmwareFileDownloader _downloader =
      widget.firmwareDownloader ?? FirmwareFileDownloader(storage: _downloads);
  late final DeviceUsageStore _usage = widget.deviceUsageStore ?? DeviceUsageStore();
  late final ExpertModeStore _expertModeStore = widget.expertModeStore ?? ExpertModeStore();
  late final FileDownloadNotifier _downloadNotifier = FileDownloadNotifier.firmware(
    widget.notificationService ?? const NoopDownloadNotificationService(),
  );
  final FileShareService _share = const FileShareService();

  List<WatchModel> _watches = <WatchModel>[];
  Map<String, StoredFirmwareHistory> _histories = <String, StoredFirmwareHistory>{};
  WatchModel? _selected;
  WatchVariant? _selectedVariant;
  List<WatchVariant> _sourceVariants = <WatchVariant>[];
  StoredFirmwareHistory? _history;
  bool _loadingCatalog = true;
  bool _checking = false;
  bool _refreshingZepp = false;
  String? _downloadingVersion;
  int _downloadReceived = 0;
  int? _downloadTotal;
  String? _downloadProgressLabel;
  DateTime _downloadProgressShownAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _zeppFromCache = false;
  bool _zeppEnteredManually = false;
  bool _expertMode = false;
  String? _zeppVersion;
  DateTime? _zeppCheckedAt;
  final TextEditingController _currentFirmware = TextEditingController();
  String? _firmwareFieldError;
  bool _closed = false;
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
    applyTabEpochChanges(
      oldSettingsEpoch: oldWidget.settingsEpoch,
      settingsEpoch: widget.settingsEpoch,
      oldDeviceUsageEpoch: oldWidget.deviceUsageEpoch,
      deviceUsageEpoch: widget.deviceUsageEpoch,
      onSettingsEpoch: () {
        unawaited(_loadOutputLabel());
        unawaited(_reloadExpertMode());
        setState(() {
          _existingByVersion.clear();
          _downloadedFirmware.clear();
        });
        unawaited(_refreshExistingForHistory(_history));
      },
      onDeviceUsageEpoch: () => unawaited(_syncToSharedMru()),
    );
  }

  Future<void> _loadOutputLabel() async {
    final OutputFolder folder = await _downloads.loadSettings(force: true);
    if (!mounted) return;
    setState(() => _outputFolderLabel = folder.label);
  }

  @override
  void dispose() {
    _closed = true;
    if (_expertMode) unawaited(_persistBaseline(_currentFirmware.text));
    _currentFirmware.dispose();
    super.dispose();
  }

  Future<void> _loadZeppVersionInfo() async {
    final String version = await _client.loadCachedZeppVersion();
    final String? cached = await _versionClient.getCached();
    final DateTime? checkedAt = await _versionClient.getCachedAt();
    final bool manual = await _versionClient.wasEnteredManually();
    if (!mounted) return;
    setState(() {
      _zeppVersion = version;
      _zeppFromCache = cached != null && cached.isNotEmpty;
      _zeppEnteredManually = manual;
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
      final ({List<WatchModel> ordered, WatchModel? preferred}) mru = await _usage.orderedWatchesWithPreferred(
        watches: watches,
        deviceIdOf: (WatchModel w) => w.deviceId,
      );
      final Map<String, StoredFirmwareHistory> histories = await _store.getAll();
      final bool expertMode = await _expertModeStore.load();
      await _loadZeppVersionInfo();
      if (!mounted) return;
      setState(() {
        _watches = mru.ordered;
        _histories = histories;
        _expertMode = expertMode;
        _loadingCatalog = false;
      });
      if (mru.preferred != null) {
        await _applyWatch(mru.preferred!, recordUsage: false);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _error = exceptionMessage(e);
      });
    }
  }

  /// Re-sort and select the globally preferred watch (tab re-opened).
  Future<void> _syncToSharedMru() async {
    final ({List<WatchModel> ordered, WatchModel? preferred})? mru = await orderedWatchesForSharedMru(
      usage: _usage,
      watches: _watches,
    );
    if (mru == null || !mounted) return;
    setState(() => _watches = mru.ordered);
    if (mru.preferred != null && mru.preferred!.deviceId != _selected?.deviceId) {
      await _applyWatch(mru.preferred!, recordUsage: false);
      return;
    }
    final WatchModel? watch = _selected;
    if (watch == null || watch.variants.length < 2) return;
    final ({List<WatchVariant> ordered, WatchVariant? preferred}) sources = await _usage.orderedSourcesWithPreferred(
      deviceId: watch.deviceId,
      sources: watch.variants,
      deviceSourceOf: (WatchVariant v) => v.deviceSource,
    );
    if (!mounted) return;
    if (sources.preferred != null && sources.preferred!.deviceSource != _selectedVariant?.deviceSource) {
      await _applyVariant(
        sources.preferred!,
        recordUsage: false,
        ordered: sources.ordered,
      );
    } else {
      setState(() => _sourceVariants = sources.ordered);
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
        _zeppEnteredManually = false;
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

  Future<void> _editZeppVersion() async {
    final AppVersion current = AppVersion(_zeppVersion ?? _versionClient.fallbackVersion);
    final AppVersion? next = await showZeppVersionEditDialog(context, current: current);
    if (!mounted || next == null) return;
    await _versionClient.saveManual(next);
    if (!mounted) return;
    await _loadZeppVersionInfo();
    if (!mounted) return;
    setState(() {
      _status = 'Using Zepp app ${next.value}';
      _error = null;
    });
  }

  Future<void> _reloadExpertMode() async {
    final bool enabled = await _expertModeStore.load();
    if (!mounted || _closed) return;
    if (_expertMode && !enabled) {
      await _persistBaseline(_currentFirmware.text);
      if (!mounted || _closed) return;
    }
    if (enabled) {
      final WatchModel? watch = _selected;
      final WatchVariant? variant = _selectedVariant;
      if (watch != null && variant != null) {
        final String? saved = await _store.baseline(
          deviceId: watch.deviceId,
          deviceSource: variant.deviceSource,
        );
        if (!mounted || _closed) return;
        _currentFirmware.text = saved ?? '';
      }
    }
    setState(() {
      _expertMode = enabled;
      _firmwareFieldError = null;
    });
  }

  Future<void> _persistBaseline(String raw) async {
    if (!_expertMode) return;
    final WatchModel? watch = _selected;
    final WatchVariant? variant = _selectedVariant;
    if (watch == null || variant == null) return;
    final String deviceId = watch.deviceId;
    final int deviceSource = variant.deviceSource;
    final String trimmed = raw.trim();
    if (trimmed.isNotEmpty && !FirmwareVersion.isUserInput(trimmed)) return;
    await _store.setBaseline(
      deviceId: deviceId,
      deviceSource: deviceSource,
      version: trimmed.isEmpty ? null : trimmed,
    );
  }

  /// Saves the field for the watch on screen, then loads the baseline for [watch].
  Future<void> _useBaselineFor(WatchModel watch, WatchVariant variant) async {
    await _persistBaseline(_currentFirmware.text);
    if (!mounted || _closed) return;
    final String? saved = await _store.baseline(
      deviceId: watch.deviceId,
      deviceSource: variant.deviceSource,
    );
    if (!mounted || _closed) return;
    _currentFirmware.text = saved ?? '';
  }

  void _onCurrentFirmwareChanged(String value) {
    if (_firmwareFieldError != null) {
      setState(() => _firmwareFieldError = null);
    }
    if (_expertMode) unawaited(_persistBaseline(value));
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
    final Iterable<ExistingDownloadProbe> probes = history == null
        ? const <ExistingDownloadProbe>[]
        : history.versions
              .where((FirmwareInfo info) => info.hasFirmware)
              .map(
                (FirmwareInfo info) => ExistingDownloadProbe(
                  key: info.firmwareVersion,
                  expectedFileName: FirmwareFileDownloader.suggestedFileName(
                    firmwareVersion: info.firmwareVersion,
                    firmwareUrl: info.firmwareUrl,
                    deviceName: _selected?.name,
                    semantic: _downloads.semanticNames,
                  ),
                  checksum: info.firmwareChecksum,
                  kind: AssetKind.firmware,
                ),
              );
    final Map<String, ExistingDownloadMatch> map = await _downloads.scanExistingMatches(probes);
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
    final ({List<WatchVariant> ordered, WatchVariant? preferred}) sources = await _usage.orderedSourcesWithPreferred(
      deviceId: watch.deviceId,
      sources: watch.variants,
      deviceSourceOf: (WatchVariant v) => v.deviceSource,
    );
    final WatchVariant variant = sources.preferred ?? sources.ordered.first;
    final StoredFirmwareHistory? history = _historyFor(watch, variant);
    if (recordUsage) {
      await _usage.touchWatch(watch.deviceId);
      await _usage.touchSource(watch.deviceId, variant.deviceSource);
    }
    await _useBaselineFor(watch, variant);
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
      _sourceVariants = sources.ordered;
      _selectedVariant = variant;
      _history = history;
      _firmwareFieldError = null;
      _status = history == null
          ? null
          : 'Stored latest: ${history.latestVersion}'
                '${history.checkedAt == null ? '' : ' · checked ${formatLocalDateTime(history.checkedAt!)}'}';
      _error = null;
    });
    await _refreshExistingForHistory(history);
  }

  Future<void> _selectVariant(WatchVariant variant) => _applyVariant(variant, recordUsage: true);

  Future<void> _applyVariant(
    WatchVariant variant, {
    required bool recordUsage,
    List<WatchVariant>? ordered,
  }) async {
    final WatchModel? watch = _selected;
    if (watch == null) return;
    final StoredFirmwareHistory? history = _historyFor(watch, variant);
    if (recordUsage) await _usage.touchSource(watch.deviceId, variant.deviceSource);
    await _useBaselineFor(watch, variant);
    if (!mounted) return;
    setState(() {
      final List<WatchVariant> base = ordered ?? (_sourceVariants.isEmpty ? watch.variants : _sourceVariants);
      _sourceVariants = recordUsage
          ? DeviceUsageStore.bringSourceToFront(
              sources: base,
              source: variant,
              deviceSourceOf: (WatchVariant v) => v.deviceSource,
            )
          : List<WatchVariant>.of(base);
      _selectedVariant = variant;
      _history = history;
      _firmwareFieldError = null;
      _status = history == null
          ? null
          : 'Stored latest: ${history.latestVersion}'
                '${history.checkedAt == null ? '' : ' · checked ${formatLocalDateTime(history.checkedAt!)}'}';
      _error = null;
    });
    await _refreshExistingForHistory(history);
  }

  Future<void> _onPullRefresh() async {
    if (_selected == null || _selectedVariant == null || _checking || _downloadingVersion != null) {
      return;
    }
    await _checkFirmware();
  }

  Future<void> _checkFirmware() async {
    if (_checking) return;
    final WatchModel? watch = _selected;
    final WatchVariant? variant = _selectedVariant;
    if (watch == null || variant == null) return;

    final String typed = _expertMode ? _currentFirmware.text.trim() : '';
    if (typed.isNotEmpty && !FirmwareVersion.isUserInput(typed)) {
      setState(() => _firmwareFieldError = _invalidFirmwareVersionMessage);
      return;
    }
    if (_expertMode) {
      await _persistBaseline(_currentFirmware.text);
      if (!mounted) return;
    }

    final String fromVersion = typed.isNotEmpty ? typed : (_history?.latestVersion ?? FirmwareVersion.zero.value);

    await _usage.touchWatch(watch.deviceId);
    await _usage.touchSource(watch.deviceId, variant.deviceSource);

    setState(() {
      _checking = true;
      _error = null;
      _status = fromVersion == FirmwareVersion.zero.value
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
      if (mounted) {
        await _loadZeppVersionInfo();
        setState(() => _checking = false);
      }
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

  Future<void> _copy(String value, String label) => copyTextWithSnackbar(context, text: value, label: label);

  Future<void> _confirmAndDownloadFirmware(FirmwareInfo info) async {
    if (_downloadingVersion != null) return;
    final String? url = info.firmwareUrl;
    if (url == null || url.isEmpty) return;

    final WatchModel? watch = _selected;
    if (watch != null) {
      await _usage.touchWatch(watch.deviceId);
      final WatchVariant? variant = _selectedVariant;
      if (variant != null) {
        await _usage.touchSource(watch.deviceId, variant.deviceSource);
      }
    }
    if (!mounted) return;

    final String fileName = FirmwareFileDownloader.suggestedFileName(
      firmwareVersion: info.firmwareVersion,
      firmwareUrl: url,
      deviceName: watch?.name,
      semantic: _downloads.semanticNames,
    );
    final OutputFolderDownloadResult result = await confirmAndDownloadToOutputFolder(
      context: context,
      downloads: _downloads,
      downloader: _downloader,
      notifier: _downloadNotifier,
      url: url,
      fileName: fileName,
      version: info.firmwareVersion,
      kind: AssetKind.firmware,
      expectedChecksum: info.firmwareChecksum,
      matchedByChecksumOnSave: info.firmwareChecksum != null,
      onShare: _shareExport,
      snackbarMessage: (String name) => 'Firmware saved: $name',
      dialogTitle:
          ({
            required bool isRedownload,
            required OutputFolder folder,
            required ExistingDownloadMatch? existing,
          }) => isRedownload ? 'Redownload firmware?' : 'Download firmware?',
      dialogContent:
          ({
            required bool isRedownload,
            required OutputFolder folder,
            required ExistingDownloadMatch? existing,
          }) => isRedownload
          ? '“${existing!.file.fileName}” is already in ${folder.label}'
                '${existing.matchedByChecksum ? ' (file verified)' : ''}.\n\n'
                'Redownloading will replace the existing file. Continue?'
          : 'Download firmware ${info.firmwareVersion} ($fileName) into '
                '${folder.label}?\n\n'
                'This can be a large file. Nothing is downloaded until you confirm.',
      onDownloadStarted: (OutputFolder folder, String name) async {
        if (!mounted) return;
        setState(() {
          _downloadingVersion = info.firmwareVersion;
          _downloadReceived = 0;
          _downloadTotal = null;
          _downloadProgressLabel = 'Starting…';
          _downloadProgressShownAt = DateTime.fromMillisecondsSinceEpoch(0);
          _error = null;
          _status = 'Downloading $name…';
          _outputFolderLabel = folder.label;
        });
      },
      onProgress: (int received, int? total) => _onFirmwareDownloadProgress(
        fileName,
        received,
        total,
      ),
    );
    if (!mounted) return;
    switch (result.status) {
      case OutputFolderDownloadStatus.cancelled:
        if (_downloadingVersion != null) setState(_clearDownloadUi);
        return;
      case OutputFolderDownloadStatus.failed:
        setState(() {
          _clearDownloadUi();
          _error = result.errorMessage;
          _status = null;
        });
      case OutputFolderDownloadStatus.success:
        final SavedExport export = result.export!;
        final OutputFolder folder = result.folder!;
        setState(() {
          _downloadedFirmware.insert(0, export);
          _status = 'Saved ${result.fileName} to ${folder.label}';
          _existingByVersion[info.firmwareVersion] = result.match!;
          _clearDownloadUi();
        });
    }
  }

  /// Coalesce byte-stream callbacks so the firmware list does not rebuild
  /// on every chunk. The chunk that finishes the body always paints.
  void _onFirmwareDownloadProgress(String fileName, int received, int? total) {
    if (!mounted || _downloadingVersion == null) return;
    final bool saving = total != null && total > 0 && received >= total;
    final DateTime now = DateTime.now();
    if (!saving && now.difference(_downloadProgressShownAt) < const Duration(milliseconds: 200)) {
      return;
    }
    _downloadProgressShownAt = now;
    final ({String caption, String status}) ui = _firmwareDownloadUi(
      fileName: fileName,
      received: received,
      total: total,
    );
    setState(() {
      _downloadReceived = received;
      _downloadTotal = total;
      _downloadProgressLabel = ui.caption;
      _status = ui.status;
    });
  }

  void _clearDownloadUi() {
    _downloadingVersion = null;
    _downloadReceived = 0;
    _downloadTotal = null;
    _downloadProgressLabel = null;
  }

  double? get _downloadFraction {
    final int? total = _downloadTotal;
    if (_downloadingVersion == null || total == null || total <= 0) return null;
    return (_downloadReceived / total).clamp(0.0, 1.0);
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
    missingMessage: 'Local file path unavailable to share',
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<WatchVariant> variants = _sourceVariants.isNotEmpty
        ? _sourceVariants
        : (_selected?.variants ?? const <WatchVariant>[]);
    final bool showSourcePicker = variants.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Firmware check'),
        actions: <Widget>[
          if (widget.onOpenSettings != null) SettingsAction(onPressed: widget.onOpenSettings!),
        ],
      ),
      body: _loadingCatalog
          ? const Center(child: CircularProgressIndicator())
          : RestorableScrollBody.list(
              storageId: 'firmware_${_selected?.deviceId ?? 'none'}',
              onRefresh: _onPullRefresh,
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
                FirmwareZeppVersionCard(
                  versionLabel: _zeppVersion ?? _versionClient.fallbackVersion,
                  fromCache: _zeppFromCache,
                  checkedAt: _zeppCheckedAt,
                  refreshing: _refreshingZepp,
                  enabled: !(_checking || _refreshingZepp),
                  enteredManually: _zeppEnteredManually,
                  onRefresh: _refreshZeppVersion,
                  onEdit: _expertMode ? _editZeppVersion : null,
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
                if (_selected != null && _selectedVariant != null)
                  FirmwareWatchActions(
                    deviceId: _selected!.deviceId,
                    watchName: _selected!.name,
                    variants: variants,
                    selectedVariant: _selectedVariant!,
                    showSourcePicker: showSourcePicker,
                    checking: _checking,
                    history: _history,
                    onSelectVariant: (WatchVariant value) => unawaited(_selectVariant(value)),
                    onCheckFirmware: _checkFirmware,
                    onClearHistory: _clearHistory,
                    expertMode: _expertMode,
                    currentFirmware: _currentFirmware,
                    currentFirmwareError: _firmwareFieldError,
                    onCurrentFirmwareChanged: _onCurrentFirmwareChanged,
                  ),
                if (_status != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(_status!, style: theme.textTheme.bodyMedium),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 16),
                  ErrorBanner(message: _error!),
                ],
                if (_history != null && _history!.versions.isNotEmpty)
                  FirmwareStoredVersionsList(
                    history: _history!,
                    versionsSubtitle: _firmwareVersionsSubtitle,
                    downloadingVersion: _downloadingVersion,
                    downloadProgress: _downloadFraction,
                    downloadProgressLabel: _downloadProgressLabel,
                    existingByVersion: _existingByVersion,
                    onCopy: _copy,
                    onDownloadFirmware: _confirmAndDownloadFirmware,
                    onShareExisting: _shareExisting,
                  ),
                FirmwareDownloadedList(
                  exports: _downloadedFirmware,
                  outputFolderLabel: _outputFolderLabel,
                  onShare: (SavedExport export) => unawaited(_shareExport(export)),
                ),
              ],
            ),
    );
  }
}

const String _invalidFirmwareVersionMessage = 'Enter a firmware version such as 3.17.0.3';

({String caption, String status}) _firmwareDownloadUi({
  required String fileName,
  required int received,
  int? total,
}) {
  if (total != null && total > 0 && received >= total) {
    return (caption: 'Saving…', status: 'Saving $fileName…');
  }
  if (received <= 0) {
    return (caption: 'Starting…', status: 'Downloading $fileName…');
  }
  final String caption = formatDownloadProgress(received: received, total: total);
  return (caption: caption, status: 'Downloading $fileName · $caption');
}
