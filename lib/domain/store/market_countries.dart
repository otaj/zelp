/// Amazfit market regions used when refreshing Apps / Watchfaces.
///
/// The market API filters catalogs by `user_country` / `Country`. A single
/// country (historically hardcoded `US` in Zelp) misses region-gated rows.
/// Zepp Explorer indexes the same set: `RU`, `CN`, `PL`, `US`.
const List<String> kDefaultMarketCountries = <String>['RU', 'CN', 'PL', 'US'];
