import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/crypto/zepp_crypto.dart';
import 'package:zelp/models/device.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/exceptions.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('zeppEncryptForm', () {
    test('is deterministic for the same payload', () {
      final payload = {
        'emailOrPhone': 'a@b.co',
        'password': 'secret',
        'token': ['access', 'refresh'],
      };
      final a = zeppEncryptForm(payload);
      final b = zeppEncryptForm(payload);
      expect(a, b);
      expect(a, isNotEmpty);
    });

    test('changes when password changes', () {
      final a = zeppEncryptForm({'password': 'one'});
      final b = zeppEncryptForm({'password': 'two'});
      expect(a, isNot(equals(b)));
    });
  });

  group('Device.fromZepp', () {
    test('parses mac, active flag, and auth key', () {
      final device = Device.fromZepp({
        'macAddress': 'AA:BB:CC:DD:EE:FF',
        'activeStatus': 1,
        'additionalInfo': jsonEncode({'auth_key': 'deadbeef'}),
      });
      expect(device.mac, 'AA:BB:CC:DD:EE:FF');
      expect(device.active, isTrue);
      expect(device.displayKey, '0xdeadbeef');
    });

    test('prefixes 0x only when missing', () {
      final device = Device.fromZepp({
        'macAddress': '11:22:33:44:55:66',
        'activeStatus': 0,
        'additionalInfo': jsonEncode({'auth_key': '0xabc'}),
      });
      expect(device.active, isFalse);
      expect(device.displayKey, '0xabc');
    });

    test('tolerates malformed additionalInfo JSON', () {
      final device = Device.fromZepp({
        'macAddress': 'AA:BB:CC:DD:EE:FF',
        'activeStatus': 1,
        'additionalInfo': '{not-json',
      });
      expect(device.displayKey, '0x??');
    });
  });

  group('DeviceCatalog.parseDeviceListJson', () {
    test('maps variants and sorts by name', () {
      final watches = DeviceCatalog.parseDeviceListJson(
        jsonEncode([
          {
            'id': 'b',
            'deviceName': 'Zebra',
            'osVersion': '3',
            'deviceSource': [1],
            'productionId': [10],
          },
          {
            'id': 'a',
            'shortDeviceName': 'Alpha',
            'osVersion': '2',
            'application': 'com.example',
            'deviceSource': [2, 3],
            'productionId': [20, 30],
          },
        ]),
      );
      expect(watches.map((w) => w.name), ['Alpha', 'Zebra']);
      expect(watches.first.variants.length, 2);
      expect(watches.first.variants.first.appName, 'com.example');
    });

    test('skips empty ids and mismatched source lists', () {
      final watches = DeviceCatalog.parseDeviceListJson(
        jsonEncode([
          {
            'id': '',
            'deviceName': 'Bad',
            'deviceSource': [1],
            'productionId': [1],
          },
          {
            'id': 'ok',
            'deviceName': 'Ok',
            'deviceSource': [1, 2],
            'productionId': [1],
          },
        ]),
      );
      expect(watches, isEmpty);
    });

    test('rejects non-list JSON body', () {
      expect(
        () => DeviceCatalog.parseDeviceListJson('{"not":"a list"}'),
        throwsA(
          isA<DeviceException>().having(
            (e) => e.code,
            'code',
            'device-list-invalid',
          ),
        ),
      );
    });
  });

  group('DeviceCatalog.load', () {
    test('uses mock HTTP and caches until forceRefresh', () async {
      var hits = 0;
      final mock = MockClient((_) async {
        hits++;
        return http.Response(
          jsonEncode([
            {
              'id': 'gtr4',
              'deviceName': 'GTR 4',
              'osVersion': '3',
              'deviceSource': [229],
              'productionId': [1],
            },
          ]),
          200,
        );
      });
      final catalog = DeviceCatalog(httpClient: mock);
      addTearDown(catalog.close);

      final first = await catalog.load();
      final second = await catalog.load();
      expect(first.single.name, 'GTR 4');
      expect(identical(first, second), isTrue);
      expect(hits, 1);

      await catalog.load(forceRefresh: true);
      expect(hits, 2);
    });
  });
}
