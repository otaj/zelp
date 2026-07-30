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

  @override
  bool operator ==(Object other) => other is FirmwareVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
