import 'package:flutter/material.dart';
import 'package:zelp/domain/primitives/local_datetime.dart';

/// Card showing the Zepp app version used for firmware checks, with refresh.
class FirmwareZeppVersionCard extends StatelessWidget {
  const FirmwareZeppVersionCard({
    required this.versionLabel,
    required this.fromCache,
    required this.checkedAt,
    required this.refreshing,
    required this.enabled,
    required this.onRefresh,
    this.onEdit,
    this.enteredManually = false,
    super.key,
  });

  final String versionLabel;
  final bool fromCache;
  final DateTime? checkedAt;
  final bool refreshing;
  final bool enabled;
  final VoidCallback onRefresh;

  /// When null, the version cannot be typed (expert mode is off).
  final VoidCallback? onEdit;

  /// True when [versionLabel] was typed, not fetched from Play.
  final bool enteredManually;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: <Widget>[
            const Icon(Icons.android),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Zepp app in use',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    versionLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    _sourceDetail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                key: const Key('zepp-version-edit'),
                tooltip: 'Enter Zepp app version',
                onPressed: enabled ? onEdit : null,
                icon: const Icon(Icons.edit_outlined),
              ),
            IconButton(
              tooltip: 'Update Zepp app version',
              onPressed: enabled ? onRefresh : null,
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }

  String get _sourceDetail {
    if (!fromCache) {
      return onEdit == null
          ? 'Built-in default — refresh for the latest'
          : 'Built-in default — refresh from Play, or enter the name and code';
    }
    final DateTime? at = checkedAt;
    final String when = at == null ? '' : ' · ${formatLocalDateTime(at)}';
    if (enteredManually) return 'Entered manually$when';
    if (at == null) return 'Saved on this device';
    return 'Saved$when';
  }
}
