import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/services/store_catalog_db.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late StoreCatalogDb db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('store_star_');
    db = StoreCatalogDb(
      opener:
          ({required path, required version, required onCreate, onUpgrade}) {
            return databaseFactoryFfi.openDatabase(
              path,
              options: OpenDatabaseOptions(
                version: version,
                onCreate: onCreate,
                onUpgrade: onUpgrade,
              ),
            );
          },
      databasePath: p.join(tempDir.path, 'catalog.db'),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'star persistence, auto-star on download, and update detection',
    () async {
      await db.replaceCatalog(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        deviceSource: 229,
        items: [
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

      final starred = await db.starAfterDownload(
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

      await db.replaceCatalog(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        deviceSource: 229,
        items: [
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
      final after = await db.getLatestByAppId(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(after!.isStarred, isTrue);
      expect(after.version, '2.0');
      expect(after.starSeenVersion, '1.0');
      expect(after.hasStarredUpdate, isTrue);

      final onlyStarred = await db.listItems(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        query: const StoreCatalogQuery(starredOnly: true),
      );
      expect(onlyStarred.single.appId, 1);

      await db.markStarSeen(after);
      final seen = await db.getLatestByAppId(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(seen!.hasStarredUpdate, isFalse);

      await db.setStarred(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        starred: false,
      );
      final unstarred = await db.getLatestByAppId(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(unstarred!.isStarred, isFalse);
    },
  );

  test('findEnrichedCache reuses detail across watch models', () async {
    await db.replaceCatalog(
      entryType: StoreEntryType.lightapp,
      deviceId: 'gtr4',
      deviceSource: 229,
      items: const [
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

    final enriched = await db.findEnrichedCache(
      appId: 42,
      entryType: StoreEntryType.lightapp,
      version: '1.0',
    );
    expect(enriched, isNotNull);
    expect(enriched!.description, 'About timer');

    // Second model refresh can copy without a new detail fetch.
    await db.replaceCatalog(
      entryType: StoreEntryType.lightapp,
      deviceId: 'balance',
      deviceSource: 8519936,
      items: [
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

    final models = await db.listCompatibleDeviceIds(
      appId: 42,
      entryType: StoreEntryType.lightapp,
    );
    expect(models, containsAll(['gtr4', 'balance']));

    final onBalance = await db.getLatestByAppId(
      appId: 42,
      entryType: StoreEntryType.lightapp,
      deviceId: 'balance',
    );
    expect(onBalance!.downloadUrl, 'https://cdn.example.com/t.zpk');
    expect(onBalance.description, 'About timer');
  });
}
