/// Compact `YYYYMMDDHHmm` tokens in Huami firmware CDN names.
///
/// Example: `fw_3.12.4.1_202607201712_<md5>_watch@mhs003_ota_sign.zip`.
class FirmwareReleaseStamp {
  FirmwareReleaseStamp._();

  static final RegExp _token = RegExp(r'_(20\d{10})(?:_|[.]|$)');

  /// Build timestamp from a firmware URL or basename, or null if none is valid.
  static DateTime? tryParse(String? urlOrName) {
    if (urlOrName == null) return null;
    final String trimmed = urlOrName.trim();
    if (trimmed.isEmpty) return null;

    String text = trimmed;
    try {
      text = Uri.decodeComponent(trimmed);
    } on FormatException {
      // Keep the raw string when the URL is not percent-encoded.
    }

    final int slash = text.lastIndexOf('/');
    final String haystack = slash >= 0 ? text.substring(slash + 1) : text;
    final Match? match = _token.firstMatch(haystack);
    if (match == null) return null;
    return _parseCompact(match.group(1)!);
  }

  static DateTime? _parseCompact(String stamp) {
    if (stamp.length != 12) return null;
    final int? year = int.tryParse(stamp.substring(0, 4));
    final int? month = int.tryParse(stamp.substring(4, 6));
    final int? day = int.tryParse(stamp.substring(6, 8));
    final int? hour = int.tryParse(stamp.substring(8, 10));
    final int? minute = int.tryParse(stamp.substring(10, 12));
    if (year == null || month == null || day == null || hour == null || minute == null) {
      return null;
    }
    if (year < 2015 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (hour > 23 || minute > 59) return null;
    final DateTime utc = DateTime.utc(year, month, day, hour, minute);
    if (utc.year != year || utc.month != month || utc.day != day) return null;
    return utc;
  }
}
