import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/models/watch_model.dart';

void main() {
  group('FirmwareInfo.fromApi', () {
    test('parses firmwareMd5 and changeLog / readme', () {
      final info = FirmwareInfo.fromApi({
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
      final withReadme = FirmwareInfo.fromApi({
        'firmwareVersion': '1.0',
        'readme': 'Notes',
      });
      expect(withReadme.readmeOrChangelog, 'Notes');

      final empty = FirmwareInfo.fromApi({
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
      final info = FirmwareInfo.fromApi({
        'firmwareVersion': '9.9.9',
        'firmwareUrl': 'https://cdn.example/a.bin',
      });
      expect(info.firmwareMd5, isNull);
      expect(info.firmwareChecksum, isNull);
      expect(info.hasFirmware, isTrue);
    });

    test('hasFirmware is false without URL', () {
      final info = FirmwareInfo.fromApi({'firmwareVersion': '1.0'});
      expect(info.hasFirmware, isFalse);
    });
  });

  group('StoredFirmwareHistory', () {
    test('storageKey includes device id and source', () {
      expect(StoredFirmwareHistory.storageKey('gtr4', 229), 'gtr4:229');
    });

    test('copyWithMerged updates same version and appends new', () {
      final history = StoredFirmwareHistory(
        deviceId: 'gtr4',
        watchName: 'GTR 4',
        deviceSource: 229,
        versions: [FirmwareInfo(firmwareVersion: '1.0.0', firmwareUrl: 'old')],
      );

      final merged = history.copyWithMerged([
        FirmwareInfo(firmwareVersion: '1.0.0', firmwareUrl: 'new'),
        FirmwareInfo(firmwareVersion: '2.0.0'),
      ]);

      expect(merged.versions.length, 2);
      expect(merged.versions.first.firmwareUrl, 'new');
      expect(merged.latestVersion, '2.0.0');
    });

    test('round-trips through JSON including md5', () {
      final history = StoredFirmwareHistory(
        deviceId: 'bip5',
        watchName: 'Bip 5',
        deviceSource: 10,
        versions: [
          FirmwareInfo.fromApi({
            'firmwareVersion': '3.2.1',
            'firmwareMd5': '098f6bcd4621d373cade4e832627b4f6',
            'changeLog': 'Notes',
          }),
        ],
        checkedAt: DateTime.utc(2026, 1, 2),
      );
      final restored = StoredFirmwareHistory.fromJson(history.toJson());
      expect(restored.deviceId, 'bip5');
      expect(restored.deviceSource, 10);
      expect(restored.versions.single.firmwareVersion, '3.2.1');
      expect(
        restored.versions.single.firmwareMd5,
        '098f6bcd4621d373cade4e832627b4f6',
      );
      expect(restored.versions.single.readmeOrChangelog, 'Notes');
      expect(restored.checkedAt?.toUtc(), DateTime.utc(2026, 1, 2));
    });
  });
}
