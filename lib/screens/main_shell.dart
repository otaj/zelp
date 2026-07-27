import 'package:flutter/material.dart';

import '../services/credential_store.dart';
import 'credentials_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.credentialStore,
  });

  final CredentialStore? credentialStore;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final CredentialStore _credentials =
      widget.credentialStore ?? CredentialStore();

  @override
  Widget build(BuildContext context) {
    return CredentialsScreen(
      credentialStore: _credentials,
    );
  }
}
