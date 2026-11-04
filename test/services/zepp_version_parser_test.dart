import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/services/zepp_version_parser.dart';

import '../helpers/play_catalog_json.dart';
import '../helpers/play_store_html.dart';

void main() {
  const ZeppVersionParser parser = ZeppVersionParser();

  group('ZeppVersionParser Play Store', () {
    test('reads version name from ds details path 140', () {
      expect(parser.parseVersionName(playStoreHtml()), '10.7.3-play');
    });

    test('reads version from keyed fallback on the last details element', () {
      expect(
        parser.parseVersionName(playStoreHtml(asKeyedFallback: true)),
        '10.7.3-play',
      );
    });

    test('finds the details blob even when the ds key is not 5', () {
      expect(
        parser.parseVersionName(playStoreHtml(dsKey: 6, version: '10.8.0-play')),
        '10.8.0-play',
      );
    });

    test('rejects a page without the Zepp package id', () {
      expect(
        () => parser.parseVersionName(
          playStoreHtml(packageId: 'com.example.missing'),
        ),
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.code,
            'code',
            'zepp-version-play',
          ),
        ),
      );
    });

    test('rejects a page that lacks version details', () {
      expect(
        () => parser.parseVersionName('''
<html><body>${ZeppVersionParser.packageId}
<script>AF_initDataCallback({key: 'ds:2', hash: '1', data:[1], sideChannel: {}});</script>
</body></html>
'''),
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.code,
            'code',
            'zepp-version-parse',
          ),
        ),
      );
    });
  });

  group('ZeppVersionParser Play catalog', () {
    test('reads version name and version code when both listings agree', () {
      final AppVersion release = parser.parseCatalogRelease(playCatalogJson());
      expect(release.value, '10.10.5-play_151997');
      expect(release.displayName, '10.10.5-play');
      expect(release.buildCode, 151997);
    });

    test('uses the highest history version code regardless of order', () {
      expect(
        parser
            .parseCatalogRelease(
              playCatalogJson(
                includeLastVersion: false,
                version: '10.7.3-play',
                versionCode: 151942,
                history: const <({String version, int versionCode})>[
                  (version: '10.10.5-play', versionCode: 151997),
                ],
              ),
            )
            .value,
        '10.10.5-play_151997',
      );
    });

    test('accepts lastVersion when history is absent', () {
      expect(
        parser.parseCatalogRelease(playCatalogJson(includeHistory: false)).value,
        '10.10.5-play_151997',
      );
    });

    test('rejects a catalog whose listings disagree', () {
      expect(
        () => parser.parseCatalogRelease(
          playCatalogJson(
            history: const <({String version, int versionCode})>[
              (version: '10.10.6-play', versionCode: 152000),
            ],
          ),
        ),
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.code,
            'code',
            'zepp-version-parse',
          ),
        ),
      );
    });

    test('rejects a catalog for a different package', () {
      expect(
        () => parser.parseCatalogRelease(
          playCatalogJson(packageId: 'com.example.missing'),
        ),
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.code,
            'code',
            'zepp-version-parse',
          ),
        ),
      );
    });

    test('rejects an empty catalog', () {
      expect(
        () => parser.parseCatalogRelease('[]'),
        throwsA(
          isA<DeviceException>().having(
            (DeviceException e) => e.code,
            'code',
            'zepp-version-parse',
          ),
        ),
      );
    });
  });
}
