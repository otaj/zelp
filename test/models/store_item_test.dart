import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/models/store_item.dart';

void main() {
  group('StoreEntryType', () {
    test('maps Amazfit api paths and labels', () {
      expect(StoreEntryType.lightapp.apiValue, 'lightapp');
      expect(StoreEntryType.watch.apiValue, 'watch');
      expect(StoreEntryType.lightapp.label, 'Apps');
      expect(StoreEntryType.watch.label, 'Watchfaces');
      expect(StoreEntryType.fromApi('watch'), StoreEntryType.watch);
      expect(StoreEntryType.fromApi('lightapp'), StoreEntryType.lightapp);
    });
  });

  group('StoreItem', () {
    test('fromListApi skips empty version fallbacks and maps fields', () {
      final StoreItem item = StoreItem.fromListApi(
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
      expect(item.hasDownload, isFalse);
      expect(item.canDownload, isFalse);
    });

    test('mergeDetail fills download URL without inventing checksum', () {
      final StoreItem base = StoreItem.fromListApi(
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
      final StoreItem detailed = base.mergeDetail(<String, dynamic>{
        'download_url': 'https://cdn.example/face.zip',
        'size': 99,
        'description': 'Pretty',
        'new_description': 'v2 notes',
        'publisher': <String, Object>{'id': 1, 'name': 'Studio'},
        'metas': <String, int>{'builtin_id': 7},
        'config': '{"runtime":{"apiVersion":{"minVersion":"2.0.0"}}}',
      });
      expect(detailed.downloadUrl, 'https://cdn.example/face.zip');
      expect(detailed.downloadSize, 99);
      expect(detailed.description, 'Pretty');
      expect(detailed.changelog, 'v2 notes');
      expect(detailed.publisherName, 'Studio');
      expect(detailed.minZeppVersion, '2.0.0');
      expect(detailed.canDownload, isTrue);
      expect(detailed.suggestedFileName, 'face.zip');
    });

    test('suggestedFileName falls back when URL missing', () {
      const StoreItem item = StoreItem(
        appId: 9,
        entryType: StoreEntryType.lightapp,
        deviceSource: 1,
        version: '1.0-beta',
        name: 'X',
      );
      expect(item.suggestedFileName, 'app_9_1.0-beta.zip');
    });

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
      final StoreItem restored = StoreItem.fromRow(item.toRow());
      expect(restored.appId, 3);
      expect(restored.entryType, StoreEntryType.watch);
      expect(restored.downloadUrl, 'https://cdn.example/c.zip');
      expect(restored.refreshedAt?.toUtc(), DateTime.utc(2026, 7));
    });
  });
}
