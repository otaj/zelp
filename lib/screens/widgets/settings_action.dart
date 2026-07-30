import 'package:flutter/material.dart';

/// AppBar action that opens the Settings / first-time setup screen.
class SettingsAction extends StatelessWidget {
  const SettingsAction({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Settings',
    onPressed: onPressed,
    icon: const Icon(Icons.settings_outlined),
  );
}
