/// Amazfit API `deviceSource` integer identifying a hardware channel/variant.
class DeviceSource {
  DeviceSource(this.value) {
    if (value < 0) {
      throw ArgumentError.value(
        value,
        'deviceSource',
        'Device source must be non-negative',
      );
    }
  }

  final int value;

  @override
  bool operator ==(Object other) =>
      other is DeviceSource && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}
