import 'package:meta/meta.dart';

/// Firmware version string as returned by Amazfit (`hasNewVersion`).
@immutable
class FirmwareVersion {
  FirmwareVersion(String raw) : value = raw.trim() {
    if (value.isEmpty) {
      throw ArgumentError.value(
        raw,
        'firmwareVersion',
        'Firmware version must not be empty',
      );
    }
  }

  /// Sentinel used when walking the update chain from scratch.
  static final FirmwareVersion zero = FirmwareVersion('0');

  final String value;

  /// Numeric dotted-segment order (`3.8.0.1` < `3.12.4.1`).
  int compareTo(FirmwareVersion other) {
    final List<int> a = _numericParts(value);
    final List<int> b = _numericParts(other.value);
    final int n = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < n; i++) {
      final int av = i < a.length ? a[i] : 0;
      final int bv = i < b.length ? b[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return value.compareTo(other.value);
  }

  static List<int> _numericParts(String raw) {
    final List<int> parts = <int>[];
    for (final String piece in raw.split('.')) {
      final int? n = int.tryParse(RegExp(r'^\d+').stringMatch(piece) ?? '');
      if (n == null) break;
      parts.add(n);
    }
    return parts;
  }

  @override
  bool operator ==(Object other) => other is FirmwareVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
