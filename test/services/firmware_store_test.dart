import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/firmware_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirmwareStore', () {
    late FirmwareStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = FirmwareStore(prefs: await SharedPreferences.getInstance());
    });

    test('merge adds versions and get returns per source', () async {
      final WatchModel watch = WatchModel(
        deviceId: 'gtr4',
        name: 'GTR 4',
        osVersion: '3',
        variants: <WatchVariant>[
          WatchVariant(
            deviceSource: 229,
            productionId: 1,
            appName: 'com.huami.midong',
          ),
        ],
      );
      final WatchVariant variant = watch.variants.first;

      final StoredFirmwareHistory first = await store.merge(
        watch: watch,
        variant: variant,
        discovered: <FirmwareInfo>[
          FirmwareInfo(
            firmwareVersion: '1.0.0',
            firmwareUrl: 'https://example/fw1',
          ),
        ],
      );
      expect(first.versions.length, 1);

      final StoredFirmwareHistory second = await store.merge(
        watch: watch,
        variant: variant,
        discovered: <FirmwareInfo>[
          FirmwareInfo(
            firmwareVersion: '1.0.0',
            firmwareUrl: 'https://example/fw1-updated',
          ),
          FirmwareInfo(firmwareVersion: '1.1.0'),
        ],
      );
      expect(second.versions.length, 2);
      expect(second.versions.first.firmwareUrl, 'https://example/fw1-updated');
      expect(second.latestVersion, '1.1.0');

      final StoredFirmwareHistory? loaded = await store.get(deviceId: 'gtr4', deviceSource: 229);
      expect(loaded?.versions.length, 2);

      final StoredFirmwareHistory? other = await store.get(deviceId: 'gtr4', deviceSource: 999);
      expect(other, isNull);
    });

    test('clearVariant removes only that source', () async {
      final WatchModel watch = WatchModel(
        deviceId: 'bip5',
        name: 'Bip 5',
        osVersion: '3',
        variants: <WatchVariant>[
          WatchVariant(
            deviceSource: 1,
            productionId: 1,
            appName: 'com.huami.midong',
          ),
          WatchVariant(
            deviceSource: 2,
            productionId: 2,
            appName: 'com.huami.midong',
          ),
        ],
      );
      await store.merge(
        watch: watch,
        variant: watch.variants[0],
        discovered: <FirmwareInfo>[FirmwareInfo(firmwareVersion: 'a')],
      );
      await store.merge(
        watch: watch,
        variant: watch.variants[1],
        discovered: <FirmwareInfo>[FirmwareInfo(firmwareVersion: 'b')],
      );

      await store.clearVariant(deviceId: 'bip5', deviceSource: 1);
      expect(await store.get(deviceId: 'bip5', deviceSource: 1), isNull);
      expect(
        (await store.get(deviceId: 'bip5', deviceSource: 2))?.latestVersion,
        'b',
      );
    });

    test('baseline is stored per source and survives clearVariant', () async {
      await store.setBaseline(deviceId: 'gtr4', deviceSource: 229, version: '3.12.4.1');
      await store.setBaseline(deviceId: 'gtr4', deviceSource: 230, version: ' 1.0.0 ');
      expect(await store.baseline(deviceId: 'gtr4', deviceSource: 229), '3.12.4.1');
      expect(await store.baseline(deviceId: 'gtr4', deviceSource: 230), '1.0.0');

      await store.setBaseline(deviceId: 'gtr4', deviceSource: 229, version: '   ');
      expect(await store.baseline(deviceId: 'gtr4', deviceSource: 229), isNull);
      expect(await store.baseline(deviceId: 'gtr4', deviceSource: 230), '1.0.0');

      final WatchModel watch = WatchModel(
        deviceId: 'gtr4',
        name: 'GTR 4',
        osVersion: '3',
        variants: <WatchVariant>[
          WatchVariant(
            deviceSource: 230,
            productionId: 1,
            appName: 'com.huami.midong',
          ),
        ],
      );
      await store.merge(
        watch: watch,
        variant: watch.variants.first,
        discovered: <FirmwareInfo>[FirmwareInfo(firmwareVersion: '9.9.9')],
      );
      await store.clearVariant(deviceId: 'gtr4', deviceSource: 230);
      expect(await store.get(deviceId: 'gtr4', deviceSource: 230), isNull);
      expect(await store.baseline(deviceId: 'gtr4', deviceSource: 230), '1.0.0');

      final FirmwareStore reloaded = FirmwareStore(prefs: await SharedPreferences.getInstance());
      expect(await reloaded.baseline(deviceId: 'gtr4', deviceSource: 230), '1.0.0');
      expect(await reloaded.baseline(deviceId: 'gtr4', deviceSource: 229), isNull);
    });
  });
}
