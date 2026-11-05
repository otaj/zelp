import 'package:flutter/material.dart';

/// Settings switch for firmware, Zepp version, and store-region controls.
class SettingsExpertModeSection extends StatelessWidget {
  const SettingsExpertModeSection({
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Expert mode', style: theme.textTheme.titleMedium),
        CheckboxListTile(
          key: const Key('expert-mode'),
          contentPadding: EdgeInsets.zero,
          value: value,
          onChanged: enabled ? onChanged : null,
          title: const Text('Show expert controls'),
          subtitle: const Text(
            'On Firmware, type the version on your watch for a smaller diff, '
            'and the official Zepp app version name and code. On Apps and '
            'Watchfaces, choose which countries Update list queries.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}
