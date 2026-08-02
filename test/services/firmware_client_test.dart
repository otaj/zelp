import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/firmware_client.dart';
import 'package:zelp/services/zepp_version_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final WatchVariant variant = WatchVariant(
    deviceSource: 229,
    productionId: 1,
    appName: 'com.huami.midong',
  );

  Future<FirmwareClient> buildClient({
    required MockClient mock,
    List<String>? countries,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return FirmwareClient(
      httpClient: mock,
      countries: countries,
      zeppVersion: '10.0.0-play_1',
      zeppVersionClient: ZeppVersionClient(
        prefs: prefs,
        fallbackVersion: '10.0.0-play_1',
        httpClient: MockClient((_) async => fail('APKMirror must not run')),
      ),
    );
  }

  Map<String, dynamic> fwJson(String version, {String? url}) => <String, dynamic>{
    'firmwareVersion': version,
    'firmwareUrl': ?url,
  };

  test('merges firmware chains across regions', () async {
    final List<String> countriesHit = <String>[];
    final MockClient mock = MockClient((http.Request request) async {
      expect(request.url.path, '/devices/ALL/hasNewVersion');
      final String country = request.url.queryParameters['country']!;
      expect(request.headers['country'], country);
      countriesHit.add(country);

      final String fw = request.url.queryParameters['firmwareVersion']!;
      if (country == 'CN') {
        if (fw == '0') {
          return http.Response(jsonEncode(fwJson('1.0.0', url: 'https://cdn/cn.bin')), 200);
        }
        if (fw == '1.0.0') {
          return http.Response(jsonEncode(fwJson('2.0.0', url: 'https://cdn/new.bin')), 200);
        }
        return http.Response('{}', 200);
      }
      if (country == 'US') {
        if (fw == '0') {
          return http.Response(jsonEncode(fwJson('1.0.0', url: 'https://cdn/us.bin')), 200);
        }
        return http.Response('{}', 200);
      }
      return http.Response('{}', 200);
    });

    final FirmwareClient client = await buildClient(
      mock: mock,
      countries: const <String>['CN', 'US'],
    );
    final List<FirmwareInfo> found = await client.checkUpdates(
      variant: variant,
      timezone: 'UTC',
    );

    expect(countriesHit.toSet(), <String>{'CN', 'US'});
    expect(found.map((FirmwareInfo f) => f.firmwareVersion).toList(), <String>[
      '1.0.0',
      '2.0.0',
    ]);
    // First region that listed 1.0.0 keeps its URL.
    expect(found.first.firmwareUrl, 'https://cdn/cn.bin');
    expect(found.last.firmwareUrl, 'https://cdn/new.bin');
    client.close();
  });

  test('prefers firmwareUrl when merging the same version', () async {
    final MockClient mock = MockClient((http.Request request) async {
      final String country = request.url.queryParameters['country']!;
      final String fw = request.url.queryParameters['firmwareVersion']!;
      if (fw != '0') return http.Response('{}', 200);
      if (country == 'RU') {
        return http.Response(jsonEncode(fwJson('1.5.0')), 200);
      }
      if (country == 'US') {
        return http.Response(jsonEncode(fwJson('1.5.0', url: 'https://cdn/us.bin')), 200);
      }
      return http.Response('{}', 200);
    });

    final FirmwareClient client = await buildClient(
      mock: mock,
      countries: const <String>['RU', 'US'],
    );
    final List<FirmwareInfo> found = await client.checkUpdates(
      variant: variant,
      timezone: 'UTC',
    );

    expect(found, hasLength(1));
    expect(found.single.firmwareVersion, '1.5.0');
    expect(found.single.firmwareUrl, 'https://cdn/us.bin');
    client.close();
  });

  test('succeeds when one region fails and another returns updates', () async {
    final MockClient mock = MockClient((http.Request request) async {
      final String country = request.url.queryParameters['country']!;
      if (country == 'CN') {
        return http.Response('boom', 500);
      }
      final String fw = request.url.queryParameters['firmwareVersion']!;
      if (fw == '0') {
        return http.Response(jsonEncode(fwJson('3.0.0', url: 'https://cdn/pl.bin')), 200);
      }
      return http.Response('{}', 200);
    });

    final FirmwareClient client = await buildClient(
      mock: mock,
      countries: const <String>['CN', 'PL'],
    );
    final List<FirmwareInfo> found = await client.checkUpdates(
      variant: variant,
      timezone: 'UTC',
    );

    expect(found.single.firmwareVersion, '3.0.0');
    client.close();
  });

  test('throws when every region fails', () async {
    final MockClient mock = MockClient((_) async => http.Response('nope', 503));

    final FirmwareClient client = await buildClient(
      mock: mock,
      countries: const <String>['US', 'CN'],
    );

    await expectLater(
      client.checkUpdates(variant: variant, timezone: 'UTC'),
      throwsA(
        isA<DeviceException>().having(
          (DeviceException e) => e.code,
          'code',
          'firmware-check-failed',
        ),
      ),
    );
    client.close();
  });

  test('pairs lang with country', () async {
    final Map<String, String> langs = <String, String>{};
    final MockClient mock = MockClient((http.Request request) async {
      final String country = request.url.queryParameters['country']!;
      langs[country] = request.url.queryParameters['lang']!;
      expect(request.headers['lang'], langs[country]);
      return http.Response('{}', 200);
    });

    final FirmwareClient client = await buildClient(
      mock: mock,
      countries: const <String>['RU', 'CN', 'PL', 'US'],
    );
    await client.checkUpdates(variant: variant, timezone: 'UTC');

    expect(langs, <String, String>{
      'RU': 'ru_RU',
      'CN': 'zh_CN',
      'PL': 'pl_PL',
      'US': 'en_US',
    });
    client.close();
  });
}
