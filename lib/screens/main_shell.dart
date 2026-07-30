import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zelp/domain/navigation/auth_tab_gate.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/screens/credentials_screen.dart';
import 'package:zelp/screens/firmware_check_screen.dart';
import 'package:zelp/screens/gps_files_screen.dart';
import 'package:zelp/screens/store_catalog_screen.dart';
import 'package:zelp/services/android_download_notification_service.dart';
import 'package:zelp/services/credential_store.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_notification_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.credentialStore,
    this.deviceUsageStore,
    this.authGate = const AuthTabGate(),
  });

  final CredentialStore? credentialStore;
  final DeviceUsageStore? deviceUsageStore;
  final AuthTabGate authGate;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final AuthTabGate _gate = const AuthTabGate();

  int _index = AuthTabGate.credentialsIndex;
  bool _signedIn = false;

  /// Lazily built so opening the app does not fetch the device catalog.
  bool _watchfacesOpened = false;
  bool _appsOpened = false;
  bool _firmwareOpened = false;
  int _gpsSettingsEpoch = 0;
  int _deviceUsageEpoch = 0;
  DownloadNotificationService? _downloadNotifications;

  late final CredentialStore _credentials = widget.credentialStore ?? CredentialStore();
  late final DeviceUsageStore _deviceUsage = widget.deviceUsageStore ?? DeviceUsageStore();

  AuthTabGate get _authGate => widget.authGate;

  DownloadNotificationService _notifications() => _downloadNotifications ??= Platform.isAndroid
      ? AndroidDownloadNotificationService()
      : const NoopDownloadNotificationService();

  @override
  void initState() {
    super.initState();
    unawaited(_refreshAuth());
  }

  Future<void> _refreshAuth() async {
    final Credentials? creds = await _credentials.load();
    if (!mounted) return;
    final bool signedIn = creds != null && !creds.isEmpty;
    setState(() {
      _signedIn = signedIn;
      _index = _authGate.afterAuthChanged(current: _index, signedIn: signedIn);
    });
  }

  void _onAuthChanged(bool signedIn) {
    setState(() {
      _signedIn = signedIn;
      _index = _authGate.afterAuthChanged(current: _index, signedIn: signedIn);
    });
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
      if (next == AuthTabGate.gpsIndex) _gpsSettingsEpoch++;
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

  @override
  Widget build(BuildContext context) {
    // Keep analyzer happy if gate const differs in tests.
    assert(_gate.requiresAuth(AuthTabGate.gpsIndex), 'GPS tab must require auth');

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          CredentialsScreen(
            credentialStore: _credentials,
            deviceUsageStore: _deviceUsage,
            onAuthChanged: _onAuthChanged,
          ),
          GpsFilesScreen(
            settingsEpoch: _gpsSettingsEpoch,
            credentialStore: _credentials,
          ),
          if (_watchfacesOpened)
            StoreCatalogScreen(
              entryType: StoreEntryType.watch,
              notificationService: _notifications(),
              deviceUsageStore: _deviceUsage,
              deviceUsageEpoch: _deviceUsageEpoch,
            )
          else
            const SizedBox.shrink(),
          if (_appsOpened)
            StoreCatalogScreen(
              entryType: StoreEntryType.lightapp,
              notificationService: _notifications(),
              deviceUsageStore: _deviceUsage,
              deviceUsageEpoch: _deviceUsageEpoch,
            )
          else
            const SizedBox.shrink(),
          if (_firmwareOpened)
            FirmwareCheckScreen(
              notificationService: _notifications(),
              deviceUsageStore: _deviceUsage,
              deviceUsageEpoch: _deviceUsageEpoch,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: <Widget>[
          const NavigationDestination(
            icon: Icon(Icons.key_outlined),
            selectedIcon: Icon(Icons.key),
            label: 'Credentials',
          ),
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
