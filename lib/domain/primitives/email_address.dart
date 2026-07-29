import 'package:meta/meta.dart';

/// Validated Amazfit/Zepp account email.
@immutable
class EmailAddress {
  EmailAddress(String raw) : value = raw.trim() {
    if (value.isEmpty) {
      throw ArgumentError.value(raw, 'email', 'Email must not be empty');
    }
    if (!_looksLikeEmail.hasMatch(value)) {
      throw ArgumentError.value(raw, 'email', 'Email looks invalid');
    }
  }

  static final RegExp _looksLikeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// True when [raw] would construct a valid [EmailAddress] without throwing.
  static bool isValid(String raw) {
    final String trimmed = raw.trim();
    return trimmed.isNotEmpty && _looksLikeEmail.hasMatch(trimmed);
  }

  final String value;

  @override
  bool operator ==(Object other) => other is EmailAddress && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
