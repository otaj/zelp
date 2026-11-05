/// Upload day embedded in Amazfit store package URLs.
///
/// Watchface list rows often send `updated_at: 0`. The package URL still
/// carries the day the file was published:
/// `https://store-cdn.zepp.com/custom_user_app/20261104/<token>/1130086.zip`.
class StorePackageStamp {
  StorePackageStamp._();

  static final RegExp _day = RegExp(r'custom_user_app/(20\d{2})(\d{2})(\d{2})(?:/|$)');

  /// Calendar day from a store package URL, or null when none is present.
  ///
  /// Stored at 12:00 UTC so [DateTime.toLocal] keeps that calendar day in
  /// ordinary time zones. The URL has no clock time.
  static DateTime? tryParse(String? url) {
    if (url == null) return null;
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    String text = trimmed;
    try {
      text = Uri.decodeComponent(trimmed);
    } on FormatException {
      // Keep the raw string when the URL is not percent-encoded.
    }

    final Match? match = _day.firstMatch(text);
    if (match == null) return null;
    return _parseDay(match.group(1)!, match.group(2)!, match.group(3)!);
  }

  static DateTime? _parseDay(String yearText, String monthText, String dayText) {
    final int? year = int.tryParse(yearText);
    final int? month = int.tryParse(monthText);
    final int? day = int.tryParse(dayText);
    if (year == null || month == null || day == null) return null;
    if (year < 2015 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    final DateTime utc = DateTime.utc(year, month, day, 12);
    if (utc.year != year || utc.month != month || utc.day != day) return null;
    return utc;
  }
}
