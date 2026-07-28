import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceUsageStore', () {
    test('persists touch and sorts pairing devices MRU-first', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DeviceUsageStore(prefs: prefs);

      await store.touchPairing(
        'AA:BB:CC:DD:EE:01',
        at: DateTime.utc(2026, 1, 1),
      );
      await store.touchPairing(
        'AA:BB:CC:DD:EE:02',
        at: DateTime.utc(2026, 1, 2),
      );

      final sorted = await store.sortPairingDevices(
        devices: [
          'AA:BB:CC:DD:EE:03',
          'AA:BB:CC:DD:EE:01',
          'AA:BB:CC:DD:EE:02',
        ],
        macOf: (m) => m,
      );
      expect(sorted.first, 'AA:BB:CC:DD:EE:02');
      expect(sorted[1], 'AA:BB:CC:DD:EE:01');
      expect(sorted.last, 'AA:BB:CC:DD:EE:03');
    });

    test('sortWatches uses watch keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DeviceUsageStore(prefs: prefs);
      await store.touchWatch('bip5', at: DateTime.utc(2026, 2, 1));

      final sorted = await store.sortWatches(
        watches: ['gtr4', 'bip5', 't-rex'],
        deviceIdOf: (id) => id,
      );
      expect(sorted.first, 'bip5');
      expect(sorted.sublist(1), ['gtr4', 't-rex']);
    });

    test('shared prefs: touch on one store is visible to another', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final firmware = DeviceUsageStore(prefs: prefs);
      final watchfaces = DeviceUsageStore(prefs: prefs);

      await firmware.touchWatch('gtr4', at: DateTime.utc(2026, 3, 1));
      await firmware.touchWatch('bip5', at: DateTime.utc(2026, 3, 2));

      // Fresh store instance (like another screen) must read the same MRU.
      final apps = DeviceUsageStore(prefs: prefs);
      final preferred = await apps.preferMostRecentWatch(
        watches: ['t-rex', 'gtr4', 'bip5'],
        deviceIdOf: (id) => id,
      );
      expect(preferred, 'bip5');

      final sorted = await watchfaces.sortWatches(
        watches: ['t-rex', 'gtr4', 'bip5'],
        deviceIdOf: (id) => id,
      );
      expect(sorted, ['bip5', 'gtr4', 't-rex']);
    });

    test('preferMostRecentWatch ignores ids not in the list', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DeviceUsageStore(prefs: prefs);
      await store.touchWatch('removed', at: DateTime.utc(2026, 4, 9));
      await store.touchWatch('gtr4', at: DateTime.utc(2026, 4, 1));

      final preferred = await store.preferMostRecentWatch(
        watches: ['gtr4', 'bip5'],
        deviceIdOf: (id) => id,
      );
      expect(preferred, 'gtr4');
    });

    test('preferMostRecentWatch is null when none used', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DeviceUsageStore(prefs: prefs);
      expect(
        await store.preferMostRecentWatch(
          watches: ['gtr4', 'bip5'],
          deviceIdOf: (id) => id,
        ),
        isNull,
      );
    });

    test('preferMostRecentPairing picks newest MAC among list', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DeviceUsageStore(prefs: prefs);
      await store.touchPairing(
        'AA:BB:CC:DD:EE:01',
        at: DateTime.utc(2026, 5, 1),
      );
      await store.touchPairing(
        'AA:BB:CC:DD:EE:02',
        at: DateTime.utc(2026, 5, 2),
      );

      expect(
        await store.preferMostRecentPairing(
          devices: ['AA:BB:CC:DD:EE:01', 'AA:BB:CC:DD:EE:03'],
          macOf: (m) => m,
        ),
        'AA:BB:CC:DD:EE:01',
      );
    });
  });
}
