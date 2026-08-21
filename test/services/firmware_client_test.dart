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

  bool isExplorerFirmware(http.Request request) => request.url.path.contains('/api/v1/device/firmwares/');

  Map<String, dynamic> explorerFwJson(
    String version, {
    required String releasedAt,
    String? url,
    String type = 'Firmware',
  }) => <String, dynamic>{
    'firmwareType': type,
    'version': version,
    'downloadUrl': ?url,
    'changelog': 'notes $version',
    'releasedAt': releasedAt,
  };

  test('fetchFullHistory starts from version zero', () async {
    final List<String> fromVersions = <String>[];
    final MockClient mock = MockClient((http.Request request) async {
      if (isExplorerFirmware(request)) {
        return http.Response('[]', 200);
      }
      fromVersions.add(request.url.queryParameters['firmwareVersion']!);
      final String fw = request.url.queryParameters['firmwareVersion']!;
      if (fw == '0') {
        return http.Response(jsonEncode(fwJson('1.0.0', url: 'https://cdn/a.bin')), 200);
      }
      if (fw == '1.0.0') {
        return http.Response(jsonEncode(fwJson('2.0.0', url: 'https://cdn/b.bin')), 200);
      }
      return http.Response('{}', 200);
    });

    final FirmwareClient client = await buildClient(
      mock: mock,
      countries: const <String>['US'],
    );
    final List<FirmwareInfo> found = await client.fetchFullHistory(
      variant: variant,
      timezone: 'UTC',
    );

    expect(fromVersions.first, '0');
    expect(found.map((FirmwareInfo f) => f.firmwareVersion).toList(), <String>[
      '1.0.0',
      '2.0.0',
    ]);
    client.close();
  });

  test('fetchFullHistory merges explorer archive with the live OTA hop', () async {
    final MockClient mock = MockClient((http.Request request) async {
      if (isExplorerFirmware(request)) {
        expect(request.url.path, endsWith('/firmwares/${variant.deviceSource}'));
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            explorerFwJson('2.0.0', releasedAt: '2026-07-24T00:00:00', url: 'https://cdn/old-latest.bin'),
            explorerFwJson('1.5.0', releasedAt: '2026-05-01T00:00:00', url: 'https://cdn/mid.bin'),
            explorerFwJson('1.0.0', releasedAt: '2026-04-01T00:00:00', url: 'https://cdn/old.bin'),
            explorerFwJson('9.9.9', releasedAt: '2026-04-01T00:00:00', type: 'GPS data'),
          ]),
          200,
        );
      }
      final String fw = request.url.queryParameters['firmwareVersion']!;
      if (fw == '0') {
        return http.Response(jsonEncode(fwJson('2.0.0', url: 'https://cdn/live.bin')), 200);
      }
      return http.Response('{}', 200);
    });

    final FirmwareClient client = await buildClient(
      mock: mock,
      countries: const <String>['US'],
    );
    final List<FirmwareInfo> found = await client.fetchFullHistory(
      variant: variant,
      timezone: 'UTC',
    );

    expect(found.map((FirmwareInfo f) => f.firmwareVersion).toList(), <String>[
      '1.0.0',
      '1.5.0',
      '2.0.0',
    ]);
    expect(found.last.firmwareUrl, 'https://cdn/live.bin');
    client.close();
  });

  test('fetchFullHistory keeps the live chain when explorer is down', () async {
    final MockClient mock = MockClient((http.Request request) async {
      if (isExplorerFirmware(request)) {
        return http.Response('nope', 503);
      }
      final String fw = request.url.queryParameters['firmwareVersion']!;
      if (fw == '0') {
        return http.Response(jsonEncode(fwJson('3.0.0', url: 'https://cdn/live.bin')), 200);
      }
      return http.Response('{}', 200);
    });

    final FirmwareClient client = await buildClient(
      mock: mock,
      countries: const <String>['US'],
    );
    final List<FirmwareInfo> found = await client.fetchFullHistory(
      variant: variant,
      timezone: 'UTC',
    );

    expect(found.single.firmwareVersion, '3.0.0');
    client.close();
  });

  test('mergeFirmwareHistories prefers live URLs and appends unseen live versions', () {
    final List<FirmwareInfo> merged = FirmwareClient.mergeFirmwareHistories(
      archived: <FirmwareInfo>[
        FirmwareInfo(firmwareVersion: '1.0.0', firmwareUrl: 'https://cdn/old.bin'),
        FirmwareInfo(firmwareVersion: '2.0.0'),
      ],
      live: <FirmwareInfo>[
        FirmwareInfo(firmwareVersion: '2.0.0', firmwareUrl: 'https://cdn/live.bin'),
        FirmwareInfo(firmwareVersion: '3.0.0', firmwareUrl: 'https://cdn/new.bin'),
      ],
    );
    expect(merged.map((FirmwareInfo f) => f.firmwareVersion).toList(), <String>[
      '1.0.0',
      '2.0.0',
      '3.0.0',
    ]);
    expect(merged[1].firmwareUrl, 'https://cdn/live.bin');
  });

  test('mergeFirmwareHistories keeps archive release dates when overlaying live URLs', () {
    final DateTime released = DateTime.utc(2026, 8, 21);
    final List<FirmwareInfo> merged = FirmwareClient.mergeFirmwareHistories(
      archived: <FirmwareInfo>[
        FirmwareInfo(
          firmwareVersion: '3.8.0.1',
          firmwareUrl: 'https://cdn/old.bin',
          releasedAt: DateTime.utc(2026, 5, 29),
        ),
        FirmwareInfo(
          firmwareVersion: '3.17.0.3',
          firmwareUrl: 'https://cdn/archive.bin',
          releasedAt: released,
        ),
      ],
      live: <FirmwareInfo>[
        FirmwareInfo(firmwareVersion: '3.17.0.3', firmwareUrl: 'https://cdn/live.bin'),
      ],
    );
    expect(
      merged.map((FirmwareInfo f) => f.firmwareVersion).toList(),
      <String>['3.8.0.1', '3.17.0.3'],
    );
    expect(merged.last.firmwareUrl, 'https://cdn/live.bin');
    expect(merged.last.releasedAt, released);
  });

  test('OTA walk stops when Amazfit repeats the same firmwareVersion', () async {
    int hops = 0;
    final MockClient mock = MockClient((http.Request request) async {
      hops++;
      return http.Response(jsonEncode(fwJson('1.0.0', url: 'https://cdn/a.bin')), 200);
    });

    final FirmwareClient client = await buildClient(
      mock: mock,
      countries: const <String>['US'],
    );
    final List<FirmwareInfo> found = await client.checkUpdates(
      variant: variant,
      timezone: 'UTC',
    );

    expect(found.single.firmwareVersion, '1.0.0');
    expect(hops, 2);
    client.close();
  });

  test('checkUpdates can start after a known version', () async {
    final List<String> fromVersions = <String>[];
    final MockClient mock = MockClient((http.Request request) async {
      fromVersions.add(request.url.queryParameters['firmwareVersion']!);
      final String fw = request.url.queryParameters['firmwareVersion']!;
      if (fw == '1.0.0') {
        return http.Response(jsonEncode(fwJson('2.0.0', url: 'https://cdn/b.bin')), 200);
      }
      return http.Response('{}', 200);
    });

    final FirmwareClient client = await buildClient(
      mock: mock,
      countries: const <String>['US'],
    );
    final List<FirmwareInfo> found = await client.checkUpdates(
      variant: variant,
      fromVersion: '1.0.0',
      timezone: 'UTC',
    );

    expect(fromVersions, <String>['1.0.0', '2.0.0']);
    expect(found.single.firmwareVersion, '2.0.0');
    client.close();
  });

  test('checkUpdates adopts a newer explorer Play version for Amazfit requests', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zepp_play_version': '10.6.1-play_151920',
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> appVersions = <String>[];
    final MockClient mock = MockClient((http.Request request) async {
      if (request.url.path == '/api/constants') {
        return http.Response(
          jsonEncode(<String, String>{'zeppVersion': '10.7.3-play_151942'}),
          200,
        );
      }
      expect(request.url.path, '/devices/ALL/hasNewVersion');
      appVersions.add(request.url.queryParameters['appVersion']!);
      final String fw = request.url.queryParameters['firmwareVersion']!;
      if (fw == '3.12.4.1') {
        return http.Response(jsonEncode(fwJson('3.17.0.3', url: 'https://cdn/new.bin')), 200);
      }
      return http.Response('{}', 200);
    });

    final ZeppVersionClient versions = ZeppVersionClient(
      prefs: prefs,
      fallbackVersion: '10.6.1-play_151920',
      httpClient: MockClient((_) async => fail('APKMirror must not run')),
    );
    final FirmwareClient client = FirmwareClient(
      httpClient: mock,
      countries: const <String>['US'],
      zeppVersionClient: versions,
    );
    final List<FirmwareInfo> found = await client.checkUpdates(
      variant: variant,
      fromVersion: '3.12.4.1',
      timezone: 'UTC',
    );

    expect(appVersions, everyElement('10.7.3-play_151942'));
    expect(found.single.firmwareVersion, '3.17.0.3');
    expect(await versions.getCached(), '10.7.3-play_151942');
    client.close();
  });

  test('checkUpdates keeps the cached Play version when explorer constants fail', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'zepp_play_version': '10.6.1-play_151920',
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> appVersions = <String>[];
    final MockClient mock = MockClient((http.Request request) async {
      if (request.url.path == '/api/constants') {
        return http.Response('nope', 503);
      }
      appVersions.add(request.url.queryParameters['appVersion']!);
      return http.Response('{}', 200);
    });

    final FirmwareClient client = FirmwareClient(
      httpClient: mock,
      countries: const <String>['US'],
      zeppVersionClient: ZeppVersionClient(
        prefs: prefs,
        fallbackVersion: '10.6.1-play_151920',
        httpClient: MockClient((_) async => fail('APKMirror must not run')),
      ),
    );
    await client.checkUpdates(variant: variant, timezone: 'UTC');

    expect(appVersions, everyElement('10.6.1-play_151920'));
    client.close();
  });
}
