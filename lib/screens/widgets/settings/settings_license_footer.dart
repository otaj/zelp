import 'package:flutter/material.dart';
import 'package:zelp/legal/zelp_legal.dart';

/// License and source line at the bottom of Settings.
class SettingsLicenseFooter extends StatelessWidget {
  const SettingsLicenseFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(
        '${ZelpLegal.licenseNotice}\n${ZelpLegal.sourceUrl}',
        style: style,
      ),
    );
  }
}
