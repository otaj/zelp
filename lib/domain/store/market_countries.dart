import 'package:sealed_countries/sealed_countries.dart';

/// Amazfit regions used when refreshing Apps / Watchfaces and checking firmware.
///
/// The market API filters catalogs by `user_country` / `Country`. Firmware
/// `hasNewVersion` similarly takes a `country` (and matching `lang`). A single
/// country (historically hardcoded `US` in Zelp) misses region-gated rows and
/// delayed firmware rollouts. Zepp Explorer indexes the same set:
/// `RU`, `CN`, `PL`, `US`.
const List<String> kDefaultMarketCountries = <String>['RU', 'CN', 'PL', 'US'];

/// ISO 3166-1 country for [code], or null when it is not an assigned alpha-2 code.
WorldCountry? isoMarketCountry(String code) {
  final String trimmed = code.trim();
  if (trimmed.isEmpty) return null;
  return WorldCountry.maybeFromCodeShort(trimmed);
}

/// English country name for an ISO alpha-2 [country] code.
String labelForMarketCountry(String country) {
  final WorldCountry? match = isoMarketCountry(country);
  if (match == null) return country.trim().toUpperCase();
  return match.internationalName;
}

/// Flag emoji for an ISO alpha-2 [country] code, or empty when the code is unknown.
String flagForMarketCountry(String country) => isoMarketCountry(country)?.emoji ?? '';

/// Keeps assigned ISO 3166-1 alpha-2 codes, in the order given.
///
/// Unknown codes are dropped. Duplicates collapse to the first occurrence.
/// An empty or all-unknown selection falls back to [kDefaultMarketCountries]
/// so a refresh always has somewhere to query.
List<String> normalizeMarketCountries(Iterable<String> raw) {
  final List<String> kept = <String>[];
  final Set<String> seen = <String>{};
  for (final String code in raw) {
    final WorldCountry? match = isoMarketCountry(code);
    if (match == null) continue;
    if (!seen.add(match.codeShort)) continue;
    kept.add(match.codeShort);
  }
  if (kept.isEmpty) return List<String>.from(kDefaultMarketCountries);
  return kept;
}

/// ISO countries whose name or code matches [query], excluding [excluded] alpha-2 codes.
///
/// An empty [query] returns every country that is not excluded, sorted by English name.
List<WorldCountry> marketCountriesMatching(
  String query, {
  Iterable<String> excluded = const <String>[],
}) {
  final String needle = query.trim().toLowerCase();
  final Set<String> skip = <String>{
    for (final String code in excluded) code.trim().toUpperCase(),
  };
  final List<WorldCountry> matches =
      <WorldCountry>[
        for (final WorldCountry country in WorldCountry.list)
          if (!skip.contains(country.codeShort) && _countryMatches(country, needle)) country,
      ]..sort((WorldCountry a, WorldCountry b) {
        final int byName = a.internationalName.toLowerCase().compareTo(
          b.internationalName.toLowerCase(),
        );
        if (byName != 0) return byName;
        return a.codeShort.compareTo(b.codeShort);
      });
  return matches;
}

bool _countryMatches(WorldCountry country, String query) {
  if (query.isEmpty) return true;
  return country.internationalName.toLowerCase().contains(query) ||
      country.codeShort.toLowerCase().contains(query) ||
      country.code.toLowerCase().contains(query);
}

/// Zepp `lang` header/query value paired with a market [country] code.
String langForMarketCountry(String country) {
  switch (country.toUpperCase()) {
    case 'CN':
      return 'zh_CN';
    case 'RU':
      return 'ru_RU';
    case 'PL':
      return 'pl_PL';
    default:
      return 'en_US';
  }
}
