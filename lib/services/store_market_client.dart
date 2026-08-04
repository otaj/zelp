import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/zepp_client.dart' show ZeppSession;

/// Amazfit market API client (same endpoints as explorer `fetch/api.py`).
///
/// Base: `https://api.amazfit.com/market/devices/{deviceSource}/{entryType}/…`
/// Requires an authenticated `appToken` + `userId` from [ZeppSession].
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
  /// `deviceId` is stamped on each row for model-centric caching; market URLs
  /// still use [variant]'s `deviceSource`.
  ///
  /// [forCountry] overrides the client default [country] for this request
  /// (`user_country` query + `Country` header).
  Future<List<StoreItem>> fetchCategorizedCatalog({
    required WatchVariant variant,
    required StoreEntryType entryType,
    required String appToken,
    required String userId,
    required AppVersion zeppVersion,
    String deviceId = '',
    int pageLimit = 200,
    String? forCountry,
    void Function(int loaded)? onProgress,
    void Function(StoreItem item)? onItem,
  }) async {
    final String marketCountry = forCountry ?? country;
    final Map<String, String> headers = _headers(
      variant: variant,
      entryType: entryType,
      appToken: appToken,
      zeppVersion: zeppVersion,
      forCountry: marketCountry,
    );
    final Map<String, String> commonQuery = <String, String>{
      'api_level': '$apiLevel',
      'userid': userId,
      'user_country': marketCountry,
      'per_page': '15',
    };

    final Uri homepageUri = Uri.parse(
      '$baseUrl/market/devices/${variant.deviceSource}/${entryType.apiValue}/homepage',
    ).replace(queryParameters: commonQuery);

    final http.Response homepageResp = await _http.get(homepageUri, headers: headers);
    if (homepageResp.statusCode != 200) {
      throw DeviceException(
        'Market homepage failed (status ${homepageResp.statusCode})',
        code: 'store-homepage-failed',
      );
    }
    final dynamic homepageJson = jsonDecode(homepageResp.body);
    if (homepageJson is! Map) {
      throw DeviceException(
        'Unexpected market homepage format',
        code: 'store-homepage-invalid',
      );
    }
    final dynamic categoriesRaw = homepageJson['categories'];
    final List<({int id, String name})> categories = <({int id, String name})>[];
    if (categoriesRaw is List) {
      for (final Object? entry in categoriesRaw) {
        if (entry is! Map) continue;
        final dynamic id = entry['category_id'];
        final String name = entry['category']?.toString() ?? '';
        if (id is num) {
          categories.add((id: id.toInt(), name: name));
        }
      }
    }

    final List<StoreItem> items = <StoreItem>[];
    // Same app can appear under multiple homepage categories; keep one row.
    final Set<String> seenKeys = <String>{};
    int globPage = 0;
    for (final ({int id, String name}) category in categories) {
      int page = 1;
      while (true) {
        globPage++;
        if (globPage > pageLimit) break;

        final Uri listUri = Uri.parse(
          '$baseUrl/market/devices/${variant.deviceSource}/'
          '${entryType.apiValue}/category-apps/${category.id}',
        ).replace(queryParameters: <String, dynamic>{...commonQuery, 'page': '$page'});
        final http.Response listResp = await _http.get(listUri, headers: headers);
        if (listResp.statusCode != 200) {
          throw DeviceException(
            'Market category list failed (status ${listResp.statusCode})',
            code: 'store-list-failed',
          );
        }
        final dynamic listJson = jsonDecode(listResp.body);
        if (listJson is! Map) {
          throw DeviceException(
            'Unexpected market list format',
            code: 'store-list-invalid',
          );
        }
        final dynamic data = listJson['data'];
        if (data is! List || data.isEmpty) break;

        for (final Object? row in data) {
          if (row is! Map) continue;
          final Map<String, dynamic> map = Map<String, dynamic>.from(row);
          map['category_name'] = category.name;
          final dynamic size = map['size'];
          if (size is num && size == 0) continue;
          final StoreItem item = StoreMarketClient.itemFromListApi(
            row: map,
            entryType: entryType,
            deviceSource: variant.deviceSource,
            deviceId: deviceId,
          );
          if (item.appId <= 0) continue;
          final String key = '${item.appId}|${item.version}';
          if (!seenKeys.add(key)) continue;
          items.add(item);
          onItem?.call(item);
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
  ///
  /// [forCountry] overrides the client default [country] for this request.
  Future<Map<String, dynamic>> fetchItemDetail({
    required WatchVariant variant,
    required StoreEntryType entryType,
    required int appId,
    required String appToken,
    required String userId,
    required AppVersion zeppVersion,
    String? forCountry,
  }) async {
    final String marketCountry = forCountry ?? country;
    final Map<String, String> headers = _headers(
      variant: variant,
      entryType: entryType,
      appToken: appToken,
      zeppVersion: zeppVersion,
      forCountry: marketCountry,
    );
    final Uri uri =
        Uri.parse(
          '$baseUrl/market/devices/${variant.deviceSource}/'
          '${entryType.apiValue}/apps/$appId',
        ).replace(
          queryParameters: <String, dynamic>{
            'userid': userId,
            'user_country': marketCountry,
            'api_level': '$apiLevel',
          },
        );
    final http.Response resp = await _http.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw DeviceException(
        'Market detail failed (status ${resp.statusCode})',
        code: 'store-detail-failed',
      );
    }
    final dynamic json = jsonDecode(resp.body);
    if (json is! Map) {
      throw DeviceException(
        'Unexpected market detail format',
        code: 'store-detail-invalid',
      );
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(json);
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
    required String forCountry,
  }) {
    final String appName = entryType == StoreEntryType.lightapp ? 'com.huami.midong' : variant.appName;
    return <String, String>{
      'apptoken': appToken,
      'Country': forCountry,
      'appplatform': 'android_phone',
      'appname': appName,
      'hm-privacy-diagnostics': 'false',
      'cv': zeppVersion.cvToken,
      'user-agent': 'Zepp/${zeppVersion.displayName} (Pixel 4; Android 12; Density/2.75)',
    };
  }

  void close() {
    if (_ownsClient) _http.close();
  }

  /// Parses a categorized market list row (before detail fetch).
  static StoreItem itemFromListApi({
    required Map<String, dynamic> row,
    required StoreEntryType entryType,
    required int deviceSource,
    String deviceId = '',
  }) {
    int? asInt(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    String asString(Object? v) {
      if (v == null) return '';
      return v.toString().trim();
    }

    String version = asString(row['device_support_version']);
    if (version.isEmpty) version = asString(row['version']);
    if (version.isEmpty) version = '1.0.0';

    final dynamic updatedRaw = row['updated_at'];
    DateTime? updatedAt;
    if (updatedRaw is num && updatedRaw != 0) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(
        (updatedRaw * 1000).toInt(),
        isUtc: true,
      );
    }

    return StoreItem(
      appId: asInt(row['id']) ?? 0,
      entryType: entryType,
      deviceId: deviceId,
      deviceSource: deviceSource,
      version: version,
      name: asString(row['name']),
      brief: asString(row['brief_description']),
      iconUrl: asString(row['image']),
      downloadSize: asInt(row['size']),
      categoryName: asString(row['category_name']),
      isFree: row['is_free'] == true || row['is_free'] == 1,
      updatedAt: updatedAt,
    );
  }

  /// Merges Amazfit detail fields into a list row (download URL, publisher, …).
  static StoreItem mergeDetail(StoreItem item, Map<String, dynamic> detail) {
    String asString(Object? v) {
      if (v == null) return '';
      return v.toString().trim();
    }

    int? asInt(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final dynamic metas = detail['metas'];
    int? builtin;
    if (metas is Map) {
      builtin = asInt(metas['builtin_id']);
    }
    if (builtin != null && builtin >= (1 << 31) - 1) {
      builtin = item.appId;
    }
    builtin ??= item.appId;

    String minZepp = item.minZeppVersion;
    final dynamic configRaw = detail['config'];
    if (configRaw is String && configRaw.isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(configRaw);
        if (decoded is Map) {
          final dynamic runtime = decoded['runtime'];
          if (runtime is Map) {
            final dynamic apiVersion = runtime['apiVersion'];
            if (apiVersion is Map) {
              final String min = asString(apiVersion['minVersion']);
              if (min.isNotEmpty) minZepp = min;
            }
          }
        }
      } on Exception catch (_) {}
    }

    final dynamic publisher = detail['publisher'];
    String pubName = item.publisherName;
    int? pubId = item.publisherId;
    if (publisher is Map) {
      final String name = asString(publisher['name']);
      if (name.isNotEmpty) pubName = name;
      pubId = asInt(publisher['id']) ?? pubId;
    }

    final String detailName = asString(detail['name']);
    final String detailImage = asString(detail['image']);
    final String desc = asString(detail['description']);
    final String change = asString(detail['new_description']);
    final String url = asString(detail['download_url']);
    final List<String> screenshots = previewPicUrls(detail['preview_pic']);

    final dynamic updatedRaw = detail['updated_at'];
    DateTime? updatedAt = item.updatedAt;
    if (updatedRaw is num && updatedRaw != 0) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(
        (updatedRaw * 1000).toInt(),
        isUtc: true,
      );
    }

    return item.copyWith(
      description: desc.isNotEmpty ? desc : item.description,
      changelog: change.isNotEmpty ? change : item.changelog,
      downloadUrl: url.isNotEmpty ? url : item.downloadUrl,
      downloadSize: asInt(detail['size']) ?? item.downloadSize,
      builtinId: builtin,
      publisherName: pubName,
      publisherId: pubId,
      minZeppVersion: minZepp,
      name: detailName.isNotEmpty ? detailName : item.name,
      iconUrl: detailImage.isNotEmpty ? detailImage : item.iconUrl,
      screenshotUrls: screenshots,
      updatedAt: updatedAt,
    );
  }

  /// Parses Amazfit detail `preview_pic` into a de-duplicated URL list.
  static List<String> previewPicUrls(Object? raw) {
    if (raw is! List) return const <String>[];
    final LinkedHashSet<String> urls = LinkedHashSet<String>();
    for (final Object? entry in raw) {
      if (entry == null) continue;
      final String url = entry.toString().trim();
      if (url.isNotEmpty) urls.add(url);
    }
    return List<String>.unmodifiable(urls);
  }

  /// Parses Amazfit entry-type path segments (`lightapp` / `watch`).
  static StoreEntryType entryTypeFromApi(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'watch':
        return StoreEntryType.watch;
      case 'lightapp':
      default:
        return StoreEntryType.lightapp;
    }
  }
}
