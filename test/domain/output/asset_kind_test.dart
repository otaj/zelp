import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/output/asset_kind.dart';

void main() {
  group('AssetKind.folderName', () {
    test('maps each download kind to its subfolder', () {
      expect(AssetKind.firmware.folderName, 'fw');
      expect(AssetKind.app.folderName, 'apps');
      expect(AssetKind.watchface.folderName, 'watchfaces');
      expect(AssetKind.gps.folderName, 'gps');
    });
  });
}
