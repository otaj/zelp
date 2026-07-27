/// Validated Amazfit/Zepp account email.
class EmailAddress {
  EmailAddress(String raw) : value = raw.trim() {
    if (value.isEmpty) {
      throw ArgumentError.value(raw, 'email', 'Email must not be empty');
    }
    if (!_looksLikeEmail.hasMatch(value)) {
      throw ArgumentError.value(raw, 'email', 'Email looks invalid');
    }
  }

  static final _looksLikeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final String value;

  @override
  bool operator ==(Object other) =>
      other is EmailAddress && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
