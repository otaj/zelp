import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/store/store_catalog_query.dart';
import '../models/store_item.dart';

typedef OpenStoreDatabase =
    Future<Database> Function({
      required String path,
      required int version,
      required Future<void> Function(Database db, int version) onCreate,
      Future<void> Function(Database db, int oldVersion, int newVersion)?
      onUpgrade,
    });

/// Local cache for Apps / Watchfaces metadata.
///
/// Browse reads only from this store. Network refresh is explicit via
/// [StoreCatalogService]. Rows are keyed by watch **model** ([deviceId]).
/// Stars are stored on item rows and preserved across [replaceCatalog].
class StoreCatalogDb {
  StoreCatalogDb({
    Database? database,
    OpenStoreDatabase? opener,
    String? databasePath,
  }) : _database = database,
       _opener = opener ?? _defaultOpen,
       _databasePath = databasePath;

  static const dbName = 'store_catalog.db';

  /// v3: model-centric keys + starring columns.
  static const schemaVersion = 3;
  static const itemsTable = 'store_items';
  static const metaTable = 'store_refresh_meta';

  final OpenStoreDatabase _opener;
  final String? _databasePath;
  Database? _database;

  static Future<Database> _defaultOpen({
    required String path,
    required int version,
    required Future<void> Function(Database db, int version) onCreate,
    Future<void> Function(Database db, int oldVersion, int newVersion)?
    onUpgrade,
  }) {
    return openDatabase(
      path,
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE $itemsTable (
  app_id INTEGER NOT NULL,
  entry_type TEXT NOT NULL,
  device_id TEXT NOT NULL,
  device_source INTEGER NOT NULL,
  version TEXT NOT NULL,
  name TEXT NOT NULL,
  brief TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  changelog TEXT NOT NULL DEFAULT '',
  icon_url TEXT NOT NULL DEFAULT '',
  download_url TEXT NOT NULL DEFAULT '',
  download_size INTEGER,
  publisher_name TEXT NOT NULL DEFAULT '',
  publisher_id INTEGER,
  category_name TEXT NOT NULL DEFAULT '',
  category_id INTEGER,
  builtin_id INTEGER,
  is_free INTEGER NOT NULL DEFAULT 1,
  is_removed INTEGER NOT NULL DEFAULT 0,
  is_starred INTEGER NOT NULL DEFAULT 0,
  star_seen_version TEXT NOT NULL DEFAULT '',
  min_zepp_version TEXT NOT NULL DEFAULT '',
  updated_at TEXT,
  refreshed_at TEXT,
  PRIMARY KEY (app_id, entry_type, device_id, version)
)
''');
    await db.execute('''
CREATE INDEX idx_store_items_browse
ON $itemsTable (entry_type, device_id, is_removed, name)
''');
    await db.execute('''
CREATE TABLE $metaTable (
  device_id TEXT NOT NULL,
  entry_type TEXT NOT NULL,
  device_source INTEGER NOT NULL,
  refreshed_at TEXT,
  item_count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (device_id, entry_type)
)
''');
  }

  Future<Database> _ensureDb() async {
    if (_database != null) return _database!;
    final path =
        _databasePath ??
        p.join((await getApplicationDocumentsDirectory()).path, dbName);
    _database = await _opener(
      path: path,
      version: schemaVersion,
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS $itemsTable');
        await db.execute('DROP TABLE IF EXISTS $metaTable');
        await db.execute('DROP TABLE IF EXISTS store_stars');
        await _createSchema(db);
      },
    );
    return _database!;
  }

  Future<List<StoreItem>> listItems({
    required StoreEntryType entryType,
    required String deviceId,
    StoreCatalogQuery query = const StoreCatalogQuery(),
    bool includeRemoved = false,
  }) async {
    final db = await _ensureDb();
    final where = StringBuffer('entry_type = ? AND device_id = ?');
    final args = <Object?>[entryType.apiValue, deviceId];
    if (!includeRemoved) {
      where.write(' AND is_removed = 0');
    }
    if (query.starredOnly) {
      where.write(' AND is_starred = 1');
    }
    final trimmed = query.text.trim();
    if (trimmed.isNotEmpty) {
      where.write(
        ' AND (name LIKE ? OR brief LIKE ? OR publisher_name LIKE ? '
        'OR category_name LIKE ? OR description LIKE ?)',
      );
      final like = '%$trimmed%';
      args.addAll([like, like, like, like, like]);
    }
    final category = query.categoryName?.trim();
    if (category != null && category.isNotEmpty) {
      where.write(' AND category_name = ?');
      args.add(category);
    }
    final publisher = query.publisherName?.trim();
    if (publisher != null && publisher.isNotEmpty) {
      where.write(' AND publisher_name = ?');
      args.add(publisher);
    }
    switch (query.price) {
      case StorePriceFilter.free:
        where.write(' AND is_free = 1');
      case StorePriceFilter.paid:
        where.write(' AND is_free = 0');
      case StorePriceFilter.all:
        break;
    }
    final rows = await db.query(
      itemsTable,
      where: where.toString(),
      whereArgs: args,
      orderBy: query.orderBySql,
    );
    return rows.map(StoreItem.fromRow).toList();
  }

  Future<StoreItem?> getLatestByAppId({
    required int appId,
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final db = await _ensureDb();
    final rows = await db.query(
      itemsTable,
      where:
          'app_id = ? AND entry_type = ? AND device_id = ? AND is_removed = 0',
      whereArgs: [appId, entryType.apiValue, deviceId],
      orderBy: 'refreshed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StoreItem.fromRow(rows.first);
  }

  Future<Map<int, StoreItem>> mapActiveByAppId({
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final items = await listItems(entryType: entryType, deviceId: deviceId);
    return {for (final item in items) item.appId: item};
  }

  Future<List<String>> distinctCategories({
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final db = await _ensureDb();
    final rows = await db.rawQuery(
      'SELECT DISTINCT category_name AS v FROM $itemsTable '
      'WHERE entry_type = ? AND device_id = ? AND is_removed = 0 '
      'AND category_name != "" ORDER BY category_name COLLATE NOCASE ASC',
      [entryType.apiValue, deviceId],
    );
    return rows
        .map((r) => r['v']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<List<String>> distinctPublishers({
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final db = await _ensureDb();
    final rows = await db.rawQuery(
      'SELECT DISTINCT publisher_name AS v FROM $itemsTable '
      'WHERE entry_type = ? AND device_id = ? AND is_removed = 0 '
      'AND publisher_name != "" ORDER BY publisher_name COLLATE NOCASE ASC',
      [entryType.apiValue, deviceId],
    );
    return rows
        .map((r) => r['v']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<StoreItem?> getItem({
    required int appId,
    required StoreEntryType entryType,
    required String deviceId,
    required String version,
  }) async {
    final db = await _ensureDb();
    final rows = await db.query(
      itemsTable,
      where: 'app_id = ? AND entry_type = ? AND device_id = ? AND version = ?',
      whereArgs: [appId, entryType.apiValue, deviceId, version],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StoreItem.fromRow(rows.first);
  }

  /// Any enriched cache row for this app+version (any watch model).
  ///
  /// Used so switching models does not re-fetch detail when another model's
  /// cache already has download URL + description.
  Future<StoreItem?> findEnrichedCache({
    required int appId,
    required StoreEntryType entryType,
    required String version,
  }) async {
    final db = await _ensureDb();
    final rows = await db.query(
      itemsTable,
      where:
          'app_id = ? AND entry_type = ? AND version = ? AND is_removed = 0 '
          "AND download_url != '' AND description != ''",
      whereArgs: [appId, entryType.apiValue, version],
      orderBy: 'refreshed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      // Fall back: download URL alone is enough to skip most detail work.
      final loose = await db.query(
        itemsTable,
        where:
            'app_id = ? AND entry_type = ? AND version = ? AND is_removed = 0 '
            "AND download_url != ''",
        whereArgs: [appId, entryType.apiValue, version],
        orderBy: 'refreshed_at DESC',
        limit: 1,
      );
      if (loose.isEmpty) return null;
      return StoreItem.fromRow(loose.first);
    }
    return StoreItem.fromRow(rows.first);
  }

  /// Watch model ids in the local cache that list this app (any version).
  Future<List<String>> listCompatibleDeviceIds({
    required int appId,
    required StoreEntryType entryType,
  }) async {
    final db = await _ensureDb();
    final rows = await db.rawQuery(
      'SELECT DISTINCT device_id AS v FROM $itemsTable '
      'WHERE app_id = ? AND entry_type = ? AND is_removed = 0 '
      "AND device_id != '' ORDER BY device_id COLLATE NOCASE ASC",
      [appId, entryType.apiValue],
    );
    return rows
        .map((r) => r['v']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Stars or unstars every cached version of an app for this watch model.
  Future<StoreItem?> setStarred({
    required int appId,
    required StoreEntryType entryType,
    required String deviceId,
    required bool starred,
    String? seenVersion,
  }) async {
    final db = await _ensureDb();
    final latest = await getLatestByAppId(
      appId: appId,
      entryType: entryType,
      deviceId: deviceId,
    );
    final seen = seenVersion ?? (starred ? (latest?.version ?? '') : '');
    await db.update(
      itemsTable,
      {'is_starred': starred ? 1 : 0, 'star_seen_version': starred ? seen : ''},
      where: 'app_id = ? AND entry_type = ? AND device_id = ?',
      whereArgs: [appId, entryType.apiValue, deviceId],
    );
    return getLatestByAppId(
      appId: appId,
      entryType: entryType,
      deviceId: deviceId,
    );
  }

  /// Auto-star after download; marks current version as seen (no “Updated” badge).
  Future<StoreItem?> starAfterDownload(StoreItem item) {
    return setStarred(
      appId: item.appId,
      entryType: item.entryType,
      deviceId: item.deviceId,
      starred: true,
      seenVersion: item.version,
    );
  }

  /// Clears the “Updated” badge by recording the current version as seen.
  Future<StoreItem?> markStarSeen(StoreItem item) {
    if (!item.isStarred) return Future.value(item);
    return setStarred(
      appId: item.appId,
      entryType: item.entryType,
      deviceId: item.deviceId,
      starred: true,
      seenVersion: item.version,
    );
  }

  /// Upserts [items] for a watch model and marks prior active rows not in the
  /// batch as removed. Preserves star flags from the previous cache.
  Future<void> replaceCatalog({
    required StoreEntryType entryType,
    required String deviceId,
    required int deviceSource,
    required List<StoreItem> items,
    DateTime? refreshedAt,
  }) async {
    final db = await _ensureDb();
    final now = refreshedAt ?? DateTime.now().toUtc();
    final previous = await mapActiveByAppId(
      entryType: entryType,
      deviceId: deviceId,
    );
    await db.transaction((txn) async {
      final seen = <String>{};
      for (final item in items) {
        final prev = previous[item.appId];
        final stamped = item.copyWith(
          deviceId: deviceId,
          deviceSource: deviceSource,
          refreshedAt: now,
          isRemoved: false,
          isStarred: prev?.isStarred ?? item.isStarred,
          starSeenVersion: prev?.starSeenVersion ?? item.starSeenVersion,
        );
        seen.add('${stamped.appId}|${stamped.version}');
        await txn.insert(
          itemsTable,
          stamped.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final existing = await txn.query(
        itemsTable,
        columns: ['app_id', 'version'],
        where: 'entry_type = ? AND device_id = ? AND is_removed = 0',
        whereArgs: [entryType.apiValue, deviceId],
      );
      for (final row in existing) {
        final key = '${row['app_id']}|${row['version']}';
        if (seen.contains(key)) continue;
        await txn.update(
          itemsTable,
          {'is_removed': 1, 'refreshed_at': now.toIso8601String()},
          where:
              'app_id = ? AND entry_type = ? AND device_id = ? AND version = ?',
          whereArgs: [
            row['app_id'],
            entryType.apiValue,
            deviceId,
            row['version'],
          ],
        );
      }
      await txn.insert(metaTable, {
        'device_id': deviceId,
        'entry_type': entryType.apiValue,
        'device_source': deviceSource,
        'refreshed_at': now.toIso8601String(),
        'item_count': items.length,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> upsertItem(StoreItem item) async {
    final db = await _ensureDb();
    await db.insert(
      itemsTable,
      item.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> lastRefreshedAt({
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final db = await _ensureDb();
    final rows = await db.query(
      metaTable,
      columns: ['refreshed_at'],
      where: 'entry_type = ? AND device_id = ?',
      whereArgs: [entryType.apiValue, deviceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['refreshed_at'] as String? ?? '');
  }

  Future<int> countItems({
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final db = await _ensureDb();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $itemsTable '
      'WHERE entry_type = ? AND device_id = ? AND is_removed = 0',
      [entryType.apiValue, deviceId],
    );
    final value = result.first['c'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
