import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/services/zepp_version_parser.dart';

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
}
