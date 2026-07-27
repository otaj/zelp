import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/firmware_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirmwareStore', () {
    late FirmwareStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = FirmwareStore(prefs: await SharedPreferences.getInstance());
    });

    test('merge adds versions and get returns per source', () async {
      final watch = WatchModel(
        deviceId: 'gtr4',
        name: 'GTR 4',
        osVersion: '3',
        variants: [
          WatchVariant(
            deviceSource: 229,
            productionId: 1,
            appName: 'com.huami.midong',
          ),
        ],
      );
      final variant = watch.variants.first;

      final first = await store.merge(
        watch: watch,
        variant: variant,
        discovered: [
          FirmwareInfo(
            firmwareVersion: '1.0.0',
            firmwareUrl: 'https://example/fw1',
          ),
        ],
      );
      expect(first.versions.length, 1);

      final second = await store.merge(
        watch: watch,
        variant: variant,
        discovered: [
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

      final loaded = await store.get(deviceId: 'gtr4', deviceSource: 229);
      expect(loaded?.versions.length, 2);

      final other = await store.get(deviceId: 'gtr4', deviceSource: 999);
      expect(other, isNull);
    });

    test('clearVariant removes only that source', () async {
      final watch = WatchModel(
        deviceId: 'bip5',
        name: 'Bip 5',
        osVersion: '3',
        variants: [
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
        discovered: [FirmwareInfo(firmwareVersion: 'a')],
      );
      await store.merge(
        watch: watch,
        variant: watch.variants[1],
        discovered: [FirmwareInfo(firmwareVersion: 'b')],
      );

      await store.clearVariant(deviceId: 'bip5', deviceSource: 1);
      expect(await store.get(deviceId: 'bip5', deviceSource: 1), isNull);
      expect(
        (await store.get(deviceId: 'bip5', deviceSource: 2))?.latestVersion,
        'b',
      );
    });
  });
}
