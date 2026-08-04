import 'dart:async';

import 'package:flutter/material.dart';

import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/store/zepp_install_qr.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/screens/widgets/restorable_scroll_body.dart';
import 'package:zelp/screens/widgets/store_item_icon.dart';
import 'package:zelp/screens/widgets/store_item_screenshots.dart';
import 'package:zelp/screens/widgets/zepp_install_qr_dialog.dart';

/// Full-screen detail for one app or watchface (About / What’s new, actions).
class StoreItemDetailScreen extends StatelessWidget {
  const StoreItemDetailScreen({
    required this.item,
    required this.entryType,
    required this.sizeLabel,
    required this.existing,
    required this.busy,
    required this.loadIcon,
    required this.onDownload,
    required this.onShareExisting,
    required this.onToggleStar,
    super.key,
    this.compatibleWatchNames = const <String>[],
    this.onCopyLink,
    this.onMarkUpdateSeen,
  });

  final StoreItem item;
  final StoreEntryType entryType;
  final String sizeLabel;
  final ExistingDownloadMatch? existing;
  final bool busy;
  final bool loadIcon;
  final VoidCallback onDownload;
  final void Function(ExistingDownloadMatch match) onShareExisting;
  final VoidCallback onToggleStar;
  final List<String> compatibleWatchNames;
  final VoidCallback? onCopyLink;
  final VoidCallback? onMarkUpdateSeen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String description = item.description.trim();
    final String changelog = item.changelog.trim();
    final bool canQr = ZeppInstallQr.payloadFor(item) != null;
    final List<String> meta = <String>[
      if (item.version.isNotEmpty) 'Version ${item.version}',
      if (item.publisherName.isNotEmpty) item.publisherName,
      if (item.categoryName.isNotEmpty) item.categoryName,
      if (sizeLabel.isNotEmpty) sizeLabel,
      if (item.releasedDateLabel != null) 'Released ${item.releasedDateLabel}',
      if (item.isRemoved) 'Removed',
      if (item.isStarred) 'Starred',
      if (item.hasStarredUpdate) 'Has an update',
    ];

    final Widget icon = StoreItemIcon.detail(
      item: item,
      entryType: entryType,
      loadNetwork: loadIcon,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: <Widget>[
          IconButton(
            tooltip: item.isStarred ? 'Remove star' : 'Star',
            onPressed: busy ? null : onToggleStar,
            icon: Icon(item.isStarred ? Icons.star : Icons.star_border),
          ),
        ],
      ),
      body: RestorableScrollBody.list(
        storageId: 'store_detail_${entryType.apiValue}_${item.appId}',
        children: <Widget>[
          if (item.hasStarredUpdate)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.new_releases_outlined),
                title: const Text('Update available'),
                subtitle: Text(
                  'This starred ${entryType.singular} has a newer version '
                  '(${item.version}).',
                ),
                trailing: onMarkUpdateSeen == null
                    ? null
                    : TextButton(
                        onPressed: onMarkUpdateSeen,
                        child: const Text('Got it'),
                      ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              icon,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(item.name, style: theme.textTheme.titleLarge),
                    if (item.brief.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        item.brief,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (meta.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(meta.join(' · '), style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (item.screenshotUrls.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            StoreItemScreenshots(
              urls: item.screenshotUrls,
              loadNetwork: loadIcon,
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!item.isFree)
                Chip(
                  avatar: Icon(
                    Icons.paid,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  label: const Text('Paid'),
                )
              else
                FilledButton.icon(
                  onPressed: busy || item.isRemoved ? null : onDownload,
                  icon: Icon(existing != null ? Icons.refresh : Icons.download),
                  label: Text(existing != null ? 'Download again' : 'Download'),
                ),
              OutlinedButton.icon(
                onPressed: busy || !canQr
                    ? null
                    : () {
                        unawaited(showZeppInstallQrDialog(context, item: item));
                      },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Show QR code'),
              ),
              if (onCopyLink != null)
                OutlinedButton.icon(
                  onPressed: busy ? null : onCopyLink,
                  icon: const Icon(Icons.link),
                  label: const Text('Copy link'),
                ),
              if (existing != null)
                OutlinedButton.icon(
                  onPressed: () => onShareExisting(existing!),
                  icon: const Icon(Icons.share),
                  label: const Text('Share file'),
                ),
            ],
          ),
          if (existing != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Already downloaded: ${existing!.file.fileName}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (compatibleWatchNames.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text('Also works on', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              compatibleWatchNames.join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            Text('About', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodyMedium),
          ],
          if (changelog.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            Text('What’s new', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(changelog, style: theme.textTheme.bodyMedium),
          ],
          if (description.isEmpty && changelog.isEmpty) ...<Widget>[
            const SizedBox(height: 24),
            Text(
              'No description available yet. Try updating the list.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
