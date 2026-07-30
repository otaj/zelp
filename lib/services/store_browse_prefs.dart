import 'package:shared_preferences/shared_preferences.dart';

import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/models/store_item.dart';

/// Persists last filter/sort choice per Apps / Watchfaces tab.
class StoreBrowsePrefs {
  StoreBrowsePrefs({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async => _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();

  String _key(StoreEntryType type, String suffix) => 'store_browse_${type.apiValue}_$suffix';

  Future<StoreCatalogQuery> load(StoreEntryType type) async {
    final SharedPreferences prefs = await _ensure();
    final String sortName = prefs.getString(_key(type, 'sort')) ?? StoreSortBy.name.name;
    final String dirName = prefs.getString(_key(type, 'dir')) ?? StoreSortDirection.ascending.name;
    final String priceName = prefs.getString(_key(type, 'price')) ?? StorePriceFilter.all.name;
    final String? category = prefs.getString(_key(type, 'category'));
    final String? publisher = prefs.getString(_key(type, 'publisher'));
    final bool starredOnly = prefs.getBool(_key(type, 'starred')) ?? false;

    return StoreCatalogQuery(
      categoryName: (category == null || category.isEmpty) ? null : category,
      publisherName: (publisher == null || publisher.isEmpty) ? null : publisher,
      price: StorePriceFilter.values.firstWhere(
        (StorePriceFilter e) => e.name == priceName,
        orElse: () => StorePriceFilter.all,
      ),
      starredOnly: starredOnly,
      sortBy: StoreSortBy.values.firstWhere(
        (StoreSortBy e) => e.name == sortName,
        orElse: () => StoreSortBy.name,
      ),
      sortDirection: StoreSortDirection.values.firstWhere(
        (StoreSortDirection e) => e.name == dirName,
        orElse: () => StoreSortDirection.ascending,
      ),
    );
  }

  Future<void> save(StoreEntryType type, StoreCatalogQuery query) async {
    final SharedPreferences prefs = await _ensure();
    await prefs.setString(_key(type, 'sort'), query.sortBy.name);
    await prefs.setString(_key(type, 'dir'), query.sortDirection.name);
    await prefs.setString(_key(type, 'price'), query.price.name);
    await prefs.setBool(_key(type, 'starred'), query.starredOnly);
    if (query.categoryName == null || query.categoryName!.isEmpty) {
      await prefs.remove(_key(type, 'category'));
    } else {
      await prefs.setString(_key(type, 'category'), query.categoryName!);
    }
    if (query.publisherName == null || query.publisherName!.isEmpty) {
      await prefs.remove(_key(type, 'publisher'));
    } else {
      await prefs.setString(_key(type, 'publisher'), query.publisherName!);
    }
  }
}
