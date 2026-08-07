import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/domain/store/store_device_cache_meta.dart';
import 'package:zelp/models/store_item.dart';

import '../helpers/store_catalog_harness.dart';

void main() {
  final StoreCatalogDbHarness harness = StoreCatalogDbHarness();

  setUp(() async {
    await harness.setUp(prefix: 'store_db_');
  });

  tearDown(() async {
    await harness.tearDown();
  });

  test(
    'replaceCatalog, list, search, and refresh meta by watch model',
    () async {
      await harness.db.replaceCatalog(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        deviceSource: 229,
        items: <StoreItem>[
          const StoreItem(
            appId: 1,
            entryType: StoreEntryType.lightapp,
            deviceId: 'gtr4',
            deviceSource: 229,
            version: '1.0',
            name: 'Alpha Timer',
            categoryName: 'Tools',
            downloadSize: 10,
          ),
          const StoreItem(
            appId: 2,
            entryType: StoreEntryType.lightapp,
            deviceId: 'gtr4',
            deviceSource: 229,
            version: '2.0',
            name: 'Beta Weather',
            categoryName: 'Lifestyle',
            downloadSize: 20,
          ),
        ],
        refreshedAt: DateTime.utc(2026, 7),
      );
      await harness.db.upsertItem(
        const StoreItem(
          appId: 3,
          entryType: StoreEntryType.watch,
          deviceId: 'gtr4',
          deviceSource: 229,
          version: '1.0',
          name: 'Circle',
          downloadSize: 30,
        ),
      );

      final List<StoreItem> apps = await harness.db.listItems(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(apps.map((StoreItem e) => e.name), <String>['Alpha Timer', 'Beta Weather']);

      final List<StoreItem> found = await harness.db.listItems(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        query: const StoreCatalogQuery(text: 'weather'),
      );
      expect(found.single.name, 'Beta Weather');

      expect(
        await harness.db.lastRefreshedAt(
          entryType: StoreEntryType.lightapp,
          deviceId: 'gtr4',
        ),
        DateTime.utc(2026, 7),
      );

      await harness.db.replaceCatalog(
        entryType: StoreEntryType.lightapp,
        deviceId: 'balance',
        deviceSource: 241,
        items: <StoreItem>[
          const StoreItem(
            appId: 4,
            entryType: StoreEntryType.lightapp,
            deviceId: 'balance',
            deviceSource: 241,
            version: '1.0',
            name: 'Delta',
          ),
        ],
        refreshedAt: DateTime.utc(2026, 8),
      );

      final List<StoreDeviceCacheMeta> collected = await harness.db.listRefreshMeta(
        entryType: StoreEntryType.lightapp,
      );
      expect(
        collected.map((StoreDeviceCacheMeta m) => m.deviceId).toList(),
        <String>['balance', 'gtr4'],
      );
      expect(collected.first.itemCount, 1);
      expect(collected.first.refreshedAt, DateTime.utc(2026, 8));
      expect(collected.last.itemCount, 2);
      expect(collected.last.refreshedAt, DateTime.utc(2026, 7));

      await harness.db.replaceCatalog(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        deviceSource: 229,
        items: <StoreItem>[
          const StoreItem(
            appId: 9,
            entryType: StoreEntryType.lightapp,
            deviceId: 'gtr4',
            deviceSource: 229,
            version: '3.0',
            name: 'Only',
          ),
        ],
      );
      final List<StoreItem> after = await harness.db.listItems(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(after.map((StoreItem e) => e.name), <String>['Only']);
      expect(
        await harness.db.countItems(entryType: StoreEntryType.watch, deviceId: 'gtr4'),
        1,
      );
    },
  );
}
