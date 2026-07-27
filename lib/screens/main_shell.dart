import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/navigation/auth_tab_gate.dart';
import '../models/store_item.dart';
import '../services/android_download_notification_service.dart';
import '../services/credential_store.dart';
import '../services/download_notification_service.dart';
import 'credentials_screen.dart';
import 'firmware_check_screen.dart';
import 'gps_files_screen.dart';
import 'store_catalog_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.credentialStore,
    this.authGate = const AuthTabGate(),
  });

  final CredentialStore? credentialStore;
  final AuthTabGate authGate;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _gate = const AuthTabGate();

  int _index = AuthTabGate.credentialsIndex;
  bool _signedIn = false;

  /// Lazily built so opening the app does not fetch the device catalog.
  bool _watchfacesOpened = false;
  bool _appsOpened = false;
  bool _firmwareOpened = false;
  int _gpsSettingsEpoch = 0;
  DownloadNotificationService? _downloadNotifications;

  late final CredentialStore _credentials =
      widget.credentialStore ?? CredentialStore();

  AuthTabGate get _authGate => widget.authGate;

  DownloadNotificationService _notifications() {
    return _downloadNotifications ??= Platform.isAndroid
        ? AndroidDownloadNotificationService()
        : const NoopDownloadNotificationService();
  }

  @override
  void initState() {
    super.initState();
    _refreshAuth();
  }

  Future<void> _refreshAuth() async {
    final creds = await _credentials.load();
    if (!mounted) return;
    final signedIn = creds != null && !creds.isEmpty;
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
    final next = _authGate.resolveSelection(
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
      if (next == AuthTabGate.watchfacesIndex) _watchfacesOpened = true;
      if (next == AuthTabGate.appsIndex) _appsOpened = true;
      if (next == AuthTabGate.firmwareIndex) _firmwareOpened = true;
    });
  }

  Widget _lockedIcon(
    IconData outlined,
    IconData filled, {
    required bool selected,
  }) {
    return Badge(
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
  }

  @override
  Widget build(BuildContext context) {
    // Keep analyzer happy if gate const differs in tests.
    assert(_gate.requiresAuth(AuthTabGate.gpsIndex));

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          CredentialsScreen(
            credentialStore: _credentials,
            onAuthChanged: _onAuthChanged,
          ),
          GpsFilesScreen(
            settingsEpoch: _gpsSettingsEpoch,
            credentialStore: _credentials,
          ),
          _watchfacesOpened
              ? StoreCatalogScreen(
                  entryType: StoreEntryType.watch,
                  notificationService: _notifications(),
                )
              : const SizedBox.shrink(),
          _appsOpened
              ? StoreCatalogScreen(
                  entryType: StoreEntryType.lightapp,
                  notificationService: _notifications(),
                )
              : const SizedBox.shrink(),
          _firmwareOpened
              ? FirmwareCheckScreen(notificationService: _notifications())
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
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
