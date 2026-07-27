import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/zepp/zepp_version_parser.dart';
import 'package:zelp/services/exceptions.dart';

void main() {
  const parser = ZeppVersionParser();

  group('ZeppVersionParser listing', () {
    test('parses All versions widget href', () {
      const listing = '''
<html><head><title>Download Zepp APKs for Android - APKMirror</title></head>
<body>
<div><div class="widgetHeader">All versions</div>
<a class="fontBlack" href="/apk/zepp-inc/amazfit-watch/amazfit-watch-10-6-1-play-release/">10.6.1</a>
</div>
</body></html>
''';
      expect(
        parser.parseLatestVersionHref(listing),
        '/apk/zepp-inc/amazfit-watch/amazfit-watch-10-6-1-play-release/',
      );
    });

    test('falls back to first fontBlack link when widget missing', () {
      const listing = '''
<html><head><title>Download Zepp APKs for Android</title></head>
<body>
<a class="fontBlack" href="/apk/zepp-inc/amazfit-watch/fallback-release/">x</a>
</body></html>
''';
      expect(
        parser.parseLatestVersionHref(listing),
        '/apk/zepp-inc/amazfit-watch/fallback-release/',
      );
    });

    test('rejects unexpected listing title', () {
      expect(
        () => parser.parseLatestVersionHref(
          '<html><head><title>Blocked</title></head></html>',
        ),
        throwsA(
          isA<DeviceException>().having(
            (e) => e.code,
            'code',
            'zepp-version-listing',
          ),
        ),
      );
    });

    test('rejects listing with no version link', () {
      expect(
        () => parser.parseLatestVersionHref(
          '<html><head><title>Download Zepp APKs for Android</title></head>'
          '<body><p>empty</p></body></html>',
        ),
        throwsA(
          isA<DeviceException>().having(
            (e) => e.code,
            'code',
            'zepp-version-link',
          ),
        ),
      );
    });
  });

  group('ZeppVersionParser detail', () {
    test('parses name_code from h3 + version code row', () {
      const detail = '''
<html><head><title>Zepp 10.6.1-play APK Download by Zepp, Inc.</title></head>
<body>
<div>
  <h3>Download Zepp 10.6.1-play</h3>
  <div class="table-row">header</div>
  <div class="table-row"><span class="colorLightBlack">151920</span></div>
</div>
</body></html>
''';
      expect(parser.parseVersionFromDetailHtml(detail), '10.6.1-play_151920');
    });

    test('rejects unexpected detail title', () {
      expect(
        () => parser.parseVersionFromDetailHtml(
          '<html><head><title>Captcha</title></head></html>',
        ),
        throwsA(
          isA<DeviceException>().having(
            (e) => e.code,
            'code',
            'zepp-version-detail',
          ),
        ),
      );
    });

    test('rejects detail missing version code', () {
      expect(
        () => parser.parseVersionFromDetailHtml('''
<html><head><title>APK Download by Zepp, Inc.</title></head>
<body><div><h3>Download Zepp 1.0.0</h3>
<div class="table-row">only one</div>
</div></body></html>
'''),
        throwsA(
          isA<DeviceException>().having(
            (e) => e.code,
            'code',
            'zepp-version-parse',
          ),
        ),
      );
    });
  });

  group('resolveDetailUrl', () {
    test('keeps absolute hrefs and joins relative ones', () {
      expect(
        parser.resolveDetailUrl('https://cdn.example/x').toString(),
        'https://cdn.example/x',
      );
      expect(
        parser.resolveDetailUrl('/apk/zepp/release/').toString(),
        'https://www.apkmirror.com/apk/zepp/release/',
      );
    });
  });
}
