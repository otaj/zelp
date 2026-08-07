import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/device_usage_store.dart';

/// Applies tab epoch bumps shared by Firmware and Store catalog screens.
void applyTabEpochChanges({
  required int oldSettingsEpoch,
  required int settingsEpoch,
  required int oldDeviceUsageEpoch,
  required int deviceUsageEpoch,
  required void Function() onSettingsEpoch,
  required void Function() onDeviceUsageEpoch,
}) {
  if (oldSettingsEpoch != settingsEpoch) {
    onSettingsEpoch();
  }
  if (oldDeviceUsageEpoch != deviceUsageEpoch) {
    onDeviceUsageEpoch();
  }
}

/// Reorders [watches] by shared MRU preference.
///
/// Returns `null` when [watches] is empty (nothing to sync).
Future<({List<WatchModel> ordered, WatchModel? preferred})?> orderedWatchesForSharedMru({
  required DeviceUsageStore usage,
  required List<WatchModel> watches,
}) async {
  if (watches.isEmpty) return null;
  return usage.orderedWatchesWithPreferred(
    watches: watches,
    deviceIdOf: (WatchModel w) => w.deviceId,
  );
}
