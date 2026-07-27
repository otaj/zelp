import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/primitives/app_version.dart';
import '../models/store_item.dart';
import '../models/watch_model.dart';
import 'exceptions.dart';

/// Amazfit market API client (same endpoints as explorer `fetch/api.py`).
///
/// Base: `https://api.amazfit.com/market/devices/{deviceSource}/{entryType}/…`
/// Requires an authenticated [appToken] + [userId] from [ZeppSession].
class StoreMarketClient {
  StoreMarketClient({
    http.Client? httpClient,
    this.apiLevel = 500,
    this.country = 'US',
    this.baseUrl = 'https://api.amazfit.com',
  }) : _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  final http.Client _http;
  final bool _ownsClient;
  final int apiLevel;
  final String country;
  final String baseUrl;

  /// Fetches homepage categories then paginated category apps (explorer
  /// `fetch_categorized`). Skips zero-size rows.
  ///
  /// [deviceId] is stamped on each row for model-centric caching; market URLs
  /// still use [variant.deviceSource].
  Future<List<StoreItem>> fetchCategorizedCatalog({
    required WatchVariant variant,
    required StoreEntryType entryType,
    required String appToken,
    required String userId,
    required AppVersion zeppVersion,
    String deviceId = '',
    int pageLimit = 200,
    void Function(int loaded)? onProgress,
  }) async {
    final headers = _headers(
      variant: variant,
      entryType: entryType,
      appToken: appToken,
      zeppVersion: zeppVersion,
    );
    final commonQuery = {
      'api_level': '$apiLevel',
      'userid': userId,
      'user_country': country,
      'per_page': '15',
    };

    final homepageUri = Uri.parse(
      '$baseUrl/market/devices/${variant.deviceSource}/${entryType.apiValue}/homepage',
    ).replace(queryParameters: commonQuery);

    final homepageResp = await _http.get(homepageUri, headers: headers);
    if (homepageResp.statusCode != 200) {
      throw DeviceException(
        'Market homepage failed (status ${homepageResp.statusCode})',
        code: 'store-homepage-failed',
      );
    }
    final homepageJson = jsonDecode(homepageResp.body);
    if (homepageJson is! Map) {
      throw DeviceException(
        'Unexpected market homepage format',
        code: 'store-homepage-invalid',
      );
    }
    final categoriesRaw = homepageJson['categories'];
    final categories = <({int id, String name})>[];
    if (categoriesRaw is List) {
      for (final entry in categoriesRaw) {
        if (entry is! Map) continue;
        final id = entry['category_id'];
        final name = entry['category']?.toString() ?? '';
        if (id is num) {
          categories.add((id: id.toInt(), name: name));
        }
      }
    }

    final items = <StoreItem>[];
    var globPage = 0;
    for (final category in categories) {
      var page = 1;
      while (true) {
        globPage++;
        if (globPage > pageLimit) break;

        final listUri = Uri.parse(
          '$baseUrl/market/devices/${variant.deviceSource}/'
          '${entryType.apiValue}/category-apps/${category.id}',
        ).replace(queryParameters: {...commonQuery, 'page': '$page'});
        final listResp = await _http.get(listUri, headers: headers);
        if (listResp.statusCode != 200) {
          throw DeviceException(
            'Market category list failed (status ${listResp.statusCode})',
            code: 'store-list-failed',
          );
        }
        final listJson = jsonDecode(listResp.body);
        if (listJson is! Map) {
          throw DeviceException(
            'Unexpected market list format',
            code: 'store-list-invalid',
          );
        }
        final data = listJson['data'];
        if (data is! List || data.isEmpty) break;

        for (final row in data) {
          if (row is! Map) continue;
          final map = Map<String, dynamic>.from(row);
          map['category_name'] = category.name;
          final size = map['size'];
          if (size is num && size == 0) continue;
          items.add(
            StoreItem.fromListApi(
              row: map,
              entryType: entryType,
              deviceSource: variant.deviceSource,
              deviceId: deviceId,
            ),
          );
          onProgress?.call(items.length);
        }
        page++;
      }
      if (globPage > pageLimit) break;
    }
    return items;
  }

  /// Detail fetch for download URL / publisher / description (explorer
  /// `fetch_item`).
  Future<Map<String, dynamic>> fetchItemDetail({
    required WatchVariant variant,
    required StoreEntryType entryType,
    required int appId,
    required String appToken,
    required String userId,
    required AppVersion zeppVersion,
  }) async {
    final headers = _headers(
      variant: variant,
      entryType: entryType,
      appToken: appToken,
      zeppVersion: zeppVersion,
    );
    final uri =
        Uri.parse(
          '$baseUrl/market/devices/${variant.deviceSource}/'
          '${entryType.apiValue}/apps/$appId',
        ).replace(
          queryParameters: {
            'userid': userId,
            'user_country': country,
            'api_level': '$apiLevel',
          },
        );
    final resp = await _http.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw DeviceException(
        'Market detail failed (status ${resp.statusCode})',
        code: 'store-detail-failed',
      );
    }
    final json = jsonDecode(resp.body);
    if (json is! Map) {
      throw DeviceException(
        'Unexpected market detail format',
        code: 'store-detail-invalid',
      );
    }
    final map = Map<String, dynamic>.from(json);
    if (map.containsKey('message') && !map.containsKey('download_url')) {
      throw DeviceException(
        map['message']?.toString() ?? 'Market detail error',
        code: 'store-detail-error',
      );
    }
    return map;
  }

  Map<String, String> _headers({
    required WatchVariant variant,
    required StoreEntryType entryType,
    required String appToken,
    required AppVersion zeppVersion,
  }) {
    final appName = entryType == StoreEntryType.lightapp
        ? 'com.huami.midong'
        : variant.appName;
    return {
      'apptoken': appToken,
      'Country': country,
      'appplatform': 'android_phone',
      'appname': appName,
      'hm-privacy-diagnostics': 'false',
      'cv': zeppVersion.cvToken,
      'user-agent':
          'Zepp/${zeppVersion.displayName} (Pixel 4; Android 12; Density/2.75)',
    };
  }

  void close() {
    if (_ownsClient) _http.close();
  }
}
