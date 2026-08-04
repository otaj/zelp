/// One watch model that already has Apps / Watchfaces metadata in the local cache.
class StoreDeviceCacheMeta {
  const StoreDeviceCacheMeta({
    required this.deviceId,
    required this.deviceSource,
    required this.itemCount,
    this.refreshedAt,
  });

  final String deviceId;
  final int deviceSource;
  final int itemCount;
  final DateTime? refreshedAt;
}
