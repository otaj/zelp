/// Catalog / firmware device identifier (e.g. watch model id string).
class DeviceId {
  DeviceId(String raw) : value = raw.trim() {
    if (value.isEmpty) {
      throw ArgumentError.value(raw, 'deviceId', 'Device id must not be empty');
    }
  }

  final String value;

  @override
  bool operator ==(Object other) => other is DeviceId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
