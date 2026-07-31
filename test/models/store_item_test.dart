import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/services/store_catalog_db.dart';
import 'package:zelp/services/store_market_client.dart';

void main() {
  group('StoreEntryType', () {
    test('maps Amazfit api paths and labels', () {
      expect(StoreEntryType.lightapp.apiValue, 'lightapp');
      expect(StoreEntryType.watch.apiValue, 'watch');
      expect(StoreEntryType.lightapp.label, 'Apps');
      expect(StoreEntryType.watch.label, 'Watchfaces');
      expect(StoreMarketClient.entryTypeFromApi('watch'), StoreEntryType.watch);
      expect(
        StoreMarketClient.entryTypeFromApi('lightapp'),
        StoreEntryType.lightapp,
      );
      expect(
        StoreCatalogDb.entryTypeFromStorage('watch'),
        StoreEntryType.watch,
      );
    });
  });

  group('StoreMarketClient mapping', () {
    test('itemFromListApi skips empty version fallbacks and maps fields', () {
      final StoreItem item = StoreMarketClient.itemFromListApi(
        row: <String, dynamic>{
          'id': 42,
          'name': 'Timer',
          'image': 'https://cdn.example/i.png',
          'version': '',
          'device_support_version': '1.2.0',
          'size': 1200,
          'is_free': true,
          'updated_at': 1700000000,
          'brief_description': 'A timer',
          'category_name': 'Tools',
        },
        entryType: StoreEntryType.lightapp,
        deviceSource: 229,
      );
      expect(item.appId, 42);
      expect(item.version, '1.2.0');
      expect(item.categoryName, 'Tools');
      expect(item.updatedAt?.toUtc(), DateTime.utc(2023, 11, 14, 22, 13, 20));
      expect(item.releasedDateLabel, isNotNull);
      expect(item.hasDownload, isFalse);
      expect(item.canDownload, isFalse);
    });

    test('itemFromListApi omits release date when updated_at is 0', () {
      final StoreItem item = StoreMarketClient.itemFromListApi(
        row: <String, dynamic>{
          'id': 1,
          'name': 'X',
          'version': '1.0',
          'size': 1,
          'is_free': true,
          'updated_at': 0,
        },
        entryType: StoreEntryType.lightapp,
        deviceSource: 1,
      );
      expect(item.updatedAt, isNull);
      expect(item.releasedDateLabel, isNull);
    });

    test('mergeDetail fills download URL without inventing checksum', () {
      final StoreItem base = StoreMarketClient.itemFromListApi(
        row: <String, dynamic>{
          'id': 7,
          'name': 'Face',
          'size': 10,
          'version': '2.0',
          'is_free': true,
        },
        entryType: StoreEntryType.watch,
        deviceSource: 100,
      );
      final StoreItem detailed = StoreMarketClient.mergeDetail(
        base,
        <String, dynamic>{
          'download_url': 'https://cdn.example/face.zip',
          'size': 99,
          'description': 'Pretty',
          'new_description': 'v2 notes',
          'publisher': <String, Object>{'id': 1, 'name': 'Studio'},
          'metas': <String, int>{'builtin_id': 7},
          'config': '{"runtime":{"apiVersion":{"minVersion":"2.0.0"}}}',
        },
      );
      expect(detailed.downloadUrl, 'https://cdn.example/face.zip');
      expect(detailed.downloadSize, 99);
      expect(detailed.description, 'Pretty');
      expect(detailed.changelog, 'v2 notes');
      expect(detailed.publisherName, 'Studio');
      expect(detailed.minZeppVersion, '2.0.0');
      expect(detailed.canDownload, isTrue);
      expect(detailed.suggestedFileName(), 'face.zip');
      expect(
        detailed.suggestedFileName(semantic: true),
        'Face_2.0.zip',
      );
    });

    test('mergeDetail prefers detail updated_at as release time', () {
      final StoreItem base = StoreMarketClient.itemFromListApi(
        row: <String, dynamic>{
          'id': 7,
          'name': 'Face',
          'size': 10,
          'version': '2.0',
          'is_free': true,
          'updated_at': 1700000000,
        },
        entryType: StoreEntryType.watch,
        deviceSource: 100,
      );
      final StoreItem detailed = StoreMarketClient.mergeDetail(
        base,
        <String, dynamic>{
          'download_url': 'https://cdn.example/face.zip',
          'updated_at': 1710000000,
        },
      );
      expect(detailed.updatedAt?.toUtc(), DateTime.utc(2024, 3, 9, 16, 0, 0));
    });
  });

  group('StoreItem', () {
    test('suggestedFileName falls back when URL missing', () {
      const StoreItem item = StoreItem(
        appId: 9,
        entryType: StoreEntryType.lightapp,
        deviceSource: 1,
        version: '1.0-beta',
        name: 'X',
      );
      expect(item.suggestedFileName(), 'app_9_1.0-beta.zip');
      expect(item.suggestedFileName(semantic: true), 'X_1.0-beta.zip');
    });
  });

  group('StoreCatalogDb mapping', () {
    test('row round-trip preserves fields', () {
      final StoreItem item = StoreItem(
        appId: 3,
        entryType: StoreEntryType.watch,
        deviceSource: 229,
        version: '1.0',
        name: 'Circle',
        downloadUrl: 'https://cdn.example/c.zip',
        refreshedAt: DateTime.utc(2026, 7),
      );
      final StoreItem restored = StoreCatalogDb.itemFromRow(
        StoreCatalogDb.itemToRow(item),
      );
      expect(restored.appId, 3);
      expect(restored.entryType, StoreEntryType.watch);
      expect(restored.downloadUrl, 'https://cdn.example/c.zip');
      expect(restored.refreshedAt?.toUtc(), DateTime.utc(2026, 7));
    });
  });
}
