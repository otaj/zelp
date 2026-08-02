/// Amazfit regions used when refreshing Apps / Watchfaces and checking firmware.
///
/// The market API filters catalogs by `user_country` / `Country`. Firmware
/// `hasNewVersion` similarly takes a `country` (and matching `lang`). A single
/// country (historically hardcoded `US` in Zelp) misses region-gated rows and
/// delayed firmware rollouts. Zepp Explorer indexes the same set:
/// `RU`, `CN`, `PL`, `US`.
const List<String> kDefaultMarketCountries = <String>['RU', 'CN', 'PL', 'US'];

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
