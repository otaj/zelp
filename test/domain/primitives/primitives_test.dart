import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/domain/primitives/byte_size.dart';
import 'package:zelp/domain/primitives/device_id.dart';
import 'package:zelp/domain/primitives/device_source.dart';
import 'package:zelp/domain/primitives/email_address.dart';
import 'package:zelp/domain/primitives/firmware_version.dart';
import 'package:zelp/domain/primitives/local_datetime.dart';
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

    test('FirmwareVersion.compareTo uses numeric dotted segments', () {
      expect(FirmwareVersion('3.8.0.1').compareTo(FirmwareVersion('3.12.4.1')), lessThan(0));
      expect(FirmwareVersion('3.12.4.1').compareTo(FirmwareVersion('3.17.0.3')), lessThan(0));
      expect(FirmwareVersion('1.0.0').compareTo(FirmwareVersion('1.0.0')), 0);
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
      expect(v.buildCode, isNull);
    });

    test('AppVersion.isNewerThan compares Play versionCode', () {
      final AppVersion older = AppVersion('10.6.1-play_151920');
      final AppVersion newer = AppVersion('10.7.3-play_151942');
      expect(newer.isNewerThan(older), isTrue);
      expect(older.isNewerThan(newer), isFalse);
      expect(newer.isNewerThan(newer), isFalse);
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

  group('format helpers', () {
    test('formatLocalDate / formatLocalDateTime', () {
      final DateTime utc = DateTime.utc(2024, 3, 5, 14, 7);
      expect(formatLocalDate(utc), matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(
        formatLocalDateTime(utc),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')),
      );
    });

    test('formatByteSize', () {
      expect(formatByteSize(null), '');
      expect(formatByteSize(0), '');
      expect(formatByteSize(500), '500 B');
      expect(formatByteSize(2048), '2.0 KB');
      expect(formatByteSize(2 * 1024 * 1024), '2.0 MB');
    });

    test('exceptionMessage prefers ZelpException.message', () {
      expect(exceptionMessage(ZelpException('oops')), 'oops');
      expect(exceptionMessage(Exception('raw')), contains('raw'));
    });
  });
}
