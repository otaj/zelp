import 'dart:convert';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;

import '../domain/primitives/app_version.dart';
import '../models/watch_model.dart';
import 'package:zelp/domain/exceptions.dart';
import 'zepp_version_client.dart';

/// Port of explorer's `fetch_firmware` against `api.amazfit.com`.
///
/// Does not require a Zepp login — same as zeppexplorer/fetch/api.py.
/// Returns version metadata and download links only (no file downloads).
///
/// Amazfit gates newer watch firmware behind newer Zepp app versions
/// (`appVersion` / `cv`). Before checking, [checkUpdates] resolves the latest
/// Play build via [ZeppVersionClient] (APKMirror scrape, as in explorer).
class FirmwareClient {
  FirmwareClient({
    this.baseUrl = 'https://api.amazfit.com',
    ZeppVersionClient? zeppVersionClient,
    String? zeppVersion,
  }) : _zeppVersionClient = zeppVersionClient ?? ZeppVersionClient(),
       _overrideZeppVersion = zeppVersion;

  final String baseUrl;
  final ZeppVersionClient _zeppVersionClient;
  final String? _overrideZeppVersion;

  String? _resolvedZeppVersion;

  /// Last resolved Zepp Play version used for requests.
  String? get zeppVersion => _resolvedZeppVersion ?? _overrideZeppVersion;

  String get _effectiveZeppVersion =>
      zeppVersion ?? _zeppVersionClient.fallbackVersion;

  AppVersion get _appVersion => AppVersion(_effectiveZeppVersion);

  String get _zeppVersionDisplay => _appVersion.displayName;

  String get _zeppVersionIv => _appVersion.cvToken;

  String get _userAgent =>
      'Zepp/$_zeppVersionDisplay (2203129G; Android 15; Density/2.75)';

  Future<String> _localTimezone() async {
    final info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  }

  /// Loads cached/fallback Zepp version (no network).
  Future<String> loadCachedZeppVersion() async {
    final override = _overrideZeppVersion;
    if (override != null) {
      _resolvedZeppVersion = override;
      return override;
    }
    final version = await _zeppVersionClient.current();
    _resolvedZeppVersion = version;
    return version;
  }

  /// User-initiated APKMirror scrape; updates cache.
  Future<String> refreshZeppVersion() async {
    final override = _overrideZeppVersion;
    if (override != null) {
      _resolvedZeppVersion = override;
      return override;
    }
    final version = await _zeppVersionClient.refreshFromApkMirror();
    _resolvedZeppVersion = version;
    return version;
  }

  /// Walks `/devices/ALL/hasNewVersion` for [variant] starting from [fromVersion].
  Future<List<FirmwareInfo>> checkUpdates({
    required WatchVariant variant,
    String fromVersion = '0',
  }) async {
    await loadCachedZeppVersion();
    final timezone = await _localTimezone();
    return _checkVariant(
      variant: variant,
      fromVersion: fromVersion,
      timezone: timezone,
    );
  }

  Future<List<FirmwareInfo>> _checkVariant({
    required WatchVariant variant,
    required String fromVersion,
    required String timezone,
  }) async {
    final found = <FirmwareInfo>[];
    var fw = fromVersion;
    final appVersion = _effectiveZeppVersion;

    while (true) {
      final uri = Uri.parse('$baseUrl/devices/ALL/hasNewVersion').replace(
        queryParameters: {
          'channel': 'play',
          'country': 'US',
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
          'lang': 'en_US',
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

      final response = await http.get(
        uri,
        headers: {
          'appname': variant.appName,
          'appplatform': 'android_phone',
          'channel': 'play',
          'country': 'US',
          'hm-privacy-ceip': 'false',
          'hm-privacy-diagnostics': 'false',
          'lang': 'en_US',
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

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw DeviceException(
          'Unexpected firmware response format',
          code: 'firmware-invalid',
        );
      }

      if (!decoded.containsKey('firmwareVersion')) {
        break;
      }

      final info = FirmwareInfo.fromApi(decoded);
      found.add(info);
      fw = info.firmwareVersion;
    }

    return found;
  }
}
