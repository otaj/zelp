import 'dart:convert';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/domain/store/market_countries.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/zepp_version_client.dart';

/// Port of explorer's `fetch_firmware` against `api.amazfit.com`.
///
/// Does not require a Zepp login — same as zeppexplorer/fetch/api.py.
/// Returns version metadata and download links only (no file downloads).
///
/// Amazfit gates newer watch firmware behind newer Zepp app versions
/// (`appVersion` / `cv`). Before checking, [checkUpdates] resolves the latest
/// Play build via [ZeppVersionClient] (APKMirror scrape, as in explorer).
///
/// Firmware rollouts can be region-gated, so [checkUpdates] queries each
/// country in [countries] (default [kDefaultMarketCountries]) and merges
/// the OTA chains.
class FirmwareClient {
  FirmwareClient({
    this.baseUrl = 'https://api.amazfit.com',
    ZeppVersionClient? zeppVersionClient,
    String? zeppVersion,
    http.Client? httpClient,
    List<String>? countries,
  }) : _zeppVersionClient = zeppVersionClient ?? ZeppVersionClient(),
       _overrideZeppVersion = zeppVersion,
       _http = httpClient ?? http.Client(),
       _ownsClient = httpClient == null,
       countries = List<String>.unmodifiable(
         countries ?? kDefaultMarketCountries,
       );

  final String baseUrl;
  final ZeppVersionClient _zeppVersionClient;
  final String? _overrideZeppVersion;
  final http.Client _http;
  final bool _ownsClient;

  /// Amazfit `country` values queried on each check (e.g. `RU`, `CN`, `PL`, `US`).
  final List<String> countries;

  String? _resolvedZeppVersion;

  /// Last resolved Zepp Play version used for requests.
  String? get zeppVersion => _resolvedZeppVersion ?? _overrideZeppVersion;

  String get _effectiveZeppVersion => zeppVersion ?? _zeppVersionClient.fallbackVersion;

  AppVersion get _appVersion => AppVersion(_effectiveZeppVersion);

  String get _zeppVersionDisplay => _appVersion.displayName;

  String get _zeppVersionIv => _appVersion.cvToken;

  String get _userAgent => 'Zepp/$_zeppVersionDisplay (2203129G; Android 15; Density/2.75)';

  Future<String> _localTimezone() async {
    final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  }

  /// Loads cached/fallback Zepp version (no network).
  Future<String> loadCachedZeppVersion() async {
    final String? override = _overrideZeppVersion;
    if (override != null) {
      _resolvedZeppVersion = override;
      return override;
    }
    final String version = await _zeppVersionClient.current();
    _resolvedZeppVersion = version;
    return version;
  }

  /// User-initiated APKMirror scrape; updates cache.
  Future<String> refreshZeppVersion() async {
    final String? override = _overrideZeppVersion;
    if (override != null) {
      _resolvedZeppVersion = override;
      return override;
    }
    final String version = await _zeppVersionClient.refreshFromApkMirror();
    _resolvedZeppVersion = version;
    return version;
  }

  /// Walks `/devices/ALL/hasNewVersion` for [variant] starting from [fromVersion].
  ///
  /// Queries every entry in [countries], merges unique firmware versions, and
  /// succeeds if at least one region returns data (or all return an empty
  /// chain). [timezone] overrides the device timezone (useful in tests).
  Future<List<FirmwareInfo>> checkUpdates({
    required WatchVariant variant,
    String fromVersion = '0',
    String? timezone,
  }) async {
    await loadCachedZeppVersion();
    final String tz = timezone ?? await _localTimezone();
    final Map<String, FirmwareInfo> byVersion = <String, FirmwareInfo>{};
    final List<String> order = <String>[];
    DeviceException? lastError;
    int countriesOk = 0;

    for (final String country in countries) {
      try {
        final List<FirmwareInfo> chain = await _checkVariant(
          variant: variant,
          fromVersion: fromVersion,
          timezone: tz,
          country: country,
        );
        countriesOk++;
        for (final FirmwareInfo info in chain) {
          final FirmwareInfo? existing = byVersion[info.firmwareVersion];
          if (existing == null) {
            order.add(info.firmwareVersion);
            byVersion[info.firmwareVersion] = info;
          } else if (existing.firmwareUrl == null && info.firmwareUrl != null) {
            byVersion[info.firmwareVersion] = info;
          }
        }
      } on DeviceException catch (e) {
        lastError = e;
      }
    }

    if (countriesOk == 0) {
      throw lastError ??
          DeviceException(
            'Firmware check failed for all regions',
            code: 'firmware-check-failed',
          );
    }

    return <FirmwareInfo>[
      for (final String version in order) byVersion[version]!,
    ];
  }

  Future<List<FirmwareInfo>> _checkVariant({
    required WatchVariant variant,
    required String fromVersion,
    required String timezone,
    required String country,
  }) async {
    final List<FirmwareInfo> found = <FirmwareInfo>[];
    String fw = fromVersion;
    final String appVersion = _effectiveZeppVersion;
    final String lang = langForMarketCountry(country);

    while (true) {
      final Uri uri = Uri.parse('$baseUrl/devices/ALL/hasNewVersion').replace(
        queryParameters: <String, dynamic>{
          'channel': 'play',
          'country': country,
          'device': 'android_35',
          'deviceType': 'ALL',
          'device_type': 'android_phone',
          'diagnosticCode': '1',
          'firmwareFlag': '-1',
          'firmwareVersion': fw,
          'fontFlag': '0',
          'fontVersion': '0',
          'gpsVersion': '0',
          'hardwareVersion': '0',
          'lang': lang,
          'productId': '0',
          'resourceFlag': '-1',
          'resourceVersion': '-1',
          'support8Bytes': 'true',
          'timezone': timezone,
          'v': '2.0',
          'vendorSource': '1',
          'appVersion': appVersion,
          'cv': _zeppVersionIv,
          'deviceSource': variant.deviceSource.toString(),
          'productionSource': variant.productionId.toString(),
        },
      );

      final http.Response response = await _http.get(
        uri,
        headers: <String, String>{
          'appname': variant.appName,
          'appplatform': 'android_phone',
          'channel': 'play',
          'country': country,
          'hm-privacy-ceip': 'false',
          'hm-privacy-diagnostics': 'false',
          'lang': lang,
          'timezone': timezone,
          'v': '2.0',
          'vn': _zeppVersionDisplay,
          'cv': _zeppVersionIv,
          'user-agent': _userAgent,
        },
      );

      if (response.statusCode != 200) {
        throw DeviceException(
          'Firmware check failed with status ${response.statusCode}',
          code: 'firmware-check-failed',
        );
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw DeviceException(
          'Unexpected firmware response format',
          code: 'firmware-invalid',
        );
      }

      if (!decoded.containsKey('firmwareVersion')) {
        break;
      }

      final FirmwareInfo info = FirmwareInfo.fromApi(decoded);
      found.add(info);
      fw = info.firmwareVersion;
    }

    return found;
  }

  void close() {
    if (_ownsClient) _http.close();
  }
}
