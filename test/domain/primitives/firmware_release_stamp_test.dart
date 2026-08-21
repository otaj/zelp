import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/primitives/firmware_release_stamp.dart';

void main() {
  group('FirmwareReleaseStamp.tryParse', () {
    test('reads YYYYMMDDHHmm from a Huami CDN basename', () {
      const String url =
          'https://huami-firmware-cdn.huami.com/11206915/'
          'fw_3.12.4.1_202607201712_bafba5185a274c8fbe95e652f3a9df0b_'
          'watch%40mhs003_ota_sign.zip';
      expect(
        FirmwareReleaseStamp.tryParse(url),
        DateTime.utc(2026, 7, 20, 17, 12),
      );
    });

    test('returns null when the name has no compact stamp', () {
      expect(
        FirmwareReleaseStamp.tryParse('https://cdn.example/fw.bin'),
        isNull,
      );
      expect(FirmwareReleaseStamp.tryParse(null), isNull);
      expect(FirmwareReleaseStamp.tryParse(''), isNull);
    });

    test('rejects tokens that are not a real calendar time', () {
      expect(
        FirmwareReleaseStamp.tryParse('fw_1.0.0_202613011200_deadbeef.zip'),
        isNull,
      );
      expect(
        FirmwareReleaseStamp.tryParse('fw_1.0.0_202602311200_deadbeef.zip'),
        isNull,
      );
    });
  });
}
