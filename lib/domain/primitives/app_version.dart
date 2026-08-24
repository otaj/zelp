import 'package:meta/meta.dart';

/// Zepp Play app version in `name_code` form (e.g. `10.6.1-play_151920`).
@immutable
class AppVersion {
  AppVersion(String raw) : value = raw.trim() {
    if (value.isEmpty) {
      throw ArgumentError.value(
        raw,
        'appVersion',
        'App version must not be empty',
      );
    }
  }

  final String value;

  /// Display portion before `_` (e.g. `10.6.1-play`).
  String get displayName {
    final int i = value.indexOf('_');
    return i < 0 ? value : value.substring(0, i);
  }

  /// Amazfit `cv` style (`code_name`) derived from `name_code`.
  String get cvToken {
    final List<String> parts = value.split('_');
    if (parts.length < 2) return value;
    return '${parts.last}_${parts.first}';
  }

  /// Play versionCode when [value] is `name_code` (e.g. `151920`).
  int? get buildCode {
    final int i = value.lastIndexOf('_');
    if (i < 0 || i == value.length - 1) return null;
    return int.tryParse(value.substring(i + 1));
  }

  /// True when this Play build is newer than [other] (by versionCode).
  bool isNewerThan(AppVersion other) {
    final int? a = buildCode;
    final int? b = other.buildCode;
    if (a != null && b != null) return a > b;
    return value.compareTo(other.value) > 0;
  }

  /// Play Store publishes [playName] only. Amazfit `cv` still needs `name_code`.
  AppVersion withPlayName(String playName) {
    final String name = playName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        playName,
        'playName',
        'Play version name must not be empty',
      );
    }
    final int? code = buildCode;
    if (code == null) return AppVersion(name);
    return AppVersion('${name}_$code');
  }

  @override
  bool operator ==(Object other) => other is AppVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
