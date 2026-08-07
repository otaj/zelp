import 'package:flutter/material.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/store/store_item.dart';
import 'package:zelp/screens/store_item_detail_screen.dart';

/// Holds mutable [StoreItem] state while the detail route is open (stars / update-seen).
class StoreDetailHost extends StatefulWidget {
  const StoreDetailHost({
    required this.initial,
    required this.entryType,
    required this.sizeLabel,
    required this.existing,
    required this.busy,
    required this.loadIcon,
    required this.compatibleWatchNames,
    required this.onDownload,
    required this.onShareExisting,
    required this.onCopyLink,
    required this.onToggleStar,
    required this.onMarkUpdateSeen,
    super.key,
  });

  final StoreItem initial;
  final StoreEntryType entryType;
  final String sizeLabel;
  final ExistingDownloadMatch? existing;
  final bool busy;
  final bool loadIcon;
  final List<String> compatibleWatchNames;
  final void Function(StoreItem item) onDownload;
  final void Function(ExistingDownloadMatch match) onShareExisting;
  final void Function(StoreItem item) onCopyLink;
  final Future<StoreItem> Function(StoreItem item) onToggleStar;
  final Future<StoreItem> Function(StoreItem item) onMarkUpdateSeen;

  @override
  State<StoreDetailHost> createState() => _StoreDetailHostState();
}

class _StoreDetailHostState extends State<StoreDetailHost> {
  late StoreItem _item = widget.initial;

  @override
  Widget build(BuildContext context) => StoreItemDetailScreen(
    item: _item,
    entryType: widget.entryType,
    sizeLabel: widget.sizeLabel,
    existing: widget.existing,
    busy: widget.busy,
    loadIcon: widget.loadIcon,
    compatibleWatchNames: widget.compatibleWatchNames,
    onDownload: () => widget.onDownload(_item),
    onShareExisting: widget.onShareExisting,
    onCopyLink: _item.hasDownload ? () => widget.onCopyLink(_item) : null,
    onToggleStar: () async {
      final StoreItem next = await widget.onToggleStar(_item);
      if (mounted) setState(() => _item = next);
    },
    onMarkUpdateSeen: _item.hasStarredUpdate
        ? () async {
            final StoreItem next = await widget.onMarkUpdateSeen(_item);
            if (mounted) setState(() => _item = next);
          }
        : null,
  );
}
