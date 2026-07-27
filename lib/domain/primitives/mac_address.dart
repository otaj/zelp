/// Bluetooth MAC as shown for paired Zepp devices.
class MacAddress {
  MacAddress(String raw) : value = raw.trim() {
    if (value.isEmpty) {
      throw ArgumentError.value(raw, 'mac', 'MAC must not be empty');
    }
  }

  final String value;

  @override
  bool operator ==(Object other) => other is MacAddress && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
