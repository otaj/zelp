import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/credential_store.dart';
import 'package:zelp/services/store_catalog_db.dart';
import 'package:zelp/services/store_catalog_service.dart';
import 'package:zelp/services/store_market_client.dart';
import 'package:zelp/services/zepp_client.dart';
import 'package:zelp/services/zepp_version_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StoreCatalogDb db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('store_svc_');
    db = StoreCatalogDb(
      opener:
          ({required path, required version, required onCreate, onUpgrade}) {
            return databaseFactoryFfi.openDatabase(
              path,
              options: OpenDatabaseOptions(
                version: version,
                onCreate: onCreate,
                onUpgrade: onUpgrade,
              ),
            );
          },
      databasePath: p.join(tempDir.path, 'catalog.db'),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  final watch = WatchModel(
    deviceId: 'gtr4',
    name: 'GTR 4',
    osVersion: '3.0',
    variants: [
      WatchVariant(
        deviceSource: 229,
        productionId: 1,
        appName: 'com.huami.midong',
      ),
    ],
  );

  test('refresh caches catalog; browse does not hit network', () async {
    var networkHits = 0;
    final mock = MockClient((request) async {
      networkHits++;
      if (request.url.path.endsWith('/homepage')) {
        return http.Response(
          '{"categories":[{"category_id":9,"category":"Tools"}]}',
          200,
        );
      }
      if (request.url.path.contains('/category-apps/9')) {
        final page = request.url.queryParameters['page'];
        if (page == '1') {
          return http.Response('''
{"data":[{"id":5,"name":"Cached App","version":"1.0","device_support_version":"1.0",
"size":12,"is_free":true,"image":"https://i/x.png","updated_at":0,
"brief_description":"Hi"}]}
''', 200);
        }
        return http.Response('{"data":[]}', 200);
      }
      if (request.url.path.contains('/apps/5')) {
        return http.Response(
          '{"download_url":"https://cdn.example/app.zpk","size":12,'
          '"description":"D","new_description":"C","publisher":{"name":"P"},'
          '"metas":{"builtin_id":5}}',
          200,
        );
      }
      fail('unexpected ${request.url}');
    });

    final prefs = await SharedPreferences.getInstance();
    final credentials = CredentialStore();
    await credentials.save(
      Credentials(email: 'user@amazfit.com', password: 'secret'),
    );

    final service = StoreCatalogService(
      db: db,
      marketClient: StoreMarketClient(httpClient: mock),
      credentialStore: credentials,
      versionClient: ZeppVersionClient(
        prefs: prefs,
        fallbackVersion: '10.0.0-play_1',
        httpClient: MockClient((_) async {
          fail('version refresh must not run');
        }),
      ),
      sessionFactory: (creds) => ZeppSession.authenticated(
        username: creds.email,
        password: creds.password,
        appToken: 'app',
        userId: '42',
        loginToken: 'login',
      ),
    );

    final result = await service.refreshForWatch(
      watch: watch,
      entryType: StoreEntryType.lightapp,
      login: (_) async {},
    );
    expect(result.itemCount, greaterThan(0));
    expect(result.detailedCount, greaterThan(0));
    expect(networkHits, greaterThan(0));
    final hitsAfterRefresh = networkHits;

    // Second refresh: unchanged detail should be skipped.
    final second = await service.refreshForWatch(
      watch: watch,
      entryType: StoreEntryType.lightapp,
      login: (_) async {},
    );
    expect(second.skippedDetailCount, greaterThan(0));
    expect(second.detailedCount, 0);

    final cached = await service.browse(
      entryType: StoreEntryType.lightapp,
      deviceId: 'gtr4',
    );
    expect(cached.single.name, 'Cached App');
    expect(cached.single.hasDownload, isTrue);
    expect(cached.single.description, 'D');
    expect(cached.single.changelog, 'C');
    expect(networkHits, greaterThan(hitsAfterRefresh));
    // Browse itself adds no hits after the second refresh completed.
    final afterBrowse = networkHits;
    await service.browse(entryType: StoreEntryType.lightapp, deviceId: 'gtr4');
    expect(networkHits, afterBrowse);
  });

  test('refresh without remembered credentials fails clearly', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = StoreCatalogService(
      db: db,
      marketClient: StoreMarketClient(
        httpClient: MockClient((_) async => fail('no network')),
      ),
      credentialStore: CredentialStore(),
      versionClient: ZeppVersionClient(
        prefs: prefs,
        fallbackVersion: '10.0.0-play_1',
        httpClient: MockClient((_) async => fail('no network')),
      ),
    );

    await expectLater(
      () => service.refreshForWatch(
        watch: watch,
        entryType: StoreEntryType.watch,
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Credentials'),
        ),
      ),
    );
  });
}
