import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/store/store_item.dart';
import 'package:zelp/domain/store/store_package_stamp.dart';

void main() {
  group('StorePackageStamp.tryParse', () {
    test('reads YYYYMMDD from a store package URL', () {
      expect(
        StorePackageStamp.tryParse(
          'https://store-cdn.zepp.com/custom_user_app/20261104/'
          'zkyQeADWsHKmHUaqPQbJNEysRFlXTmIF/1130086.zip',
        ),
        DateTime.utc(2026, 11, 4, 12),
      );
      expect(
        StorePackageStamp.tryParse(
          'https://store-cdn.huami.com/custom_user_app/20221219/'
          'zpFTWWXvzkzeffCYKOtCwyGnhNMUhDSx/1014390.zip',
        ),
        DateTime.utc(2022, 12, 19, 12),
      );
    });

    test('returns null when the URL has no upload day', () {
      expect(StorePackageStamp.tryParse('https://cdn.example/face.zip'), isNull);
      expect(StorePackageStamp.tryParse(null), isNull);
      expect(StorePackageStamp.tryParse(''), isNull);
    });

    test('rejects tokens that are not a real calendar day', () {
      expect(
        StorePackageStamp.tryParse('https://store-cdn.zepp.com/custom_user_app/20261301/token/1.zip'),
        isNull,
      );
      expect(
        StorePackageStamp.tryParse('https://store-cdn.zepp.com/custom_user_app/20260231/token/1.zip'),
        isNull,
      );
    });
  });

  test('releaseAt falls back to the package URL when updated_at was omitted', () {
    const StoreItem item = StoreItem(
      appId: 1,
      entryType: StoreEntryType.watch,
      deviceSource: 229,
      version: '1.0.2',
      name: 'Sparta',
      downloadUrl:
          'https://store-cdn.huami.com/custom_user_app/20221219/'
          'zpFTWWXvzkzeffCYKOtCwyGnhNMUhDSx/1014390.zip',
    );
    expect(item.releaseAt, DateTime.utc(2022, 12, 19, 12));
    expect(item.releasedDateLabel, isNotNull);
    expect(item.browseMetaParts().join(' '), contains('Released'));
  });
}
