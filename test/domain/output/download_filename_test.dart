import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/output/download_filename.dart';

void main() {
  group('DownloadFilename.sanitize', () {
    test('keeps safe characters and collapses unsafe runs', () {
      expect(DownloadFilename.sanitize('Amazfit GTR 4'), 'Amazfit_GTR_4');
      expect(DownloadFilename.sanitize('T-Rex Ultra'), 'T-Rex_Ultra');
      expect(DownloadFilename.sanitize('  a//b  '), 'a_b');
      expect(DownloadFilename.sanitize(''), 'file');
    });
  });

  group('DownloadFilename.forStoreItem', () {
    test('uses CDN basename when semantic is off', () {
      expect(
        DownloadFilename.forStoreItem(
          name: 'Circle Face',
          version: '1.0',
          downloadUrl: 'https://cdn.example/opaque/face.zip',
          appId: 1,
          kindSingular: 'watchface',
          semantic: false,
        ),
        'face.zip',
      );
      expect(
        DownloadFilename.forStoreItem(
          name: 'Circle Face',
          version: '1.0',
          downloadUrl: 'https://cdn.example/opaque/face.zip',
          appId: 1,
          kindSingular: 'watchface',
          semantic: true,
        ),
        'Circle_Face_1.0.zip',
      );
    });

    test('falls back for apps without URL', () {
      expect(
        DownloadFilename.forStoreItem(
          name: 'Workout+',
          version: '3.1/rc',
          downloadUrl: '',
          appId: 42,
          kindSingular: 'app',
          semantic: false,
        ),
        'app_42_3.1_rc.zip',
      );
      expect(
        DownloadFilename.forStoreItem(
          name: 'Workout+',
          version: '3.1/rc',
          downloadUrl: '',
          appId: 42,
          kindSingular: 'app',
          semantic: true,
        ),
        'Workout_3.1_rc.zip',
      );
    });
  });

  group('DownloadFilename.forFirmware', () {
    test('semantic prefers device name over CDN basename', () {
      expect(
        DownloadFilename.forFirmware(
          firmwareVersion: '2.0.0',
          firmwareUrl: 'https://cdn.example/fw/opaque.bin',
          deviceName: 'Amazfit Balance',
          semantic: true,
        ),
        'Amazfit_Balance_2.0.0.bin',
      );
      expect(
        DownloadFilename.forFirmware(
          firmwareVersion: '2.0.0',
          firmwareUrl: 'https://cdn.example/fw/opaque.bin',
          deviceName: 'Amazfit Balance',
          semantic: false,
        ),
        'opaque.bin',
      );
    });
  });
}
