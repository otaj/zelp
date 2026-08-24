import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/services/zepp_version_client.dart';

import '../helpers/play_store_html.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZeppVersionClient cache', () {
    test('current uses fallback when cache empty (no network)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
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

    test('refreshFromPlayStore uses mock HTTP and keeps name_code', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.url.host, 'play.google.com');
        expect(
          request.url.queryParameters['id'],
          'com.huami.watch.hmwatchmanager',
        );
        return http.Response(playStoreHtml(version: '10.6.1-play'), 200);
      });

      final ZeppVersionClient client = ZeppVersionClient(
        prefs: prefs,
        fallbackVersion: '10.6.1-play_151920',
        httpClient: mock,
      );
      final String version = await client.refreshFromPlayStore();
      expect(version, '10.6.1-play_151920');
      expect(await client.getCached(), '10.6.1-play_151920');
      final ZeppVersionClient offline = ZeppVersionClient(
        prefs: prefs,
        httpClient: MockClient((_) async {
          fail('should use cache');
        }),
      );
      expect(await offline.current(), '10.6.1-play_151920');
    });

    test('refreshFromPlayStore reuses last known versionCode for a new name', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'zepp_play_version': '10.6.1-play_151920',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final MockClient mock = MockClient(
        (_) async => http.Response(playStoreHtml(), 200),
      );

      final ZeppVersionClient client = ZeppVersionClient(
        prefs: prefs,
        fallbackVersion: '10.6.1-play_151920',
        httpClient: mock,
      );
      expect(await client.refreshFromPlayStore(), '10.7.3-play_151920');
    });

    test('refreshFromPlayStore throws on non-200', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final ZeppVersionClient client = ZeppVersionClient(
        prefs: prefs,
        httpClient: MockClient((_) async => http.Response('nope', 403)),
      );
      expect(
        client.refreshFromPlayStore(),
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.code,
            'code',
            'zepp-version-play',
          ),
        ),
      );
    });
  });
}
