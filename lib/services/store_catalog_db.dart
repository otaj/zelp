import 'package:drift/drift.dart';

import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/services/store_catalog/store_catalog_database.dart';
import 'package:zelp/services/store_catalog_service.dart' show StoreCatalogService;

/// Ordering helpers for [StoreCatalogDb.listItems] — lives with the DB, not domain.
extension StoreCatalogQueryOrdering on StoreCatalogQuery {
  /// Starred updates float first, then other starred, then the primary sort.
  List<OrderingTerm> orderingTerms(StoreItems t) {
    final OrderingMode mode = sortDirection == StoreSortDirection.ascending ? OrderingMode.asc : OrderingMode.desc;
    const Expression<int> starredRank = CustomExpression<int>(
      "CASE WHEN is_starred = 1 AND star_seen_version != '' "
      'AND star_seen_version != version THEN 0 '
      'WHEN is_starred = 1 THEN 1 ELSE 2 END',
    );
    final List<OrderingTerm> primary = switch (sortBy) {
      StoreSortBy.name => <OrderingTerm>[
        OrderingTerm(expression: t.name.collate(Collate.noCase), mode: mode),
      ],
      StoreSortBy.updatedAt => <OrderingTerm>[
        OrderingTerm(expression: const CustomExpression<int>('updated_at IS NULL')),
        OrderingTerm(expression: t.updatedAt, mode: mode),
        OrderingTerm(expression: t.name.collate(Collate.noCase)),
      ],
      StoreSortBy.size => <OrderingTerm>[
        OrderingTerm(expression: const CustomExpression<int>('download_size IS NULL')),
        OrderingTerm(expression: t.downloadSize, mode: mode),
        OrderingTerm(expression: t.name.collate(Collate.noCase)),
      ],
      StoreSortBy.publisher => <OrderingTerm>[
        OrderingTerm(
          expression: t.publisherName.collate(Collate.noCase),
          mode: mode,
        ),
        OrderingTerm(expression: t.name.collate(Collate.noCase)),
      ],
      StoreSortBy.category => <OrderingTerm>[
        OrderingTerm(
          expression: t.categoryName.collate(Collate.noCase),
          mode: mode,
        ),
        OrderingTerm(expression: t.name.collate(Collate.noCase)),
      ],
    };
    return <OrderingTerm>[
      OrderingTerm(expression: starredRank),
      ...primary,
    ];
  }
}

/// Local cache for Apps / Watchfaces metadata.
///
/// Browse reads only from this store. Network refresh is explicit via
/// [StoreCatalogService]. Rows are keyed by watch **model** (`deviceId`).
/// Stars are stored on item rows and preserved across [replaceCatalog].
class StoreCatalogDb {
  StoreCatalogDb({
    StoreCatalogDatabase? database,
    String? databasePath,
  }) : _owned = database == null,
       _db = database ?? StoreCatalogDatabase.open(databasePath: databasePath);

  static const String dbName = StoreCatalogDatabase.dbName;

  /// v5: typed DateTime columns for updated_at / refreshed_at.
  static const int schemaVersion = 5;

  final StoreCatalogDatabase _db;
  final bool _owned;
  bool _closed = false;

  StoreCatalogDatabase get database => _db;

  Future<List<StoreItem>> listItems({
    required StoreEntryType entryType,
    required String deviceId,
    StoreCatalogQuery query = const StoreCatalogQuery(),
    bool includeRemoved = false,
  }) async {
    final SimpleSelectStatement<$StoreItemsTable, StoreItemRow> select = _db.select(_db.storeItems)
      ..where(($StoreItemsTable t) {
        Expression<bool> expr = t.entryType.equals(entryType.apiValue) & t.deviceId.equals(deviceId);
        if (!includeRemoved) {
          expr = expr & t.isRemoved.equals(false);
        }
        if (query.starredOnly) {
          expr = expr & t.isStarred.equals(true);
        }
        final String trimmed = query.text.trim();
        if (trimmed.isNotEmpty) {
          final String like = '%$trimmed%';
          expr =
              expr &
              (t.name.like(like) |
                  t.brief.like(like) |
                  t.publisherName.like(like) |
                  t.categoryName.like(like) |
                  t.description.like(like));
        }
        final String? category = query.categoryName?.trim();
        if (category != null && category.isNotEmpty) {
          expr = expr & t.categoryName.equals(category);
        }
        final String? publisher = query.publisherName?.trim();
        if (publisher != null && publisher.isNotEmpty) {
          expr = expr & t.publisherName.equals(publisher);
        }
        switch (query.price) {
          case StorePriceFilter.free:
            expr = expr & t.isFree.equals(true);
          case StorePriceFilter.paid:
            expr = expr & t.isFree.equals(false);
          case StorePriceFilter.all:
            break;
        }
        return expr;
      })
      ..orderBy(<OrderClauseGenerator<$StoreItemsTable>>[
        for (final OrderingTerm term in query.orderingTerms(_db.storeItems)) ($StoreItemsTable _) => term,
      ]);
    final List<StoreItemRow> rows = await select.get();
    return rows.map(itemFromData).toList();
  }

  Future<StoreItem?> getLatestByAppId({
    required int appId,
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final StoreItemRow? row =
        await (_db.select(_db.storeItems)
              ..where(
                ($StoreItemsTable t) =>
                    t.appId.equals(appId) &
                    t.entryType.equals(entryType.apiValue) &
                    t.deviceId.equals(deviceId) &
                    t.isRemoved.equals(false),
              )
              ..orderBy(<OrderClauseGenerator<$StoreItemsTable>>[
                ($StoreItemsTable t) => OrderingTerm.desc(t.refreshedAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : itemFromData(row);
  }

  Future<Map<int, StoreItem>> mapActiveByAppId({
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final List<StoreItem> items = await listItems(entryType: entryType, deviceId: deviceId);
    return <int, StoreItem>{for (final StoreItem item in items) item.appId: item};
  }

  Future<List<String>> distinctCategories({
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final Expression<String> value = _db.storeItems.categoryName;
    final JoinedSelectStatement<HasResultSet, dynamic> query = _db.selectOnly(_db.storeItems, distinct: true)
      ..addColumns(<Expression<Object>>[value])
      ..where(
        _db.storeItems.entryType.equals(entryType.apiValue) &
            _db.storeItems.deviceId.equals(deviceId) &
            _db.storeItems.isRemoved.equals(false) &
            _db.storeItems.categoryName.equals('').not(),
      )
      ..orderBy(<OrderingTerm>[
        OrderingTerm(expression: value.collate(Collate.noCase)),
      ]);
    final List<TypedResult> rows = await query.get();
    return rows.map((TypedResult r) => r.read(value) ?? '').where((String s) => s.isNotEmpty).toList();
  }

  Future<List<String>> distinctPublishers({
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final Expression<String> value = _db.storeItems.publisherName;
    final JoinedSelectStatement<HasResultSet, dynamic> query = _db.selectOnly(_db.storeItems, distinct: true)
      ..addColumns(<Expression<Object>>[value])
      ..where(
        _db.storeItems.entryType.equals(entryType.apiValue) &
            _db.storeItems.deviceId.equals(deviceId) &
            _db.storeItems.isRemoved.equals(false) &
            _db.storeItems.publisherName.equals('').not(),
      )
      ..orderBy(<OrderingTerm>[
        OrderingTerm(expression: value.collate(Collate.noCase)),
      ]);
    final List<TypedResult> rows = await query.get();
    return rows.map((TypedResult r) => r.read(value) ?? '').where((String s) => s.isNotEmpty).toList();
  }

  Future<StoreItem?> getItem({
    required int appId,
    required StoreEntryType entryType,
    required String deviceId,
    required String version,
  }) async {
    final StoreItemRow? row =
        await (_db.select(_db.storeItems)
              ..where(
                ($StoreItemsTable t) =>
                    t.appId.equals(appId) &
                    t.entryType.equals(entryType.apiValue) &
                    t.deviceId.equals(deviceId) &
                    t.version.equals(version),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : itemFromData(row);
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
    Future<StoreItem?> lookup({required bool requireDescription}) async {
      final StoreItemRow? row =
          await (_db.select(_db.storeItems)
                ..where(($StoreItemsTable t) {
                  Expression<bool> expr =
                      t.appId.equals(appId) &
                      t.entryType.equals(entryType.apiValue) &
                      t.version.equals(version) &
                      t.isRemoved.equals(false) &
                      t.downloadUrl.equals('').not();
                  if (requireDescription) {
                    expr = expr & t.description.equals('').not();
                  }
                  return expr;
                })
                ..orderBy(<OrderClauseGenerator<$StoreItemsTable>>[
                  ($StoreItemsTable t) => OrderingTerm.desc(t.refreshedAt),
                ])
                ..limit(1))
              .getSingleOrNull();
      return row == null ? null : itemFromData(row);
    }

    return await lookup(requireDescription: true) ?? lookup(requireDescription: false);
  }

  /// Watch model ids in the local cache that list this app (any version).
  Future<List<String>> listCompatibleDeviceIds({
    required int appId,
    required StoreEntryType entryType,
  }) async {
    final Expression<String> value = _db.storeItems.deviceId;
    final JoinedSelectStatement<HasResultSet, dynamic> query = _db.selectOnly(_db.storeItems, distinct: true)
      ..addColumns(<Expression<Object>>[value])
      ..where(
        _db.storeItems.appId.equals(appId) &
            _db.storeItems.entryType.equals(entryType.apiValue) &
            _db.storeItems.isRemoved.equals(false) &
            _db.storeItems.deviceId.equals('').not(),
      )
      ..orderBy(<OrderingTerm>[
        OrderingTerm(expression: value.collate(Collate.noCase)),
      ]);
    final List<TypedResult> rows = await query.get();
    return rows.map((TypedResult r) => r.read(value) ?? '').where((String s) => s.isNotEmpty).toList();
  }

  /// Stars or unstars every cached version of an app for this watch model.
  Future<StoreItem?> setStarred({
    required int appId,
    required StoreEntryType entryType,
    required String deviceId,
    required bool starred,
    String? seenVersion,
  }) async {
    final StoreItem? latest = await getLatestByAppId(
      appId: appId,
      entryType: entryType,
      deviceId: deviceId,
    );
    final String seen = seenVersion ?? (starred ? (latest?.version ?? '') : '');
    await (_db.update(_db.storeItems)..where(
          ($StoreItemsTable t) =>
              t.appId.equals(appId) & t.entryType.equals(entryType.apiValue) & t.deviceId.equals(deviceId),
        ))
        .write(
          StoreItemsCompanion(
            isStarred: Value<bool>(starred),
            starSeenVersion: Value<String>(starred ? seen : ''),
          ),
        );
    return getLatestByAppId(
      appId: appId,
      entryType: entryType,
      deviceId: deviceId,
    );
  }

  /// Auto-star after download; marks current version as seen (no “Updated” badge).
  Future<StoreItem?> starAfterDownload(StoreItem item) => setStarred(
    appId: item.appId,
    entryType: item.entryType,
    deviceId: item.deviceId,
    starred: true,
    seenVersion: item.version,
  );

  /// Clears the “Updated” badge by recording the current version as seen.
  Future<StoreItem?> markStarSeen(StoreItem item) {
    if (!item.isStarred) return Future<StoreItem?>.value(item);
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
    final DateTime now = refreshedAt ?? DateTime.now().toUtc();
    final Map<int, StoreItem> previous = await mapActiveByAppId(
      entryType: entryType,
      deviceId: deviceId,
    );
    await _db.transaction(() async {
      final Set<String> seen = <String>{};
      for (final StoreItem item in items) {
        final StoreItem? prev = previous[item.appId];
        final StoreItem stamped = item.copyWith(
          deviceId: deviceId,
          deviceSource: deviceSource,
          refreshedAt: now,
          isRemoved: false,
          isStarred: prev?.isStarred ?? item.isStarred,
          starSeenVersion: prev?.starSeenVersion ?? item.starSeenVersion,
        );
        seen.add('${stamped.appId}|${stamped.version}');
        await _db.into(_db.storeItems).insertOnConflictUpdate(itemToCompanion(stamped));
      }
      final List<StoreItemRow> existing =
          await (_db.select(_db.storeItems)..where(
                ($StoreItemsTable t) =>
                    t.entryType.equals(entryType.apiValue) & t.deviceId.equals(deviceId) & t.isRemoved.equals(false),
              ))
              .get();
      for (final StoreItemRow row in existing) {
        final String key = '${row.appId}|${row.version}';
        if (seen.contains(key)) continue;
        await (_db.update(_db.storeItems)..where(
              ($StoreItemsTable t) =>
                  t.appId.equals(row.appId) &
                  t.entryType.equals(entryType.apiValue) &
                  t.deviceId.equals(deviceId) &
                  t.version.equals(row.version),
            ))
            .write(
              StoreItemsCompanion(
                isRemoved: const Value<bool>(true),
                refreshedAt: Value<DateTime?>(now.toUtc()),
              ),
            );
      }
      await _db
          .into(_db.storeRefreshMeta)
          .insertOnConflictUpdate(
            StoreRefreshMetaCompanion.insert(
              deviceId: deviceId,
              entryType: entryType.apiValue,
              deviceSource: deviceSource,
              refreshedAt: Value<DateTime?>(now.toUtc()),
              itemCount: Value<int>(items.length),
            ),
          );
    });
  }

  Future<void> upsertItem(StoreItem item) async {
    await _db.into(_db.storeItems).insertOnConflictUpdate(itemToCompanion(item));
  }

  Future<DateTime?> lastRefreshedAt({
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final StoreRefreshMetaRow? row =
        await (_db.select(_db.storeRefreshMeta)
              ..where(
                ($StoreRefreshMetaTable t) => t.entryType.equals(entryType.apiValue) & t.deviceId.equals(deviceId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return row.refreshedAt?.toUtc();
  }

  Future<int> countItems({
    required StoreEntryType entryType,
    required String deviceId,
  }) async {
    final Expression<int> countExp = _db.storeItems.appId.count();
    final TypedResult row =
        await (_db.selectOnly(_db.storeItems)
              ..addColumns(<Expression<Object>>[countExp])
              ..where(
                _db.storeItems.entryType.equals(entryType.apiValue) &
                    _db.storeItems.deviceId.equals(deviceId) &
                    _db.storeItems.isRemoved.equals(false),
              ))
            .getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_owned) await _db.close();
  }

  /// Maps a Drift [StoreItemRow] into the domain model.
  static StoreItem itemFromData(StoreItemRow row) => StoreItem(
    appId: row.appId,
    entryType: entryTypeFromStorage(row.entryType),
    deviceId: row.deviceId,
    deviceSource: row.deviceSource,
    version: row.version,
    name: row.name,
    brief: row.brief,
    description: row.description,
    changelog: row.changelog,
    iconUrl: row.iconUrl,
    screenshotUrls: row.screenshotUrls,
    downloadUrl: row.downloadUrl,
    downloadSize: row.downloadSize,
    publisherName: row.publisherName,
    publisherId: row.publisherId,
    categoryName: row.categoryName,
    categoryId: row.categoryId,
    builtinId: row.builtinId,
    isFree: row.isFree,
    isRemoved: row.isRemoved,
    isStarred: row.isStarred,
    starSeenVersion: row.starSeenVersion,
    minZeppVersion: row.minZeppVersion,
    updatedAt: row.updatedAt?.toUtc(),
    refreshedAt: row.refreshedAt?.toUtc(),
  );

  /// Serializes a domain [StoreItem] into a Drift companion for upserts.
  static StoreItemsCompanion itemToCompanion(StoreItem item) => StoreItemsCompanion.insert(
    appId: item.appId,
    entryType: item.entryType.apiValue,
    deviceId: item.deviceId,
    deviceSource: item.deviceSource,
    version: item.version,
    name: item.name,
    brief: Value<String>(item.brief),
    description: Value<String>(item.description),
    changelog: Value<String>(item.changelog),
    iconUrl: Value<String>(item.iconUrl),
    screenshotUrls: Value<List<String>>(item.screenshotUrls),
    downloadUrl: Value<String>(item.downloadUrl),
    downloadSize: Value<int?>(item.downloadSize),
    publisherName: Value<String>(item.publisherName),
    publisherId: Value<int?>(item.publisherId),
    categoryName: Value<String>(item.categoryName),
    categoryId: Value<int?>(item.categoryId),
    builtinId: Value<int?>(item.builtinId),
    isFree: Value<bool>(item.isFree),
    isRemoved: Value<bool>(item.isRemoved),
    isStarred: Value<bool>(item.isStarred),
    starSeenVersion: Value<String>(item.starSeenVersion),
    minZeppVersion: Value<String>(item.minZeppVersion),
    updatedAt: Value<DateTime?>(item.updatedAt?.toUtc()),
    refreshedAt: Value<DateTime?>(item.refreshedAt?.toUtc()),
  );

  /// Round-trip helpers for tests / legacy call sites.
  static Map<String, Object?> itemToRow(StoreItem item) => <String, Object?>{
    'app_id': item.appId,
    'entry_type': item.entryType.apiValue,
    'device_id': item.deviceId,
    'device_source': item.deviceSource,
    'version': item.version,
    'name': item.name,
    'brief': item.brief,
    'description': item.description,
    'changelog': item.changelog,
    'icon_url': item.iconUrl,
    'screenshot_urls': encodeScreenshotUrls(item.screenshotUrls),
    'download_url': item.downloadUrl,
    'download_size': item.downloadSize,
    'publisher_name': item.publisherName,
    'publisher_id': item.publisherId,
    'category_name': item.categoryName,
    'category_id': item.categoryId,
    'builtin_id': item.builtinId,
    'is_free': item.isFree ? 1 : 0,
    'is_removed': item.isRemoved ? 1 : 0,
    'is_starred': item.isStarred ? 1 : 0,
    'star_seen_version': item.starSeenVersion,
    'min_zepp_version': item.minZeppVersion,
    'updated_at': item.updatedAt?.toIso8601String(),
    'refreshed_at': item.refreshedAt?.toIso8601String(),
  };

  static StoreItem itemFromRow(Map<String, Object?> row) {
    int? asInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    String asString(Object? v) => v?.toString() ?? '';

    return StoreItem(
      appId: asInt(row['app_id']) ?? 0,
      entryType: entryTypeFromStorage(asString(row['entry_type'])),
      deviceId: asString(row['device_id']),
      deviceSource: asInt(row['device_source']) ?? 0,
      version: asString(row['version']),
      name: asString(row['name']),
      brief: asString(row['brief']),
      description: asString(row['description']),
      changelog: asString(row['changelog']),
      iconUrl: asString(row['icon_url']),
      screenshotUrls: decodeScreenshotUrls(row['screenshot_urls']),
      downloadUrl: asString(row['download_url']),
      downloadSize: asInt(row['download_size']),
      publisherName: asString(row['publisher_name']),
      publisherId: asInt(row['publisher_id']),
      categoryName: asString(row['category_name']),
      categoryId: asInt(row['category_id']),
      builtinId: asInt(row['builtin_id']),
      isFree: (asInt(row['is_free']) ?? 1) != 0,
      isRemoved: (asInt(row['is_removed']) ?? 0) != 0,
      isStarred: (asInt(row['is_starred']) ?? 0) != 0,
      starSeenVersion: asString(row['star_seen_version']),
      minZeppVersion: asString(row['min_zepp_version']),
      updatedAt: DateTime.tryParse(asString(row['updated_at'])),
      refreshedAt: DateTime.tryParse(asString(row['refreshed_at'])),
    );
  }

  /// Parses the persisted `entry_type` column.
  static StoreEntryType entryTypeFromStorage(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'watch':
        return StoreEntryType.watch;
      case 'lightapp':
      default:
        return StoreEntryType.lightapp;
    }
  }

  /// Serializes screenshot URLs for the `screenshot_urls` column.
  static String encodeScreenshotUrls(List<String> urls) => const ScreenshotUrlsConverter().toSql(urls);

  /// Parses the `screenshot_urls` JSON array column.
  static List<String> decodeScreenshotUrls(Object? raw) {
    if (raw == null) return const <String>[];
    return const ScreenshotUrlsConverter().fromSql(raw.toString());
  }
}
