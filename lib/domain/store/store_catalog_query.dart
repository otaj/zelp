import 'package:zelp/domain/store/store_item.dart';

/// Sort keys for Apps / Watchfaces browse (SQLite cache only).
enum StoreSortBy {
  /// Member.
  name,

  /// Member.
  updatedAt,

  /// Member.
  size,

  /// Member.
  publisher,
  category;

  String get label => switch (this) {
    StoreSortBy.name => 'Name',
    StoreSortBy.updatedAt => 'Released',
    StoreSortBy.size => 'Size',
    StoreSortBy.publisher => 'Author',
    StoreSortBy.category => 'Category',
  };
}

enum StoreSortDirection {
  /// Member.
  ascending,
  descending;

  String get sql => this == StoreSortDirection.ascending ? 'ASC' : 'DESC';
}

/// Free/paid filter for the local catalog.
enum StorePriceFilter {
  /// Member.
  all,

  /// Member.
  free,
  paid;

  String get label => switch (this) {
    StorePriceFilter.all => 'All',
    StorePriceFilter.free => 'Free',
    StorePriceFilter.paid => 'Paid',
  };
}

/// Filter + sort for browsing the local store catalog (no network).
class StoreCatalogQuery {
  const StoreCatalogQuery({
    this.text = '',
    this.categoryName,
    this.publisherName,
    this.price = StorePriceFilter.all,
    this.starredOnly = false,
    this.sortBy = StoreSortBy.name,
    this.sortDirection = StoreSortDirection.ascending,
  });

  final String text;
  final String? categoryName;
  final String? publisherName;
  final StorePriceFilter price;
  final bool starredOnly;
  final StoreSortBy sortBy;
  final StoreSortDirection sortDirection;

  bool get hasActiveFilters => text.trim().isNotEmpty || hasSheetFilters;

  /// Category / author / price / starred (excludes free-text search).
  bool get hasSheetFilters =>
      (categoryName != null && categoryName!.isNotEmpty) ||
      (publisherName != null && publisherName!.isNotEmpty) ||
      price != StorePriceFilter.all ||
      starredOnly;

  StoreCatalogQuery copyWith({
    String? text,
    String? categoryName,
    bool clearCategory = false,
    String? publisherName,
    bool clearPublisher = false,
    StorePriceFilter? price,
    bool? starredOnly,
    StoreSortBy? sortBy,
    StoreSortDirection? sortDirection,
  }) => StoreCatalogQuery(
    text: text ?? this.text,
    categoryName: clearCategory ? null : (categoryName ?? this.categoryName),
    publisherName: clearPublisher ? null : (publisherName ?? this.publisherName),
    price: price ?? this.price,
    starredOnly: starredOnly ?? this.starredOnly,
    sortBy: sortBy ?? this.sortBy,
    sortDirection: sortDirection ?? this.sortDirection,
  );
}

/// Why a listed market row still needs a detail API fetch on refresh.
enum StoreDetailFetchReason {
  /// Member.
  missing,

  /// Member.
  versionChanged,

  /// Member.
  updatedAtChanged,

  /// Member.
  sizeChanged,

  /// Member.
  missingDownload,

  /// Member.
  missingDescription,
}

/// Pure incremental heuristic: skip detail when cache already has equivalent
/// list metadata + download URL + description.
///
/// List pages are always re-walked (market APIs have no since/delta). Detail
/// (`/apps/{id}`) is fetched only when this returns non-null.
StoreDetailFetchReason? detailFetchReason({
  required StoreItem listed,
  required StoreItem? cached,
}) {
  if (cached == null) return StoreDetailFetchReason.missing;
  if (listed.version != cached.version) {
    return StoreDetailFetchReason.versionChanged;
  }
  if (listed.updatedAt != null && cached.updatedAt != null && listed.updatedAt!.toUtc() != cached.updatedAt!.toUtc()) {
    return StoreDetailFetchReason.updatedAtChanged;
  }
  if (listed.updatedAt != null && cached.updatedAt == null) {
    return StoreDetailFetchReason.updatedAtChanged;
  }
  if (listed.downloadSize != null && listed.downloadSize != cached.downloadSize) {
    return StoreDetailFetchReason.sizeChanged;
  }
  if (listed.isFree && !cached.hasDownload) {
    return StoreDetailFetchReason.missingDownload;
  }
  // Description + changelog come from detail. Empty description means we never
  // enriched (or an older cache) — refetch. Empty changelog alone is OK: the
  // market often omits “What’s new”; we must not invent one or refetch forever.
  if (listed.isFree && cached.description.trim().isEmpty) {
    return StoreDetailFetchReason.missingDescription;
  }
  return null;
}

/// Merges fresh list-row fields into a cached item when detail is skipped.
StoreItem mergeListIntoCached(StoreItem listed, StoreItem cached) => cached.copyWith(
  name: listed.name.isNotEmpty ? listed.name : cached.name,
  brief: listed.brief.isNotEmpty ? listed.brief : cached.brief,
  iconUrl: listed.iconUrl.isNotEmpty ? listed.iconUrl : cached.iconUrl,
  downloadSize: listed.downloadSize ?? cached.downloadSize,
  categoryName: listed.categoryName.isNotEmpty ? listed.categoryName : cached.categoryName,
  categoryId: listed.categoryId ?? cached.categoryId,
  isFree: listed.isFree,
  updatedAt: listed.updatedAt ?? cached.updatedAt,
  deviceId: listed.deviceId.isNotEmpty ? listed.deviceId : cached.deviceId,
  deviceSource: listed.deviceSource != 0 ? listed.deviceSource : cached.deviceSource,
  isRemoved: false,
  isStarred: cached.isStarred,
  starSeenVersion: cached.starSeenVersion,
);

/// Maps cached device ids to display names for “Also works on …”.
List<String> compatibleWatchLabels({
  required List<String> deviceIds,
  required String currentDeviceId,
  required Map<String, String> nameByDeviceId,
}) {
  final List<String> labels = <String>[];
  for (final String id in deviceIds) {
    if (id == currentDeviceId) continue;
    final String? name = nameByDeviceId[id];
    if (name == null || name.trim().isEmpty) continue;
    labels.add(name.trim());
  }
  labels.sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return labels;
}
