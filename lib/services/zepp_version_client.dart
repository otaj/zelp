import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/services/zepp_version_parser.dart';

/// Fetches the latest Android Zepp (Play) app version from APKMirror.
///
/// Network access is optional for unit tests — inject `httpClient` or call
/// [ZeppVersionParser] directly with HTML fixtures.
class ZeppVersionClient {
  ZeppVersionClient({
    this.fallbackVersion = '10.6.1-play_151920',
    SharedPreferences? prefs,
    http.Client? httpClient,
    this._parser = const ZeppVersionParser(),
  }) : _prefsOverride = prefs,
       _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  static const String _cacheKey = 'zepp_play_version';
  static const String _cacheAtKey = 'zepp_play_version_checked_at';
  static const String _listingUrl = 'https://www.apkmirror.com/apk/zepp-inc/amazfit-watch/';

  final String fallbackVersion;
  final SharedPreferences? _prefsOverride;
  final http.Client _http;
  final bool _ownsClient;
  final ZeppVersionParser _parser;
  SharedPreferences? _prefs;

  static const Map<String, String> _headers = <String, String>{
    'accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,'
        'image/webp,image/apng,*/*;q=0.8',
    'accept-language': 'en-US,en;q=0.9',
    'cache-control': 'no-cache',
    'pragma': 'no-cache',
    'upgrade-insecure-requests': '1',
    'user-agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36',
  };

  Future<SharedPreferences> _ensurePrefs() async => _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();

  Future<String?> getCached() async {
    final SharedPreferences prefs = await _ensurePrefs();
    return prefs.getString(_cacheKey);
  }

  Future<DateTime?> getCachedAt() async {
    final SharedPreferences prefs = await _ensurePrefs();
    final String? raw = prefs.getString(_cacheAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _save(String version) async {
    final SharedPreferences prefs = await _ensurePrefs();
    await prefs.setString(_cacheKey, version);
    await prefs.setString(_cacheAtKey, DateTime.now().toIso8601String());
  }

  /// Returns cached version, or [fallbackVersion] if nothing is stored.
  /// Never hits the network — call [refreshFromApkMirror] when the user asks.
  Future<String> current() async {
    final String? cached = await getCached();
    if (cached != null && cached.isNotEmpty) return cached;
    return fallbackVersion;
  }

  Future<AppVersion> currentAppVersion() async => AppVersion(await current());

  /// Scrapes APKMirror, caches the result, and returns it.
  Future<String> refreshFromApkMirror() async {
    final String latest = await fetchLatest();
    await _save(latest);
    return latest;
  }

  /// Scrapes APKMirror for the newest Zepp Android build (`name_code`).
  Future<String> fetchLatest() async {
    final http.Response listing = await _http.get(Uri.parse(_listingUrl), headers: _headers);
    if (listing.statusCode != 200) {
      throw DeviceException(
        'APKMirror listing failed (status ${listing.statusCode})',
        code: 'zepp-version-listing',
      );
    }

    final String versionHref = _parser.parseLatestVersionHref(listing.body);
    final Uri detailUrl = _parser.resolveDetailUrl(versionHref);
    final http.Response detail = await _http.get(detailUrl, headers: _headers);
    if (detail.statusCode != 200) {
      throw DeviceException(
        'APKMirror detail failed (status ${detail.statusCode})',
        code: 'zepp-version-detail',
      );
    }

    return _parser.parseVersionFromDetailHtml(detail.body);
  }

  /// Exposed for tests / callers that already have a [Document].
  String? findLatestVersionHref(Document listingDoc) => _parser.findLatestVersionHref(listingDoc);

  String parseVersionFromDetail(Document detailDoc) => _parser.parseVersionFromDetail(detailDoc);

  void close() {
    if (_ownsClient) _http.close();
  }
}
