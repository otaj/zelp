import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/store/zepp_install_qr.dart';
import 'package:zelp/models/store_item.dart';

void main() {
  group('ZeppInstallQr fromDownloadUrl', () {
    test('matches Explorer https→zpkd1 transform', () {
      expect(
        ZeppInstallQr.fromDownloadUrl('https://cdn.example.com/apps/timer.zpk'),
        'zpkd1://cdn.example.com/apps/timer.zpk',
      );
      expect(
        ZeppInstallQr.fromDownloadUrl('http://cdn.example.com/a.zpk'),
        'zpkd1://cdn.example.com/a.zpk',
      );
      expect(
        ZeppInstallQr.fromDownloadUrl('zpkd1://cdn.example.com/a.zpk'),
        'zpkd1://cdn.example.com/a.zpk',
      );
      expect(ZeppInstallQr.fromDownloadUrl(''), isNull);
      expect(ZeppInstallQr.fromDownloadUrl('ftp://x'), isNull);
    });
  });

  group('ZeppInstallQr payloadFor', () {
    test('lightapp uses zpkd1:// original package URL', () {
      const StoreItem item = StoreItem(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceSource: 229,
        version: '1.0',
        name: 'Timer',
        downloadUrl: 'https://cdn.example.com/t.zpk',
      );
      expect(ZeppInstallQr.payloadFor(item), 'zpkd1://cdn.example.com/t.zpk');
    });

    test('watchface uses zpkd1:// original package URL (not Explorer JSON host)', () {
      const StoreItem item = StoreItem(
        appId: 99,
        entryType: StoreEntryType.watch,
        deviceSource: 229,
        version: '2.0',
        name: 'Face',
        downloadUrl: 'https://cdn.example.com/wf.zpk',
        iconUrl: 'https://cdn.example.com/p.png',
      );
      expect(ZeppInstallQr.payloadFor(item), 'zpkd1://cdn.example.com/wf.zpk');
      expect(ZeppInstallQr.payloadFor(item)!.startsWith('watchface://'), isFalse);
    });

    test('returns null without a download URL', () {
      const StoreItem item = StoreItem(
        appId: 99,
        entryType: StoreEntryType.watch,
        deviceSource: 229,
        version: '2.0',
        name: 'Face',
      );
      expect(ZeppInstallQr.payloadFor(item), isNull);
    });
  });
}
