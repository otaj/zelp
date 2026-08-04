import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'store_catalog_database.g.dart';

/// JSON array of screenshot URLs in the `screenshot_urls` column.
class ScreenshotUrlsConverter extends TypeConverter<List<String>, String> {
  const ScreenshotUrlsConverter();

  @override
  List<String> fromSql(String fromDb) {
    final String text = fromDb.trim();
    if (text.isEmpty) return const <String>[];
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is! List) return const <String>[];
      return List<String>.unmodifiable(<String>[
        for (final Object? entry in decoded)
          if (entry != null && entry.toString().trim().isNotEmpty) entry.toString().trim(),
      ]);
    } on FormatException {
      return const <String>[];
    }
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Cached Apps / Watchfaces rows (one version per watch model).
@DataClassName('StoreItemRow')
class StoreItems extends Table {
  @override
  String get tableName => 'store_items';

  IntColumn get appId => integer()();
  TextColumn get entryType => text()();
  TextColumn get deviceId => text()();
  IntColumn get deviceSource => integer()();
  TextColumn get version => text()();
  TextColumn get name => text()();
  TextColumn get brief => text().withDefault(const Constant<String>(''))();
  TextColumn get description => text().withDefault(const Constant<String>(''))();
  TextColumn get changelog => text().withDefault(const Constant<String>(''))();
  TextColumn get iconUrl => text().withDefault(const Constant<String>(''))();
  TextColumn get screenshotUrls =>
      text().map(const ScreenshotUrlsConverter()).withDefault(const Constant<String>('[]'))();
  TextColumn get downloadUrl => text().withDefault(const Constant<String>(''))();
  IntColumn get downloadSize => integer().nullable()();
  TextColumn get publisherName => text().withDefault(const Constant<String>(''))();
  IntColumn get publisherId => integer().nullable()();
  TextColumn get categoryName => text().withDefault(const Constant<String>(''))();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get builtinId => integer().nullable()();
  BoolColumn get isFree => boolean().withDefault(const Constant<bool>(true))();
  BoolColumn get isRemoved => boolean().withDefault(const Constant<bool>(false))();
  BoolColumn get isStarred => boolean().withDefault(const Constant<bool>(false))();
  TextColumn get starSeenVersion => text().withDefault(const Constant<String>(''))();
  TextColumn get minZeppVersion => text().withDefault(const Constant<String>(''))();

  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get refreshedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    appId,
    entryType,
    deviceId,
    version,
  };
}

/// Last refresh metadata per watch model + entry type.
@DataClassName('StoreRefreshMetaRow')
class StoreRefreshMeta extends Table {
  @override
  String get tableName => 'store_refresh_meta';

  TextColumn get deviceId => text()();
  TextColumn get entryType => text()();
  IntColumn get deviceSource => integer()();
  DateTimeColumn get refreshedAt => dateTime().nullable()();
  IntColumn get itemCount => integer().withDefault(const Constant<int>(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{deviceId, entryType};
}

@DriftDatabase(tables: <Type>[StoreItems, StoreRefreshMeta])
class StoreCatalogDatabase extends _$StoreCatalogDatabase {
  /// Inject [executor] for tests (`NativeDatabase.memory()`).
  StoreCatalogDatabase([QueryExecutor? executor]) : super(executor ?? _openExecutor());

  /// Opens [dbName] under the app documents directory (same path as before).
  factory StoreCatalogDatabase.open({String? databasePath}) => StoreCatalogDatabase(
    driftDatabase(
      name: 'store_catalog',
      native: DriftNativeOptions(
        databasePath: () async {
          if (databasePath != null) return databasePath;
          return p.join(
            (await getApplicationDocumentsDirectory()).path,
            StoreCatalogDatabase.dbName,
          );
        },
      ),
    ),
  );

  static const String dbName = 'store_catalog.db';

  /// v5: typed DateTime columns for updated_at / refreshed_at.
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createBrowseIndex();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Cache is refreshable; wipe and recreate (same policy as sqflite layer).
      for (final TableInfo<Table, dynamic> table in allTables) {
        await m.deleteTable(table.actualTableName);
      }
      await customStatement('DROP TABLE IF EXISTS store_stars');
      await m.createAll();
      await _createBrowseIndex();
    },
  );

  Future<void> _createBrowseIndex() => customStatement(
    'CREATE INDEX IF NOT EXISTS idx_store_items_browse '
    'ON store_items (entry_type, device_id, is_removed, name)',
  );
}

QueryExecutor _openExecutor() => driftDatabase(
  name: 'store_catalog',
  native: DriftNativeOptions(
    databasePath: () async => p.join(
      (await getApplicationDocumentsDirectory()).path,
      StoreCatalogDatabase.dbName,
    ),
  ),
);
