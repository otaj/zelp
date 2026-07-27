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
  });
}
