import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/services/zepp_version_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZeppVersionClient cache', () {
    test('current uses fallback when cache empty (no network)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      // MockClient that fails if any real request is attempted.
      final ZeppVersionClient client = ZeppVersionClient(
        prefs: prefs,
        fallbackVersion: '9.0.0-play_1',
        httpClient: MockClient((_) async {
          fail('network must not be called for current()');
        }),
      );

      expect(await client.current(), '9.0.0-play_1');
      expect(await client.getCached(), isNull);
    });

    test('current prefers cached value without network', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'zepp_play_version': '10.6.1-play_151920',
        'zepp_play_version_checked_at': '2026-01-01T00:00:00.000Z',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ZeppVersionClient client = ZeppVersionClient(
        prefs: prefs,
        httpClient: MockClient((_) async {
          fail('network must not be called for current()');
        }),
      );

      expect(await client.current(), '10.6.1-play_151920');
      expect(await client.getCachedAt(), isNotNull);
    });

    test('refreshFromApkMirror uses mock HTTP and updates cache', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final MockClient mock = MockClient((http.Request request) async {
        if (request.url.path.contains('amazfit-watch') && !request.url.path.contains('release')) {
          return http.Response('''
<html><head><title>Download Zepp APKs for Android</title></head>
<body><div><div class="widgetHeader">All versions</div>
<a class="fontBlack" href="/apk/zepp-inc/amazfit-watch/amazfit-watch-10-6-1-play-release/">x</a>
</div></body></html>
''', 200);
        }
        return http.Response('''
<html><head><title>APK Download by Zepp, Inc.</title></head>
<body><div>
<h3>Download Zepp 10.6.1-play</h3>
<div class="table-row">h</div>
<div class="table-row"><span class="colorLightBlack">151920</span></div>
</div></body></html>
''', 200);
      });

      final ZeppVersionClient client = ZeppVersionClient(prefs: prefs, httpClient: mock);
      final String version = await client.refreshFromApkMirror();
      expect(version, '10.6.1-play_151920');
      expect(await client.getCached(), '10.6.1-play_151920');
      // Subsequent current() stays offline.
      final ZeppVersionClient offline = ZeppVersionClient(
        prefs: prefs,
        httpClient: MockClient((_) async {
          fail('should use cache');
        }),
      );
      expect(await offline.current(), '10.6.1-play_151920');
    });
  });
}
