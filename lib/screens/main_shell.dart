import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zelp/domain/navigation/auth_tab_gate.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/screens/firmware_check_screen.dart';
import 'package:zelp/screens/gps_files_screen.dart';
import 'package:zelp/screens/settings_screen.dart';
import 'package:zelp/screens/store_catalog_screen.dart';
import 'package:zelp/services/android_download_notification_service.dart';
import 'package:zelp/services/android_network_foreground_keep_alive.dart';
import 'package:zelp/services/app_setup_store.dart';
import 'package:zelp/services/credential_store.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_notification_service.dart';
import 'package:zelp/services/network_foreground_keep_alive.dart';
import 'package:zelp/services/store_catalog_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.credentialStore,
    this.deviceUsageStore,
    this.setupStore,
    this.catalogService,
    this.authGate = const AuthTabGate(),
  });

  final CredentialStore? credentialStore;
  final DeviceUsageStore? deviceUsageStore;
  final AppSetupStore? setupStore;
  final StoreCatalogService? catalogService;
  final AuthTabGate authGate;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = AuthTabGate.firmwareIndex;
  bool _signedIn = false;
  bool _bootstrapped = false;
  bool _settingsOpen = false;

  /// Lazily built so opening the app does not fetch the device catalog.
  bool _gpsOpened = false;
  bool _watchfacesOpened = false;
  bool _appsOpened = false;
  bool _firmwareOpened = true;

  /// Bumped when Settings closes so tabs refresh folder-backed UI (labels,
  /// "already downloaded" matches). Also bumped when opening the GPS tab.
  int _settingsEpoch = 0;
  int _deviceUsageEpoch = 0;
  DownloadNotificationService? _downloadNotifications;

  late final CredentialStore _credentials = widget.credentialStore ?? CredentialStore();
  late final DeviceUsageStore _deviceUsage = widget.deviceUsageStore ?? DeviceUsageStore();
  late final AppSetupStore _setup = widget.setupStore ?? AppSetupStore();

  /// Shared across Apps + Watchfaces so both tabs use one Drift catalog DB.
  StoreCatalogService? _ownedCatalog;

  AuthTabGate get _authGate => widget.authGate;

  StoreCatalogService get _catalogService {
    final StoreCatalogService? injected = widget.catalogService;
    if (injected != null) return injected;
    return _ownedCatalog ??= StoreCatalogService(credentialStore: _credentials);
  }

  DownloadNotificationService _notifications() => _downloadNotifications ??= Platform.isAndroid
      ? AndroidDownloadNotificationService()
      : const NoopDownloadNotificationService();

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      NetworkForegroundKeepAlive.instance = AndroidNetworkForegroundKeepAlive();
    }
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    final StoreCatalogService? owned = _ownedCatalog;
    _ownedCatalog = null;
    if (owned != null) {
      unawaited(owned.close());
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    bool signedIn = false;
    bool setupDone = false;
    try {
      final Credentials? creds = await _credentials.load();
      signedIn = creds != null && !creds.isEmpty;
      setupDone = await _setup.isComplete();

      // Existing installs that already saved credentials skip first-time setup.
      if (!setupDone && signedIn) {
        await _setup.markComplete();
        setupDone = true;
      }
    } on Exception catch (_) {
      // Still show the shell; gated tabs stay locked until Settings works.
    }

    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _index = _authGate.initialIndex(signedIn: signedIn);
      _gpsOpened = signedIn;
      _bootstrapped = true;
    });

    if (!setupDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openSettings(isFirstTimeSetup: true));
      });
    }
  }

  void _onAuthChanged(bool signedIn) {
    setState(() {
      _signedIn = signedIn;
      _index = _authGate.afterAuthChanged(current: _index, signedIn: signedIn);
      if (signedIn) _gpsOpened = true;
    });
  }

  Future<void> _openSettings({bool isFirstTimeSetup = false}) async {
    if (_settingsOpen || !mounted) return;
    _settingsOpen = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (BuildContext context) => SettingsScreen(
            credentialStore: _credentials,
            deviceUsageStore: _deviceUsage,
            setupStore: _setup,
            isFirstTimeSetup: isFirstTimeSetup,
            onAuthChanged: _onAuthChanged,
            onSetupComplete: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      );
    } finally {
      _settingsOpen = false;
      if (mounted) {
        setState(() {
          _settingsEpoch++;
          _deviceUsageEpoch++;
        });
      }
    }
  }

  void _onDestinationSelected(int value) {
    final int? next = _authGate.resolveSelection(
      from: _index,
      to: value,
      signedIn: _signedIn,
    );
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthTabGate.signInRequiredMessage)),
      );
      return;
    }
    setState(() {
      _index = next;
      if (next == AuthTabGate.gpsIndex) {
        _gpsOpened = true;
        _settingsEpoch++;
      }
      if (next == AuthTabGate.watchfacesIndex) {
        _watchfacesOpened = true;
        _deviceUsageEpoch++;
      }
      if (next == AuthTabGate.appsIndex) {
        _appsOpened = true;
        _deviceUsageEpoch++;
      }
      if (next == AuthTabGate.firmwareIndex) {
        _firmwareOpened = true;
        _deviceUsageEpoch++;
      }
    });
  }

  Widget _lockedIcon(
    IconData outlined,
    IconData filled, {
    required bool selected,
  }) => Badge(
    smallSize: 8,
    alignment: AlignmentDirectional.topEnd,
    backgroundColor: Colors.transparent,
    label: Icon(
      Icons.lock_outline,
      size: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    child: Icon(selected ? filled : outlined),
  );

  Widget _storeTab({
    required StoreEntryType entryType,
    required bool opened,
  }) {
    if (!opened) return const SizedBox.shrink();
    return StoreCatalogScreen(
      entryType: entryType,
      catalogService: _catalogService,
      notificationService: _notifications(),
      deviceUsageStore: _deviceUsage,
      settingsEpoch: _settingsEpoch,
      deviceUsageEpoch: _deviceUsageEpoch,
      onOpenSettings: () {
        unawaited(_openSettings());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(_authGate.requiresAuth(AuthTabGate.gpsIndex), 'GPS tab must require auth');

    if (!_bootstrapped) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          if (_gpsOpened)
            GpsFilesScreen(
              settingsEpoch: _settingsEpoch,
              credentialStore: _credentials,
              onOpenSettings: () {
                unawaited(_openSettings());
              },
            )
          else
            const SizedBox.shrink(),
          _storeTab(entryType: StoreEntryType.watch, opened: _watchfacesOpened),
          _storeTab(entryType: StoreEntryType.lightapp, opened: _appsOpened),
          if (_firmwareOpened)
            FirmwareCheckScreen(
              notificationService: _notifications(),
              deviceUsageStore: _deviceUsage,
              settingsEpoch: _settingsEpoch,
              deviceUsageEpoch: _deviceUsageEpoch,
              onOpenSettings: () {
                unawaited(_openSettings());
              },
            )
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: <Widget>[
          NavigationDestination(
            icon: _lockedIcon(Icons.map_outlined, Icons.map, selected: false),
            selectedIcon: _lockedIcon(
              Icons.map_outlined,
              Icons.map,
              selected: true,
            ),
            label: 'GPS',
          ),
          NavigationDestination(
            icon: _lockedIcon(
              Icons.watch_outlined,
              Icons.watch,
              selected: false,
            ),
            selectedIcon: _lockedIcon(
              Icons.watch_outlined,
              Icons.watch,
              selected: true,
            ),
            label: 'Watchfaces',
          ),
          NavigationDestination(
            icon: _lockedIcon(Icons.apps_outlined, Icons.apps, selected: false),
            selectedIcon: _lockedIcon(
              Icons.apps_outlined,
              Icons.apps,
              selected: true,
            ),
            label: 'Apps',
          ),
          const NavigationDestination(
            icon: Icon(Icons.system_update_alt_outlined),
            selectedIcon: Icon(Icons.system_update_alt),
            label: 'Firmware',
          ),
        ],
      ),
    );
  }
}
