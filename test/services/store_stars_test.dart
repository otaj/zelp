import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/models/store_item.dart';

import '../helpers/store_catalog_harness.dart';

void main() {
  final StoreCatalogDbHarness harness = StoreCatalogDbHarness();

  setUp(() async {
    await harness.setUp(prefix: 'store_star_');
  });

  tearDown(() async {
    await harness.tearDown();
  });

  test(
    'star persistence, auto-star on download, and update detection',
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
            name: 'Timer',
            downloadUrl: 'https://cdn.example.com/t.zpk',
            description: 'About',
          ),
        ],
      );

      final StoreItem? starred = await harness.db.starAfterDownload(
        const StoreItem(
          appId: 1,
          entryType: StoreEntryType.lightapp,
          deviceId: 'gtr4',
          deviceSource: 229,
          version: '1.0',
          name: 'Timer',
        ),
      );
      expect(starred!.isStarred, isTrue);
      expect(starred.starSeenVersion, '1.0');
      expect(starred.hasStarredUpdate, isFalse);

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
            version: '2.0',
            name: 'Timer',
            downloadUrl: 'https://cdn.example.com/t2.zpk',
            description: 'About v2',
          ),
        ],
      );
      final StoreItem? after = await harness.db.getLatestByAppId(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(after!.isStarred, isTrue);
      expect(after.version, '2.0');
      expect(after.starSeenVersion, '1.0');
      expect(after.hasStarredUpdate, isTrue);

      final List<StoreItem> onlyStarred = await harness.db.listItems(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        query: const StoreCatalogQuery(starredOnly: true),
      );
      expect(onlyStarred.single.appId, 1);

      await harness.db.markStarSeen(after);
      final StoreItem? seen = await harness.db.getLatestByAppId(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(seen!.hasStarredUpdate, isFalse);

      await harness.db.setStarred(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        starred: false,
      );
      final StoreItem? unstarred = await harness.db.getLatestByAppId(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(unstarred!.isStarred, isFalse);
    },
  );

  test('findEnrichedCache reuses detail across watch models', () async {
    await harness.db.replaceCatalog(
      entryType: StoreEntryType.lightapp,
      deviceId: 'gtr4',
      deviceSource: 229,
      items: const <StoreItem>[
        StoreItem(
          appId: 42,
          entryType: StoreEntryType.lightapp,
          deviceId: 'gtr4',
          deviceSource: 229,
          version: '1.0',
          name: 'Timer',
          downloadUrl: 'https://cdn.example.com/t.zpk',
          description: 'About timer',
          changelog: 'v1',
        ),
      ],
    );

    final StoreItem? enriched = await harness.db.findEnrichedCache(
      appId: 42,
      entryType: StoreEntryType.lightapp,
      version: '1.0',
    );
    expect(enriched, isNotNull);
    expect(enriched!.description, 'About timer');

    // Second model refresh can copy without a new detail fetch.
    await harness.db.replaceCatalog(
      entryType: StoreEntryType.lightapp,
      deviceId: 'balance',
      deviceSource: 8519936,
      items: <StoreItem>[
        mergeListIntoCached(
          const StoreItem(
            appId: 42,
            entryType: StoreEntryType.lightapp,
            deviceId: 'balance',
            deviceSource: 8519936,
            version: '1.0',
            name: 'Timer',
          ),
          enriched,
        ).copyWith(deviceId: 'balance', deviceSource: 8519936),
      ],
    );

    final List<String> models = await harness.db.listCompatibleDeviceIds(
      appId: 42,
      entryType: StoreEntryType.lightapp,
    );
    expect(models, containsAll(<dynamic>['gtr4', 'balance']));

    final StoreItem? onBalance = await harness.db.getLatestByAppId(
      appId: 42,
      entryType: StoreEntryType.lightapp,
      deviceId: 'balance',
    );
    expect(onBalance!.downloadUrl, 'https://cdn.example.com/t.zpk');
    expect(onBalance.description, 'About timer');
  });
}
