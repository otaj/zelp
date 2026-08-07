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
    super.key,
  });

  final String versionLabel;
  final bool fromCache;
  final DateTime? checkedAt;
  final bool refreshing;
  final bool enabled;
  final VoidCallback onRefresh;

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
                    fromCache
                        ? (checkedAt == null ? 'Saved on this device' : 'Saved · ${formatLocalDateTime(checkedAt!)}')
                        : 'Built-in default — refresh for the latest',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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
}
