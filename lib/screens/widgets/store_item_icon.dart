import 'package:flutter/material.dart';

import 'package:zelp/models/store_item.dart';

/// Network (or fallback) icon for a store list tile or detail header.
class StoreItemIcon extends StatelessWidget {
  const StoreItemIcon({
    required this.item,
    required this.entryType,
    required this.size,
    required this.borderRadius,
    this.loadNetwork = true,
    this.fallbackIconSize,
    super.key,
  });

  /// Compact list-tile sizes.
  factory StoreItemIcon.list({
    required StoreItem item,
    required StoreEntryType entryType,
    bool loadNetwork = true,
    Key? key,
  }) {
    final bool watch = entryType == StoreEntryType.watch;
    return StoreItemIcon(
      key: key,
      item: item,
      entryType: entryType,
      size: watch ? 56 : 40,
      borderRadius: watch ? 12 : 8,
      loadNetwork: loadNetwork,
    );
  }

  /// Larger detail-header sizes.
  factory StoreItemIcon.detail({
    required StoreItem item,
    required StoreEntryType entryType,
    bool loadNetwork = true,
    Key? key,
  }) {
    final bool watch = entryType == StoreEntryType.watch;
    return StoreItemIcon(
      key: key,
      item: item,
      entryType: entryType,
      size: 72,
      borderRadius: watch ? 16 : 12,
      loadNetwork: loadNetwork,
      fallbackIconSize: 48,
    );
  }

  final StoreItem item;
  final StoreEntryType entryType;
  final double size;
  final double borderRadius;
  final bool loadNetwork;
  final double? fallbackIconSize;

  IconData get _fallbackIcon => entryType == StoreEntryType.watch ? Icons.watch : Icons.apps;

  @override
  Widget build(BuildContext context) {
    if (loadNetwork && item.iconUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          item.iconUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, Object error, StackTrace? stackTrace) => Icon(_fallbackIcon, size: fallbackIconSize),
        ),
      );
    }
    return Icon(_fallbackIcon, size: fallbackIconSize ?? size * 0.6);
  }
}
