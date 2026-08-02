/// Zero-pads [n] to two digits (`7` → `"07"`).
String _two(int n) => n.toString().padLeft(2, '0');

/// Local `YYYY-MM-DD HH:MM` for status lines and “last updated” labels.
String formatLocalDateTime(DateTime time) {
  final DateTime local = time.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// Local calendar day `YYYY-MM-DD` (no clock time).
String formatLocalDate(DateTime time) {
  final DateTime local = time.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)}';
}
