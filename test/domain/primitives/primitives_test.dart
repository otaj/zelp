import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/domain/primitives/device_id.dart';
import 'package:zelp/domain/primitives/device_source.dart';
import 'package:zelp/domain/primitives/email_address.dart';
import 'package:zelp/domain/primitives/firmware_version.dart';
import 'package:zelp/domain/primitives/mac_address.dart';

void main() {
  group('EmailAddress', () {
    test('trims and accepts valid email', () {
      expect(EmailAddress('  a@b.co ').value, 'a@b.co');
    });

    test('rejects empty and malformed', () {
      expect(() => EmailAddress(''), throwsArgumentError);
      expect(() => EmailAddress('not-an-email'), throwsArgumentError);
    });

    test('equality by value', () {
      expect(EmailAddress('a@b.co'), EmailAddress('a@b.co'));
    });
  });

  group('DeviceId / DeviceSource', () {
    test('DeviceId rejects empty', () {
      expect(() => DeviceId(''), throwsArgumentError);
      expect(DeviceId('gtr4').value, 'gtr4');
    });

    test('DeviceSource rejects negative', () {
      expect(() => DeviceSource(-1), throwsArgumentError);
      expect(DeviceSource(229).value, 229);
    });

    test('DeviceSource allows zero', () {
      expect(DeviceSource(0).value, 0);
    });
  });

  group('FirmwareVersion / AppVersion', () {
    test('FirmwareVersion rejects empty', () {
      expect(() => FirmwareVersion('  '), throwsArgumentError);
      expect(FirmwareVersion.zero.value, '0');
    });

    test('AppVersion splits display and cv token', () {
      final AppVersion v = AppVersion('10.6.1-play_151920');
      expect(v.displayName, '10.6.1-play');
      expect(v.cvToken, '151920_10.6.1-play');
    });

    test('AppVersion without underscore keeps whole string', () {
      final AppVersion v = AppVersion('9.12.5');
      expect(v.displayName, '9.12.5');
      expect(v.cvToken, '9.12.5');
    });

    test('AppVersion rejects blank and equality uses value', () {
      expect(() => AppVersion('  '), throwsArgumentError);
      expect(
        AppVersion('10.6.1-play_151920'),
        AppVersion('10.6.1-play_151920'),
      );
      expect(FirmwareVersion.zero, FirmwareVersion('0'));
    });
  });

  group('MacAddress', () {
    test('stores trimmed value', () {
      expect(MacAddress(' AA:BB ').value, 'AA:BB');
      expect(() => MacAddress(''), throwsArgumentError);
      expect(MacAddress('AA:BB'), MacAddress('AA:BB'));
    });
  });
}
