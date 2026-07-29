import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelp/crypto/zepp_crypto.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/models/device.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/device_catalog.dart';

void main() {
  group('zeppEncryptForm', () {
    test('is deterministic for the same payload', () {
      final Map<String, Object> payload = <String, Object>{
        'emailOrPhone': 'a@b.co',
        'password': 'secret',
        'token': <String>['access', 'refresh'],
      };
      final Uint8List a = zeppEncryptForm(payload);
      final Uint8List b = zeppEncryptForm(payload);
      expect(a, b);
      expect(a, isNotEmpty);
    });

    test('changes when password changes', () {
      final Uint8List a = zeppEncryptForm(<String, dynamic>{'password': 'one'});
      final Uint8List b = zeppEncryptForm(<String, dynamic>{'password': 'two'});
      expect(a, isNot(equals(b)));
    });
  });

  group('Device.fromZepp', () {
    test('parses mac, active flag, and auth key', () {
      final Device device = Device.fromZepp(<String, dynamic>{
        'macAddress': 'AA:BB:CC:DD:EE:FF',
        'activeStatus': 1,
        'additionalInfo': jsonEncode(<String, String>{'auth_key': 'deadbeef'}),
      });
      expect(device.mac, 'AA:BB:CC:DD:EE:FF');
      expect(device.active, isTrue);
      expect(device.displayKey, '0xdeadbeef');
    });

    test('prefixes 0x only when missing', () {
      final Device device = Device.fromZepp(<String, dynamic>{
        'macAddress': '11:22:33:44:55:66',
        'activeStatus': 0,
        'additionalInfo': jsonEncode(<String, String>{'auth_key': '0xabc'}),
      });
      expect(device.active, isFalse);
      expect(device.displayKey, '0xabc');
    });

    test('tolerates malformed additionalInfo JSON', () {
      final Device device = Device.fromZepp(<String, dynamic>{
        'macAddress': 'AA:BB:CC:DD:EE:FF',
        'activeStatus': 1,
        'additionalInfo': '{not-json',
      });
      expect(device.displayKey, '0x??');
    });
  });

  group('DeviceCatalog.parseDeviceListJson', () {
    test('maps variants and sorts by name', () {
      final List<WatchModel> watches = DeviceCatalog.parseDeviceListJson(
        jsonEncode(<Map<String, Object>>[
          <String, Object>{
            'id': 'b',
            'deviceName': 'Zebra',
            'osVersion': '3',
            'deviceSource': <int>[1],
            'productionId': <int>[10],
          },
          <String, Object>{
            'id': 'a',
            'shortDeviceName': 'Alpha',
            'osVersion': '2',
            'application': 'com.example',
            'deviceSource': <int>[2, 3],
            'productionId': <int>[20, 30],
          },
        ]),
      );
      expect(watches.map((WatchModel w) => w.name), <String>['Alpha', 'Zebra']);
      expect(watches.first.variants.length, 2);
      expect(watches.first.variants.first.appName, 'com.example');
    });

    test('skips empty ids and mismatched source lists', () {
      final List<WatchModel> watches = DeviceCatalog.parseDeviceListJson(
        jsonEncode(<Map<String, Object>>[
          <String, Object>{
            'id': '',
            'deviceName': 'Bad',
            'deviceSource': <int>[1],
            'productionId': <int>[1],
          },
          <String, Object>{
            'id': 'ok',
            'deviceName': 'Ok',
            'deviceSource': <int>[1, 2],
            'productionId': <int>[1],
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
            (DeviceException e) => e.code,
            'code',
            'device-list-invalid',
          ),
        ),
      );
    });
  });

  group('DeviceCatalog.load', () {
    test('uses mock HTTP and caches until forceRefresh', () async {
      int hits = 0;
      final MockClient mock = MockClient((_) async {
        hits++;
        return http.Response(
          jsonEncode(<Map<String, Object>>[
            <String, Object>{
              'id': 'gtr4',
              'deviceName': 'GTR 4',
              'osVersion': '3',
              'deviceSource': <int>[229],
              'productionId': <int>[1],
            },
          ]),
          200,
        );
      });
      final DeviceCatalog catalog = DeviceCatalog(httpClient: mock);
      addTearDown(catalog.close);

      final List<WatchModel> first = await catalog.load();
      final List<WatchModel> second = await catalog.load();
      expect(first.single.name, 'GTR 4');
      expect(identical(first, second), isTrue);
      expect(hits, 1);

      await catalog.load(forceRefresh: true);
      expect(hits, 2);
    });
  });
}
