import 'package:flutter/material.dart';

/// Settings switch for typing a firmware baseline and a Zepp app version.
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
          title: const Text('Enter firmware and Zepp versions'),
          subtitle: const Text(
            'On the firmware screen, type the version on your watch '
            'for a smaller diff, and the official Zepp app version name and code.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}
