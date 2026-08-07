import 'package:flutter/material.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/store/store_item.dart';
import 'package:zelp/screens/widgets/store_item_icon.dart';

/// List tile for a store catalog item (star, download, open detail).
class StoreItemTile extends StatelessWidget {
  const StoreItemTile({
    required this.item,
    required this.entryType,
    required this.loadIcon,
    required this.existing,
    required this.busy,
    required this.sizeLabel,
    required this.onOpen,
    required this.onDownload,
    required this.onToggleStar,
    this.emphasizeUpdate = false,
    super.key,
  });

  final StoreItem item;
  final StoreEntryType entryType;
  final bool loadIcon;
  final ExistingDownloadMatch? existing;
  final bool busy;
  final String sizeLabel;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onToggleStar;
  final bool emphasizeUpdate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> subtitleParts = item.browseMetaParts(
      sizeLabel: sizeLabel,
      downloaded: existing != null,
    );

    final Widget leading = StoreItemIcon.list(
      item: item,
      entryType: entryType,
      loadNetwork: loadIcon,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: emphasizeUpdate ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.45) : null,
      child: ListTile(
        leading: leading,
        title: Text(item.name),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: item.isStarred ? 'Remove star' : 'Star',
              onPressed: busy ? null : onToggleStar,
              icon: Icon(
                item.isStarred ? Icons.star : Icons.star_border,
                color: item.isStarred ? theme.colorScheme.primary : null,
              ),
            ),
            if (!item.isFree)
              Tooltip(
                message: 'Paid',
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.paid,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              IconButton(
                tooltip: existing != null ? 'Download again' : 'Download',
                onPressed: busy || item.isRemoved ? null : onDownload,
                icon: Icon(existing != null ? Icons.refresh : Icons.download),
              ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}
