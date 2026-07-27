/// Zepp Play app version in `name_code` form (e.g. `10.6.1-play_151920`).
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
    final i = value.indexOf('_');
    return i < 0 ? value : value.substring(0, i);
  }

  /// Amazfit `cv` style (`code_name`) derived from `name_code`.
  String get cvToken {
    final parts = value.split('_');
    if (parts.length < 2) return value;
    return '${parts.last}_${parts.first}';
  }

  @override
  bool operator ==(Object other) => other is AppVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
