import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/store/zepp_install_qr.dart';
import 'package:zelp/models/store_item.dart';

void main() {
  group('ZeppInstallQr apps (zpkd1://)', () {
    test('fromDownloadUrl matches Explorer https→zpkd1 transform', () {
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

    test('payloadFor lightapp uses zpkd1:// package URL', () {
      const item = StoreItem(
        appId: 1,
        entryType: StoreEntryType.lightapp,
        deviceSource: 229,
        version: '1.0',
        name: 'Timer',
        downloadUrl: 'https://cdn.example.com/t.zpk',
      );
      expect(ZeppInstallQr.payloadFor(item), 'zpkd1://cdn.example.com/t.zpk');
    });
  });

  group('ZeppInstallQr watchfaces (watchface://)', () {
    test('forWatchface matches Explorer InstallButton shape', () {
      expect(
        ZeppInstallQr.forWatchface(appTargetId: 42, host: 'explorer.example'),
        'watchface://explorer.example/api/wf_json/42',
      );
      expect(
        ZeppInstallQr.forWatchface(
          appTargetId: 42,
          host: 'explorer.example',
          mirrored: true,
        ),
        'watchface://explorer.example/api/wf_json/42/mirrored',
      );
      expect(
        ZeppInstallQr.forWatchface(
          appTargetId: 7,
          host: 'https://zepp.gfd.lt/extra',
        ),
        'watchface://zepp.gfd.lt/api/wf_json/7',
      );
      expect(ZeppInstallQr.forWatchface(appTargetId: 0), isNull);
      expect(ZeppInstallQr.forWatchface(appTargetId: 1, host: '  '), isNull);
    });

    test('payloadFor watch uses watchface:// not zpkd1://', () {
      const item = StoreItem(
        appId: 99,
        entryType: StoreEntryType.watch,
        deviceSource: 229,
        version: '2.0',
        name: 'Face',
        downloadUrl: 'https://cdn.example.com/wf.zpk',
        iconUrl: 'https://cdn.example.com/p.png',
      );
      expect(
        ZeppInstallQr.payloadFor(item, jsonHost: 'explorer.example'),
        'watchface://explorer.example/api/wf_json/99',
      );
      expect(
        ZeppInstallQr.payloadFor(item),
        'watchface://${ZeppInstallQr.defaultJsonHost}/api/wf_json/99',
      );
      // Must not fall back to the apps package transform.
      expect(ZeppInstallQr.payloadFor(item)!.startsWith('zpkd1://'), isFalse);
    });

    test('watchface JSON document matches Explorer schema keys', () {
      final doc = ZeppInstallQr.watchfaceJsonDocument(
        appId: 9,
        name: 'Face',
        updatedAtUnix: 1700000000,
        downloadUrl: 'https://cdn.example.com/wf.zpk',
        previewUrl: 'https://cdn.example.com/p.png',
        deviceSources: const [229, 230],
      );
      expect(
        doc.keys,
        containsAll([
          'appid',
          'name',
          'updated_at',
          'url',
          'preview',
          'devices',
        ]),
      );
      expect(doc['appid'], 9);
      expect(doc['devices'], [229, 230]);
    });

    test('watchfaceJsonDocumentFor maps StoreItem fields', () {
      final item = StoreItem(
        appId: 9,
        entryType: StoreEntryType.watch,
        deviceSource: 229,
        version: '1.0',
        name: 'Face',
        downloadUrl: 'https://cdn.example.com/wf.zpk',
        iconUrl: 'https://cdn.example.com/p.png',
        updatedAt: DateTime.utc(2023, 11, 14, 22, 13, 20),
      );
      final doc = ZeppInstallQr.watchfaceJsonDocumentFor(item)!;
      expect(doc['appid'], 9);
      expect(doc['name'], 'Face');
      expect(doc['url'], 'https://cdn.example.com/wf.zpk');
      expect(doc['preview'], 'https://cdn.example.com/p.png');
      expect(doc['devices'], [229]);
      expect(doc['updated_at'], 1700000000);
      expect(
        ZeppInstallQr.watchfaceJsonDocumentFor(
          const StoreItem(
            appId: 9,
            entryType: StoreEntryType.lightapp,
            deviceSource: 229,
            version: '1.0',
            name: 'Face',
            downloadUrl: 'https://cdn.example.com/wf.zpk',
          ),
        ),
        isNull,
      );
    });
  });
}
