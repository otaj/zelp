/// Coercion helpers for JSON / SQLite dynamic values.
String jsonAsString(Object? value, {bool trim = true}) {
  if (value == null) return '';
  final String text = value.toString();
  return trim ? text.trim() : text;
}

/// Like [jsonAsString], but returns null when missing or blank after trim.
String? jsonAsStringOrNull(Object? value) {
  if (value == null) return null;
  final String text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? jsonAsInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return int.tryParse(value.toString());
}
