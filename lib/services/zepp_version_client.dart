import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/services/keep_alive_http_client.dart';
import 'package:zelp/services/prefs_store.dart';
import 'package:zelp/services/zepp_version_parser.dart';

/// Fetches the latest official Zepp (Play) version name and versionCode.
///
/// The Play Store page is the version name. The public Play catalog supplies
/// the matching versionCode. A refresh is stored only when those names agree.
///
/// Network access is optional for unit tests — inject `httpClient` or call
/// [ZeppVersionParser] directly with fixtures.
class ZeppVersionClient extends PrefsStore {
  ZeppVersionClient({
    this.fallbackVersion = '10.10.5-play_151997',
    super.prefs,
    http.Client? httpClient,
    this._parser = const ZeppVersionParser(),
  }) : _http = httpClient ?? zelpHttpClient(),
       _ownsClient = httpClient == null;

  static const String _cacheKey = 'zepp_play_version';
  static const String _cacheAtKey = 'zepp_play_version_checked_at';
  static const String _cacheSourceKey = 'zepp_play_version_source';
  static const String _sourcePlay = 'play';
  static const String _sourceManual = 'manual';
  static const String _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36';
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=${ZeppVersionParser.packageId}&hl=en&gl=US';
  static const String _catalogUrl = 'https://www.apk20.com/playstore/api/database/apk/${ZeppVersionParser.packageId}';

  final String fallbackVersion;
  final http.Client _http;
  final bool _ownsClient;
  final ZeppVersionParser _parser;

  static const Map<String, String> _playHeaders = <String, String>{
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'accept-language': 'en-US,en;q=0.9',
    'user-agent': _userAgent,
  };

  static const Map<String, String> _catalogHeaders = <String, String>{
    'accept': 'application/json',
    'user-agent': _userAgent,
  };

  Future<String?> getCached() async {
    final SharedPreferences prefs = await ensurePrefs();
    return prefs.getString(_cacheKey);
  }

  Future<DateTime?> getCachedAt() async {
    final SharedPreferences prefs = await ensurePrefs();
    final String? raw = prefs.getString(_cacheAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _save(String version, {required String source}) async {
    final SharedPreferences prefs = await ensurePrefs();
    await prefs.setString(_cacheKey, version);
    await prefs.setString(_cacheAtKey, DateTime.now().toIso8601String());
    await prefs.setString(_cacheSourceKey, source);
  }

  /// Persists [version] as the current Play build (no network).
  Future<void> cacheVersion(String version) => _save(AppVersion(version).value, source: _sourcePlay);

  /// Persists a version name and code typed on the firmware screen.
  Future<void> saveManual(AppVersion version) => _save(version.value, source: _sourceManual);

  /// True when the cached build was typed in, not fetched from Play.
  Future<bool> wasEnteredManually() async {
    final String? cached = await getCached();
    if (cached == null || cached.isEmpty) return false;
    final SharedPreferences prefs = await ensurePrefs();
    return prefs.getString(_cacheSourceKey) == _sourceManual;
  }

  /// Returns cached version, or [fallbackVersion] if nothing is stored.
  /// Never hits the network — call [refreshFromPlayStore] when the user asks.
  Future<String> current() async {
    final String? cached = await getCached();
    if (cached != null && cached.isNotEmpty) return cached;
    return fallbackVersion;
  }

  Future<AppVersion> currentAppVersion() async => AppVersion(await current());

  /// Loads the current official Play build, caches it, and returns it.
  Future<String> refreshFromPlayStore() async {
    final String latest = await fetchLatest();
    await _save(latest, source: _sourcePlay);
    return latest;
  }

  /// Official Play version in Amazfit `name_code` form (`10.10.5-play_151997`).
  ///
  /// The Play listing must publish the same version name as the catalog entry
  /// that carries the versionCode. A newer Play name is not paired with an
  /// older code.
  Future<String> fetchLatest() async {
    final List<http.Response> responses = await Future.wait<http.Response>(<Future<http.Response>>[
      _http.get(Uri.parse(_playStoreUrl), headers: _playHeaders),
      _http.get(Uri.parse(_catalogUrl), headers: _catalogHeaders),
    ]);
    final http.Response play = responses[0];
    final http.Response catalog = responses[1];
    if (play.statusCode != 200) {
      throw DeviceException(
        'Play Store listing failed (status ${play.statusCode})',
        code: 'zepp-version-play',
      );
    }
    if (catalog.statusCode != 200) {
      throw DeviceException(
        'Play version catalog failed (status ${catalog.statusCode})',
        code: 'zepp-version-catalog',
      );
    }

    final String playName = _parser.parseVersionName(play.body);
    final AppVersion release = _parser.parseCatalogRelease(catalog.body);
    if (release.displayName != playName) {
      throw DeviceException(
        'Play Store lists $playName but the version catalog lists ${release.displayName}',
        code: 'zepp-version-mismatch',
      );
    }
    return release.value;
  }

  void close() {
    if (_ownsClient) _http.close();
  }
}
