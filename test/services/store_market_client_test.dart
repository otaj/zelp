import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/store_market_client.dart';

void main() {
  final WatchVariant variant = WatchVariant(
    deviceSource: 229,
    productionId: 1,
    appName: 'com.huami.midong',
  );

  group('StoreMarketClient', () {
    test('fetchCategorizedCatalog walks homepage + category pages', () async {
      final MockClient mock = MockClient((http.Request request) async {
        final String path = request.url.path;
        if (path.endsWith('/homepage')) {
          return http.Response(
            '{"categories":[{"category_id":1,"category":"Tools"}]}',
            200,
          );
        }
        if (path.contains('/category-apps/1')) {
          final String? page = request.url.queryParameters['page'];
          if (page == '1') {
            return http.Response('''
{"data":[{"id":11,"name":"App One","image":"https://i/1.png","version":"1.0",
"device_support_version":"1.0","size":100,"is_free":true,"updated_at":0,
"brief_description":"One"}]}
''', 200);
          }
          return http.Response('{"data":[]}', 200);
        }
        fail('unexpected ${request.url}');
      });

      final StoreMarketClient client = StoreMarketClient(httpClient: mock);
      addTearDown(client.close);
      final List<StoreItem> items = await client.fetchCategorizedCatalog(
        variant: variant,
        entryType: StoreEntryType.lightapp,
        appToken: 'token',
        userId: 'user',
        zeppVersion: AppVersion('10.6.1-play_151920'),
      );
      expect(items, hasLength(1));
      expect(items.single.name, 'App One');
      expect(items.single.categoryName, 'Tools');
    });

    test('fetchItemDetail returns download payload', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.url.path, contains('/apps/11'));
        return http.Response('''
{"download_url":"https://cdn.example/a.zpk","size":50,
"description":"Desc","new_description":"CL",
"publisher":{"id":2,"name":"Pub"},"metas":{"builtin_id":11}}
''', 200);
      });
      final StoreMarketClient client = StoreMarketClient(httpClient: mock);
      addTearDown(client.close);
      final Map<String, dynamic> detail = await client.fetchItemDetail(
        variant: variant,
        entryType: StoreEntryType.lightapp,
        appId: 11,
        appToken: 't',
        userId: 'u',
        zeppVersion: AppVersion('10.0.0-play_1'),
      );
      expect(detail['download_url'], 'https://cdn.example/a.zpk');
    });
  });
}
