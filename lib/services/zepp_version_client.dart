import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/services/prefs_store.dart';
import 'package:zelp/services/zepp_version_parser.dart';

/// Fetches the latest Android Zepp (Play) app version from the Play Store.
///
/// Network access is optional for unit tests — inject `httpClient` or call
/// [ZeppVersionParser] directly with HTML fixtures.
class ZeppVersionClient extends PrefsStore {
  ZeppVersionClient({
    this.fallbackVersion = '10.7.3-play_151942',
    super.prefs,
    http.Client? httpClient,
    this._parser = const ZeppVersionParser(),
  }) : _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  static const String _cacheKey = 'zepp_play_version';
  static const String _cacheAtKey = 'zepp_play_version_checked_at';
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=${ZeppVersionParser.packageId}&hl=en&gl=US';

  final String fallbackVersion;
  final http.Client _http;
  final bool _ownsClient;
  final ZeppVersionParser _parser;

  static const Map<String, String> _headers = <String, String>{
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'accept-language': 'en-US,en;q=0.9',
    'user-agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36',
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

  Future<void> _save(String version) async {
    final SharedPreferences prefs = await ensurePrefs();
    await prefs.setString(_cacheKey, version);
    await prefs.setString(_cacheAtKey, DateTime.now().toIso8601String());
  }

  /// Persists [version] as the current Play build (no network).
  Future<void> cacheVersion(String version) => _save(AppVersion(version).value);

  /// Returns cached version, or [fallbackVersion] if nothing is stored.
  /// Never hits the network — call [refreshFromPlayStore] when the user asks.
  Future<String> current() async {
    final String? cached = await getCached();
    if (cached != null && cached.isNotEmpty) return cached;
    return fallbackVersion;
  }

  Future<AppVersion> currentAppVersion() async => AppVersion(await current());

  /// Scrapes the Play Store, caches the result, and returns it.
  Future<String> refreshFromPlayStore() async {
    final String latest = await fetchLatest();
    await _save(latest);
    return latest;
  }

  /// Scrapes Play Store for the current Zepp Android version name, then keeps
  /// Amazfit's `name_code` form using the last known Play versionCode.
  Future<String> fetchLatest() async {
    final http.Response page = await _http.get(Uri.parse(_playStoreUrl), headers: _headers);
    if (page.statusCode != 200) {
      throw DeviceException(
        'Play Store listing failed (status ${page.statusCode})',
        code: 'zepp-version-play',
      );
    }

    final String playName = _parser.parseVersionName(page.body);
    final String previous = (await getCached()) ?? fallbackVersion;
    return AppVersion(previous).withPlayName(playName).value;
  }

  void close() {
    if (_ownsClient) _http.close();
  }
}
