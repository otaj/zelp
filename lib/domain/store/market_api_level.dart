/// Encodes a Zepp [API_LEVEL](https://docs.zepp.com/docs/guides/framework/device/compatibility/)
/// string (`major.minor` / `major.minor.patch`) as the Amazfit market
/// `api_level` query integer.
///
/// Device firmware reports the same scale (Gadgetbridge: `200` = `2.0`).
/// Unparseable input falls back to [fallback] (explorer’s historical “show
/// everything” ceiling).
int marketApiLevelFromVersion(String raw, {int fallback = 500}) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;

  final List<String> parts = trimmed.split('.');
  final int? major = int.tryParse(parts[0]);
  if (major == null) return fallback;
  final int minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  return major * 100 + minor;
}
