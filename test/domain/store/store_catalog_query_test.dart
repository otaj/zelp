import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/models/store_item.dart';

void main() {
  group('StoreSortBy', () {
    test('updatedAt sort is labeled Released', () {
      expect(StoreSortBy.updatedAt.label, 'Released');
    });
  });

  group('starred update detection', () {
    test('hasStarredUpdate when version differs from seen', () {
      const StoreItem updated = StoreItem(
        appId: 1,
        entryType: StoreEntryType.watch,
        deviceSource: 1,
        version: '2.0',
        name: 'Face',
        isStarred: true,
        starSeenVersion: '1.0',
      );
      expect(updated.hasStarredUpdate, isTrue);
      expect(hasStarredUpdate(updated), isTrue);

      const StoreItem seen = StoreItem(
        appId: 1,
        entryType: StoreEntryType.watch,
        deviceSource: 1,
        version: '2.0',
        name: 'Face',
        isStarred: true,
        starSeenVersion: '2.0',
      );
      expect(seen.hasStarredUpdate, isFalse);
    });

    test('detailFetchReason skips unchanged enriched rows', () {
      const StoreItem cached = StoreItem(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceSource: 229,
        version: '1.0',
        name: 'A',
        downloadUrl: 'https://cdn.example.com/a.zpk',
        description: 'About',
        changelog: 'Notes',
      );
      const StoreItem listed = StoreItem(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceSource: 229,
        version: '1.0',
        name: 'A',
      );
      expect(detailFetchReason(listed: listed, cached: cached), isNull);
      expect(
        detailFetchReason(
          listed: listed.copyWith(version: '2.0'),
          cached: cached,
        ),
        StoreDetailFetchReason.versionChanged,
      );
    });
  });

  test('compatibleWatchLabels skips current and unknown ids', () {
    final List<String> labels = compatibleWatchLabels(
      deviceIds: const <String>['gtr4', 'balance', 'unknown'],
      currentDeviceId: 'gtr4',
      nameByDeviceId: const <String, String>{'gtr4': 'GTR 4', 'balance': 'Balance'},
    );
    expect(labels, <String>['Balance']);
  });

  test('hasSheetFilters ignores free-text search', () {
    expect(const StoreCatalogQuery(text: 'timer').hasActiveFilters, isTrue);
    expect(const StoreCatalogQuery(text: 'timer').hasSheetFilters, isFalse);
    expect(
      const StoreCatalogQuery(price: StorePriceFilter.free).hasSheetFilters,
      isTrue,
    );
  });
}
