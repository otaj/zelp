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
    tempDir = await Directory.systemTemp.createTemp('store_db_');
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
    'replaceCatalog, list, search, and refresh meta by watch model',
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
            name: 'Alpha Timer',
            categoryName: 'Tools',
            downloadSize: 10,
            isFree: true,
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
            isFree: true,
          ),
        ],
        refreshedAt: DateTime.utc(2026, 7, 1),
      );
      await db.upsertItem(
        const StoreItem(
          appId: 3,
          entryType: StoreEntryType.watch,
          deviceId: 'gtr4',
          deviceSource: 229,
          version: '1.0',
          name: 'Circle',
          downloadSize: 30,
          isFree: true,
        ),
      );

      final apps = await db.listItems(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(apps.map((e) => e.name), ['Alpha Timer', 'Beta Weather']);

      final found = await db.listItems(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        query: const StoreCatalogQuery(text: 'weather'),
      );
      expect(found.single.name, 'Beta Weather');

      expect(
        await db.lastRefreshedAt(
          entryType: StoreEntryType.lightapp,
          deviceId: 'gtr4',
        ),
        DateTime.utc(2026, 7, 1),
      );

      await db.replaceCatalog(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
        deviceSource: 229,
        items: [
          const StoreItem(
            appId: 9,
            entryType: StoreEntryType.lightapp,
            deviceId: 'gtr4',
            deviceSource: 229,
            version: '3.0',
            name: 'Only',
            isFree: true,
          ),
        ],
      );
      final after = await db.listItems(
        entryType: StoreEntryType.lightapp,
        deviceId: 'gtr4',
      );
      expect(after.map((e) => e.name), ['Only']);
      expect(
        await db.countItems(entryType: StoreEntryType.watch, deviceId: 'gtr4'),
        1,
      );
    },
  );
}
