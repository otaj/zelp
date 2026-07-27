import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/watch_model.dart';
import 'exceptions.dart';

/// Device catalog from melianmiko/ZeppOS-DevicesList (same source as explorer).
const devicesListUrl =
    'https://raw.githubusercontent.com/melianmiko/ZeppOS-DevicesList/refs/heads/main/zepp_devices.json';

class DeviceCatalog {
  DeviceCatalog({http.Client? httpClient, List<WatchModel>? seed})
    : _http = httpClient ?? http.Client(),
      _ownsClient = httpClient == null,
      _cache = seed;

  final http.Client _http;
  final bool _ownsClient;
  List<WatchModel>? _cache;

  Future<List<WatchModel>> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    final response = await _http.get(Uri.parse(devicesListUrl));
    if (response.statusCode != 200) {
      throw DeviceException(
        'Failed to load device list (status ${response.statusCode})',
        code: 'device-list-failed',
      );
    }

    final watches = parseDeviceListJson(response.body);
    _cache = watches;
    return watches;
  }

  /// Parses ZeppOS-DevicesList JSON into sorted [WatchModel]s (no network).
  static List<WatchModel> parseDeviceListJson(String body) {
    final raw = jsonDecode(body);
    if (raw is! List) {
      throw DeviceException(
        'Unexpected device list format',
        code: 'device-list-invalid',
      );
    }

    final watches = <WatchModel>[];
    for (final entry in raw) {
      Map<String, dynamic>? map;
      if (entry is Map<String, dynamic>) {
        map = entry;
      } else if (entry is Map) {
        map = Map<String, dynamic>.from(entry);
      }
      if (map == null) continue;

      final sources = map['deviceSource'];
      final productionIds = map['productionId'];
      if (sources is! List || productionIds is! List) continue;
      if (sources.length != productionIds.length) continue;

      final deviceId = map['id'] as String? ?? '';
      if (deviceId.isEmpty) continue;
      final name = (map['deviceName'] as String?)?.trim().isNotEmpty == true
          ? (map['deviceName'] as String).trim()
          : ((map['shortDeviceName'] as String?)?.trim().isNotEmpty == true
                ? (map['shortDeviceName'] as String).trim()
                : deviceId);
      final osVersion = map['osVersion'] as String? ?? '';
      final application = map['application'] as String? ?? 'com.huami.midong';

      final variants = <WatchVariant>[];
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        final productionId = productionIds[i];
        if (source is! num || productionId is! num) continue;
        variants.add(
          WatchVariant(
            deviceSource: source.toInt(),
            productionId: productionId.toInt(),
            appName: application,
          ),
        );
      }
      if (variants.isEmpty) continue;

      watches.add(
        WatchModel(
          deviceId: deviceId,
          name: name,
          osVersion: osVersion,
          variants: variants,
        ),
      );
    }

    watches.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return watches;
  }

  void close() {
    if (_ownsClient) _http.close();
  }
}
