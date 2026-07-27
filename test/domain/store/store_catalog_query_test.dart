import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/models/store_item.dart';

void main() {
  group('starred update detection', () {
    test('hasStarredUpdate when version differs from seen', () {
      const updated = StoreItem(
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

      const seen = StoreItem(
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
      const cached = StoreItem(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceSource: 229,
        version: '1.0',
        name: 'A',
        downloadUrl: 'https://cdn.example.com/a.zpk',
        description: 'About',
        changelog: 'Notes',
      );
      const listed = StoreItem(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceSource: 229,
        version: '1.0',
        name: 'A',
        downloadSize: null,
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
    final labels = compatibleWatchLabels(
      deviceIds: const ['gtr4', 'balance', 'unknown'],
      currentDeviceId: 'gtr4',
      nameByDeviceId: const {'gtr4': 'GTR 4', 'balance': 'Balance'},
    );
    expect(labels, ['Balance']);
  });
}
