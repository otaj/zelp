import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/services/device_usage_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceUsageStore', () {
    test('persists touch and sorts pairing devices MRU-first', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore store = DeviceUsageStore(prefs: prefs);

      await store.touchPairing(
        'AA:BB:CC:DD:EE:01',
        at: DateTime.utc(2026),
      );
      await store.touchPairing(
        'AA:BB:CC:DD:EE:02',
        at: DateTime.utc(2026, 1, 2),
      );

      final List<String> sorted = await store.sortPairingDevices(
        devices: <String>[
          'AA:BB:CC:DD:EE:03',
          'AA:BB:CC:DD:EE:01',
          'AA:BB:CC:DD:EE:02',
        ],
        macOf: (String m) => m,
      );
      expect(sorted.first, 'AA:BB:CC:DD:EE:02');
      expect(sorted[1], 'AA:BB:CC:DD:EE:01');
      expect(sorted.last, 'AA:BB:CC:DD:EE:03');
    });

    test('sortWatches uses watch keys', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore store = DeviceUsageStore(prefs: prefs);
      await store.touchWatch('bip5', at: DateTime.utc(2026, 2));

      final List<String> sorted = await store.sortWatches(
        watches: <String>['gtr4', 'bip5', 't-rex'],
        deviceIdOf: (String id) => id,
      );
      expect(sorted.first, 'bip5');
      expect(sorted.sublist(1), <String>['gtr4', 't-rex']);
    });

    test('shared prefs: touch on one store is visible to another', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore firmware = DeviceUsageStore(prefs: prefs);
      final DeviceUsageStore watchfaces = DeviceUsageStore(prefs: prefs);

      await firmware.touchWatch('gtr4', at: DateTime.utc(2026, 3));
      await firmware.touchWatch('bip5', at: DateTime.utc(2026, 3, 2));

      // Fresh store instance (like another screen) must read the same MRU.
      final DeviceUsageStore apps = DeviceUsageStore(prefs: prefs);
      final String? preferred = await apps.preferMostRecentWatch(
        watches: <String>['t-rex', 'gtr4', 'bip5'],
        deviceIdOf: (String id) => id,
      );
      expect(preferred, 'bip5');

      final List<String> sorted = await watchfaces.sortWatches(
        watches: <String>['t-rex', 'gtr4', 'bip5'],
        deviceIdOf: (String id) => id,
      );
      expect(sorted, <String>['bip5', 'gtr4', 't-rex']);
    });

    test('preferMostRecentWatch ignores ids not in the list', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore store = DeviceUsageStore(prefs: prefs);
      await store.touchWatch('removed', at: DateTime.utc(2026, 4, 9));
      await store.touchWatch('gtr4', at: DateTime.utc(2026, 4));

      final String? preferred = await store.preferMostRecentWatch(
        watches: <String>['gtr4', 'bip5'],
        deviceIdOf: (String id) => id,
      );
      expect(preferred, 'gtr4');
    });

    test('preferMostRecentWatch is null when none used', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore store = DeviceUsageStore(prefs: prefs);
      expect(
        await store.preferMostRecentWatch(
          watches: <String>['gtr4', 'bip5'],
          deviceIdOf: (String id) => id,
        ),
        isNull,
      );
    });

    test('preferMostRecentPairing picks newest MAC among list', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore store = DeviceUsageStore(prefs: prefs);
      await store.touchPairing(
        'AA:BB:CC:DD:EE:01',
        at: DateTime.utc(2026, 5),
      );
      await store.touchPairing(
        'AA:BB:CC:DD:EE:02',
        at: DateTime.utc(2026, 5, 2),
      );

      expect(
        await store.preferMostRecentPairing(
          devices: <String>['AA:BB:CC:DD:EE:01', 'AA:BB:CC:DD:EE:03'],
          macOf: (String m) => m,
        ),
        'AA:BB:CC:DD:EE:01',
      );
    });

    test('orderedWatchesWithPreferred returns ordered list and preferred', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore store = DeviceUsageStore(prefs: prefs);
      await store.touchWatch('gtr4', at: DateTime.utc(2026, 6));
      await store.touchWatch('bip5', at: DateTime.utc(2026, 6, 2));

      final ({List<String> ordered, String? preferred}) result = await store.orderedWatchesWithPreferred(
        watches: <String>['t-rex', 'gtr4', 'bip5'],
        deviceIdOf: (String id) => id,
      );
      expect(result.ordered, <String>['bip5', 'gtr4', 't-rex']);
      expect(result.preferred, 'bip5');
    });

    test('bringWatchToFront moves matching id to index 0', () {
      expect(
        DeviceUsageStore.bringWatchToFront(
          watches: <String>['a', 'b', 'c'],
          watch: 'c',
          deviceIdOf: (String id) => id,
        ),
        <String>['c', 'a', 'b'],
      );
    });

    test('sortSources and preferMostRecentSource use per-watch source keys', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore store = DeviceUsageStore(prefs: prefs);
      await store.touchSource('bip5', 851, at: DateTime.utc(2026, 7));
      await store.touchSource('bip5', 852, at: DateTime.utc(2026, 7, 2));
      // Same source id on another watch must not influence bip5 preference.
      await store.touchSource('gtr4', 852, at: DateTime.utc(2026, 7, 9));

      final List<int> sorted = await store.sortSources(
        deviceId: 'bip5',
        sources: <int>[851, 852, 853],
        deviceSourceOf: (int s) => s,
      );
      expect(sorted, <int>[852, 851, 853]);

      expect(
        await store.preferMostRecentSource(
          deviceId: 'bip5',
          sources: <int>[851, 853],
          deviceSourceOf: (int s) => s,
        ),
        851,
      );
    });

    test('orderedSourcesWithPreferred returns ordered list and preferred', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore store = DeviceUsageStore(prefs: prefs);
      await store.touchSource('bip5', 851, at: DateTime.utc(2026, 8));
      await store.touchSource('bip5', 852, at: DateTime.utc(2026, 8, 2));

      final ({List<int> ordered, int? preferred}) result = await store.orderedSourcesWithPreferred(
        deviceId: 'bip5',
        sources: <int>[853, 851, 852],
        deviceSourceOf: (int s) => s,
      );
      expect(result.ordered, <int>[852, 851, 853]);
      expect(result.preferred, 852);
    });

    test('preferMostRecentSource is null when none used', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore store = DeviceUsageStore(prefs: prefs);
      expect(
        await store.preferMostRecentSource(
          deviceId: 'bip5',
          sources: <int>[851, 852],
          deviceSourceOf: (int s) => s,
        ),
        isNull,
      );
    });

    test('bringSourceToFront moves matching source to index 0', () {
      expect(
        DeviceUsageStore.bringSourceToFront(
          sources: <int>[851, 852, 853],
          source: 853,
          deviceSourceOf: (int s) => s,
        ),
        <int>[853, 851, 852],
      );
    });
  });
}
