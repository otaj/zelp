import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/models/watch_model.dart';

void main() {
  group('WatchVariant.label', () {
    test('shows device source, not production id', () {
      final WatchVariant variant = WatchVariant(
        deviceSource: 851,
        productionId: 1,
        appName: 'com.huami.midong',
      );
      expect(variant.label, 'Device source 851');
      expect(variant.label, isNot(contains('Variant')));
    });
  });

  group('FirmwareInfo.fromApi', () {
    test('parses firmwareMd5 and changeLog / readme', () {
      final FirmwareInfo info = FirmwareInfo.fromApi(<String, dynamic>{
        'firmwareVersion': '1.2.3',
        'firmwareUrl': 'https://cdn.example/fw.bin',
        'firmwareMd5': '098f6bcd4621d373cade4e832627b4f6',
        'firmwareSize': 12,
        'changeLog': '  Fixed GPS  ',
      });
      expect(info.firmwareMd5, '098f6bcd4621d373cade4e832627b4f6');
      expect(info.firmwareChecksum?.hex, '098f6bcd4621d373cade4e832627b4f6');
      expect(info.firmwareSize, 12);
      expect(info.readmeOrChangelog, 'Fixed GPS');
    });

    test('readme falls back to readme field; empty hides', () {
      final FirmwareInfo withReadme = FirmwareInfo.fromApi(<String, dynamic>{
        'firmwareVersion': '1.0',
        'readme': 'Notes',
      });
      expect(withReadme.readmeOrChangelog, 'Notes');

      final FirmwareInfo empty = FirmwareInfo.fromApi(<String, dynamic>{
        'firmwareVersion': '1.0',
        'changeLog': '   ',
      });
      expect(empty.readmeOrChangelog, isNull);
      expect(empty.firmwareChecksum, isNull);
    });

    test('readmeOrChangelog drives collapsible UI content presence', () {
      // ExpansionTile is only built when this is non-null (collapsed by default).
      expect(
        FirmwareInfo(
          firmwareVersion: '1',
          changeLog: 'Notes',
        ).readmeOrChangelog,
        'Notes',
      );
      expect(FirmwareInfo(firmwareVersion: '1').readmeOrChangelog, isNull);
    });

    test('does not invent checksum when API omits firmwareMd5', () {
      final FirmwareInfo info = FirmwareInfo.fromApi(<String, dynamic>{
        'firmwareVersion': '9.9.9',
        'firmwareUrl': 'https://cdn.example/a.bin',
      });
      expect(info.firmwareMd5, isNull);
      expect(info.firmwareChecksum, isNull);
      expect(info.hasFirmware, isTrue);
    });

    test('hasFirmware is false without URL', () {
      final FirmwareInfo info = FirmwareInfo.fromApi(<String, dynamic>{'firmwareVersion': '1.0'});
      expect(info.hasFirmware, isFalse);
    });
  });

  group('FirmwareInfo.fromExplorer', () {
    test('maps version, downloadUrl, changelog, and releasedAt', () {
      final FirmwareInfo info = FirmwareInfo.fromExplorer(<String, dynamic>{
        'firmwareType': 'Firmware',
        'version': '3.12.4.1',
        'downloadUrl': 'https://cdn.example/fw.bin',
        'changelog': '  Notes  ',
        'releasedAt': '2026-07-24T02:42:05.004139',
      });
      expect(info.firmwareVersion, '3.12.4.1');
      expect(info.firmwareUrl, 'https://cdn.example/fw.bin');
      expect(info.readmeOrChangelog, 'Notes');
      expect(info.firmwareMd5, isNull);
      expect(info.releasedAt, DateTime.parse('2026-07-24T02:42:05.004139'));
      expect(info.filenameReleasedAt, isNull);
    });

    test('prefers the CDN filename stamp over explorer first-seen time', () {
      final FirmwareInfo info = FirmwareInfo.fromExplorer(<String, dynamic>{
        'firmwareType': 'Firmware',
        'version': '3.12.4.1',
        'downloadUrl':
            'https://huami-firmware-cdn.huami.com/11206915/'
            'fw_3.12.4.1_202607201712_bafba5185a274c8fbe95e652f3a9df0b_'
            'watch%40mhs003_ota_sign.zip',
        'releasedAt': '2026-07-24T02:42:05.004139',
      });
      expect(info.releasedAt, DateTime.utc(2026, 7, 20, 17, 12));
      expect(info.filenameReleasedAt, DateTime.utc(2026, 7, 20, 17, 12));
    });
  });

  group('StoredFirmwareHistory', () {
    test('storageKey includes device id and source', () {
      expect(StoredFirmwareHistory.storageKey('gtr4', 229), 'gtr4:229');
    });

    test('copyWithMerged updates same version and appends new', () {
      final StoredFirmwareHistory history = StoredFirmwareHistory(
        deviceId: 'gtr4',
        watchName: 'GTR 4',
        deviceSource: 229,
        versions: <FirmwareInfo>[FirmwareInfo(firmwareVersion: '1.0.0', firmwareUrl: 'old')],
      );

      final StoredFirmwareHistory merged = history.copyWithMerged(<FirmwareInfo>[
        FirmwareInfo(firmwareVersion: '1.0.0', firmwareUrl: 'new'),
        FirmwareInfo(firmwareVersion: '2.0.0'),
      ]);

      expect(merged.versions.length, 2);
      expect(merged.versions.first.firmwareUrl, 'new');
      expect(merged.latestVersion, '2.0.0');
    });

    test('copyWithMerged sorts by release time so a stored latest is not stuck first', () {
      final StoredFirmwareHistory history = StoredFirmwareHistory(
        deviceId: 'bipmax',
        watchName: 'Bip Max',
        deviceSource: 11206915,
        versions: <FirmwareInfo>[
          FirmwareInfo(firmwareVersion: '3.17.0.3', firmwareUrl: 'live'),
        ],
      );

      final StoredFirmwareHistory merged = history.copyWithMerged(<FirmwareInfo>[
        FirmwareInfo(
          firmwareVersion: '3.8.0.1',
          firmwareUrl: 'old',
          releasedAt: DateTime.utc(2026, 5, 29),
        ),
        FirmwareInfo(
          firmwareVersion: '3.12.4.1',
          firmwareUrl: 'mid',
          releasedAt: DateTime.utc(2026, 7, 24),
        ),
        FirmwareInfo(
          firmwareVersion: '3.17.0.3',
          firmwareUrl: 'live-updated',
          releasedAt: DateTime.utc(2026, 8, 21),
        ),
      ]);

      expect(
        merged.versions.map((FirmwareInfo v) => v.firmwareVersion).toList(),
        <String>['3.8.0.1', '3.12.4.1', '3.17.0.3'],
      );
      expect(merged.latestVersion, '3.17.0.3');
      expect(merged.versions.last.firmwareUrl, 'live-updated');
    });

    test('round-trips through JSON including md5', () {
      final StoredFirmwareHistory history = StoredFirmwareHistory(
        deviceId: 'bip5',
        watchName: 'Bip 5',
        deviceSource: 10,
        versions: <FirmwareInfo>[
          FirmwareInfo.fromApi(<String, dynamic>{
            'firmwareVersion': '3.2.1',
            'firmwareMd5': '098f6bcd4621d373cade4e832627b4f6',
            'changeLog': 'Notes',
            'releasedAt': '2026-07-24T02:42:05.004139Z',
          }),
        ],
        checkedAt: DateTime.utc(2026, 1, 2),
      );
      final StoredFirmwareHistory restored = StoredFirmwareHistory.fromJson(history.toJson());
      expect(restored.deviceId, 'bip5');
      expect(restored.deviceSource, 10);
      expect(restored.versions.single.firmwareVersion, '3.2.1');
      expect(
        restored.versions.single.firmwareMd5,
        '098f6bcd4621d373cade4e832627b4f6',
      );
      expect(restored.versions.single.readmeOrChangelog, 'Notes');
      expect(restored.versions.single.releasedAt?.toUtc(), DateTime.utc(2026, 7, 24, 2, 42, 5, 4, 139));
      expect(restored.checkedAt?.toUtc(), DateTime.utc(2026, 1, 2));
    });
  });
}
