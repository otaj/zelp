import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/services/store_catalog_db.dart';

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
          ({
            required String path,
            required int version,
            required Future<void> Function(Database, int) onCreate,
            Future<void> Function(Database, int, int)? onUpgrade,
          }) => databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: version,
              onCreate: onCreate,
              onUpgrade: onUpgrade,
            ),
          ),
      databasePath: p.join(tempDir.path, 'catalog.db'),
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test(
    'star persistence, auto-star on download, and update detection',
    () async {
      await db.replaceCatalog(
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

      final StoreItem? starred = await db.starAfterDownload(
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
      final StoreItem? after = await db.getLatestByAppId(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(after!.isStarred, isTrue);
      expect(after.version, '2.0');
      expect(after.starSeenVersion, '1.0');
      expect(after.hasStarredUpdate, isTrue);

      final List<StoreItem> onlyStarred = await db.listItems(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        query: const StoreCatalogQuery(starredOnly: true),
      );
      expect(onlyStarred.single.appId, 1);

      await db.markStarSeen(after);
      final StoreItem? seen = await db.getLatestByAppId(
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
      final StoreItem? unstarred = await db.getLatestByAppId(
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

    final StoreItem? enriched = await db.findEnrichedCache(
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

    final List<String> models = await db.listCompatibleDeviceIds(
      appId: 42,
      entryType: StoreEntryType.lightapp,
    );
    expect(models, containsAll(<dynamic>['gtr4', 'balance']));

    final StoreItem? onBalance = await db.getLatestByAppId(
      appId: 42,
      entryType: StoreEntryType.lightapp,
      deviceId: 'balance',
    );
    expect(onBalance!.downloadUrl, 'https://cdn.example.com/t.zpk');
    expect(onBalance.description, 'About timer');
  });
}
