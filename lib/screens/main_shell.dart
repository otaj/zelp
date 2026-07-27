import 'package:flutter/material.dart';

import '../domain/navigation/auth_tab_gate.dart';
import '../services/credential_store.dart';
import 'credentials_screen.dart';
import 'gps_files_screen.dart';

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
  int _index = AuthTabGate.credentialsIndex;
  bool _signedIn = false;
  int _gpsSettingsEpoch = 0;

  late final CredentialStore _credentials =
      widget.credentialStore ?? CredentialStore();

  AuthTabGate get _authGate => widget.authGate;

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
        ],
      ),
    );
  }
}
