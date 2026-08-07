import 'package:flutter/material.dart';
import 'package:zelp/domain/primitives/local_datetime.dart';
import 'package:zelp/domain/store/store_device_cache_meta.dart';
import 'package:zelp/domain/store/store_item.dart';
import 'package:zelp/models/watch_model.dart';

/// Collapsible summary of watches that already have a local catalog refresh.
class CollectedDataSummary extends StatelessWidget {
  const CollectedDataSummary({
    required this.entryType,
    required this.devices,
    required this.watches,
    required this.selectedDeviceId,
    required this.enabled,
    required this.onSelectDeviceId,
    super.key,
  });

  final StoreEntryType entryType;
  final List<StoreDeviceCacheMeta> devices;
  final List<WatchModel> watches;
  final String? selectedDeviceId;
  final bool enabled;
  final ValueChanged<String> onSelectDeviceId;

  String _nameFor(String deviceId) {
    for (final WatchModel watch in watches) {
      if (watch.deviceId == deviceId) return watch.name;
    }
    return deviceId;
  }

  String _subtitleFor(StoreDeviceCacheMeta meta) {
    final String countLabel =
        '${meta.itemCount} '
        '${meta.itemCount == 1 ? entryType.singular : entryType.label.toLowerCase()}';
    final DateTime? refreshed = meta.refreshedAt;
    if (refreshed == null) return countLabel;
    return '$countLabel · last updated ${formatLocalDateTime(refreshed)}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String kind = entryType.label.toLowerCase();
    final int count = devices.length;
    final String collapsedHint = count == 1 ? '1 watch with collected $kind' : '$count watches with collected $kind';

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(8),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Distinct from RestorableScrollBody's ListView PageStorageKey so
          // expansion state is not confused with the scroll offset (double).
          key: PageStorageKey<String>('store_collected_${entryType.apiValue}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: const Icon(Icons.inventory_2_outlined),
          title: const Text('Collected data'),
          subtitle: Text(collapsedHint),
          children: <Widget>[
            for (final StoreDeviceCacheMeta meta in devices)
              ListTile(
                dense: true,
                enabled: enabled,
                selected: meta.deviceId == selectedDeviceId,
                title: Text(_nameFor(meta.deviceId)),
                subtitle: Text(_subtitleFor(meta)),
                onTap: enabled ? () => onSelectDeviceId(meta.deviceId) : null,
              ),
          ],
        ),
      ),
    );
  }
}
