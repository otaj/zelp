import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/primitives/device_id.dart';
import 'package:zelp/domain/primitives/device_source.dart';
import 'package:zelp/domain/primitives/firmware_version.dart';
import 'package:zelp/domain/primitives/json_values.dart';
import 'package:zelp/domain/store/market_api_level.dart';

class WatchVariant {
  WatchVariant({
    required int deviceSource,
    required this.productionId,
    required this.appName,
  }) : source = DeviceSource(deviceSource);

  final DeviceSource source;
  final int productionId;
  final String appName;

  int get deviceSource => source.value;

  /// Label shown when a watch has multiple firmware device sources.
  ///
  /// Options are distinguished by Amazfit [deviceSource], not production id.
  String get label => 'Device source $deviceSource';
}

/// A selectable Amazfit watch model, identified by its human-readable name.
class WatchModel {
  WatchModel({
    required String deviceId,
    required this.name,
    required this.osVersion,
    required this.variants,
    this.apiVersion = '',
  }) : id = DeviceId(deviceId);

  final DeviceId id;
  final String name;
  final String osVersion;

  /// Device [API_LEVEL](https://docs.zepp.com/docs/guides/framework/device/compatibility/)
  /// from the ZeppOS-DevicesList `apiVersion` field (e.g. `3.6.0`).
  ///
  /// Empty when the catalog omit it; [marketApiLevel] then falls back to
  /// [osVersion].
  final String apiVersion;
  final List<WatchVariant> variants;

  String get deviceId => id.value;

  /// Amazfit market `api_level` query value for Apps / Watchfaces fetches.
  int get marketApiLevel => marketApiLevelFromVersion(
    apiVersion.isNotEmpty ? apiVersion : osVersion,
  );

  /// Canonical market/firmware variant for this model (first catalog entry).
  ///
  /// Store browse/refresh is keyed by [deviceId]; Amazfit market calls still
  /// need a deviceSource under the hood — we always use this variant.
  WatchVariant get canonicalVariant => variants.first;
}

class FirmwareInfo {
  FirmwareInfo({
    required String firmwareVersion,
    this.firmwareUrl,
    this.firmwareMd5,
    this.firmwareSize,
    this.changeLog,
    this.gpsVersion,
    this.gpsUrl,
    this.gpsMd5,
    this.fontVersion,
    this.fontUrl,
    this.fontMd5,
    this.resourceVersion,
    this.resourceUrl,
    this.resourceMd5,
    this.releasedAt,
    this.raw = const <String, dynamic>{},
  }) : version = FirmwareVersion(firmwareVersion);

  factory FirmwareInfo.fromApi(Map<String, dynamic> data) => FirmwareInfo(
    firmwareVersion: jsonAsStringOrNull(data['firmwareVersion']) ?? 'unknown',
    firmwareUrl: jsonAsStringOrNull(data['firmwareUrl']),
    firmwareMd5: jsonAsStringOrNull(data['firmwareMd5']),
    firmwareSize: jsonAsInt(data['firmwareSize']),
    changeLog: jsonAsStringOrNull(data['changeLog']) ?? jsonAsStringOrNull(data['readme']),
    gpsVersion: jsonAsStringOrNull(data['gpsVersion']),
    gpsUrl: jsonAsStringOrNull(data['gpsUrl']),
    gpsMd5: jsonAsStringOrNull(data['gpsMd5']),
    fontVersion: jsonAsStringOrNull(data['fontVersion']),
    fontUrl: jsonAsStringOrNull(data['fontUrl']),
    fontMd5: jsonAsStringOrNull(data['fontMd5']),
    resourceVersion: jsonAsStringOrNull(data['resourceVersion']),
    resourceUrl: jsonAsStringOrNull(data['resourceUrl']),
    resourceMd5: jsonAsStringOrNull(data['resourceMd5']),
    releasedAt: DateTime.tryParse(jsonAsStringOrNull(data['releasedAt']) ?? ''),
    raw: Map<String, dynamic>.from(data),
  );

  factory FirmwareInfo.fromJson(Map<String, dynamic> json) => FirmwareInfo.fromApi(json);

  /// Explorer `/api/v1/device/firmwares/{source}` firmware row (camelCase JSON).
  factory FirmwareInfo.fromExplorer(Map<String, dynamic> json) => FirmwareInfo(
    firmwareVersion: jsonAsStringOrNull(json['version']) ?? 'unknown',
    firmwareUrl: jsonAsStringOrNull(json['downloadUrl']),
    changeLog: jsonAsStringOrNull(json['changelog']),
    releasedAt: DateTime.tryParse(jsonAsStringOrNull(json['releasedAt']) ?? ''),
  );

  final FirmwareVersion version;
  final String? firmwareUrl;

  /// API `firmwareMd5` when present (hex). Null if the API omitted it.
  final String? firmwareMd5;
  final int? firmwareSize;
  final String? changeLog;
  final String? gpsVersion;
  final String? gpsUrl;
  final String? gpsMd5;
  final String? fontVersion;
  final String? fontUrl;
  final String? fontMd5;
  final String? resourceVersion;
  final String? resourceUrl;
  final String? resourceMd5;
  final DateTime? releasedAt;
  final Map<String, dynamic> raw;

  String get firmwareVersion => version.value;

  bool get hasFirmware => firmwareUrl != null && firmwareUrl!.isNotEmpty;

  /// Oldest-first: explorer [releasedAt] when known, otherwise version order.
  /// Rows without a date sort after dated ones (treated as newer / live).
  static int compareByReleaseTime(FirmwareInfo a, FirmwareInfo b) {
    final DateTime? at = a.releasedAt;
    final DateTime? bt = b.releasedAt;
    if (at != null && bt != null) {
      final int byDate = at.compareTo(bt);
      if (byDate != 0) return byDate;
    } else if (at != null) {
      return -1;
    } else if (bt != null) {
      return 1;
    }
    return a.version.compareTo(b.version);
  }

  /// Prefers [live] download metadata, keeping this row's [releasedAt] when
  /// Amazfit omitted it.
  FirmwareInfo overlayLive(FirmwareInfo live) => FirmwareInfo(
    firmwareVersion: live.firmwareVersion,
    firmwareUrl: live.firmwareUrl ?? firmwareUrl,
    firmwareMd5: live.firmwareMd5 ?? firmwareMd5,
    firmwareSize: live.firmwareSize ?? firmwareSize,
    changeLog: live.changeLog ?? changeLog,
    gpsVersion: live.gpsVersion ?? gpsVersion,
    gpsUrl: live.gpsUrl ?? gpsUrl,
    gpsMd5: live.gpsMd5 ?? gpsMd5,
    fontVersion: live.fontVersion ?? fontVersion,
    fontUrl: live.fontUrl ?? fontUrl,
    fontMd5: live.fontMd5 ?? fontMd5,
    resourceVersion: live.resourceVersion ?? resourceVersion,
    resourceUrl: live.resourceUrl ?? resourceUrl,
    resourceMd5: live.resourceMd5 ?? resourceMd5,
    releasedAt: live.releasedAt ?? releasedAt,
    raw: live.raw.isNotEmpty ? live.raw : raw,
  );

  /// Non-empty changelog / release notes from the API, or null.
  String? get readmeOrChangelog {
    final String? text = changeLog?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  /// Parsed firmware file checksum only when the API provided one.
  FileChecksum? get firmwareChecksum => FileChecksum.tryParseMd5(firmwareMd5);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = raw.isNotEmpty
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{
            'firmwareVersion': firmwareVersion,
            if (firmwareUrl != null) 'firmwareUrl': firmwareUrl,
            if (firmwareMd5 != null) 'firmwareMd5': firmwareMd5,
            if (firmwareSize != null) 'firmwareSize': firmwareSize,
            if (changeLog != null) 'changeLog': changeLog,
            if (gpsVersion != null) 'gpsVersion': gpsVersion,
            if (gpsUrl != null) 'gpsUrl': gpsUrl,
            if (gpsMd5 != null) 'gpsMd5': gpsMd5,
            if (fontVersion != null) 'fontVersion': fontVersion,
            if (fontUrl != null) 'fontUrl': fontUrl,
            if (fontMd5 != null) 'fontMd5': fontMd5,
            if (resourceVersion != null) 'resourceVersion': resourceVersion,
            if (resourceUrl != null) 'resourceUrl': resourceUrl,
            if (resourceMd5 != null) 'resourceMd5': resourceMd5,
          };
    if (releasedAt != null) {
      json['releasedAt'] = releasedAt!.toIso8601String();
    }
    return json;
  }
}

/// Persisted firmware history for one watch model + device source.
class StoredFirmwareHistory {
  StoredFirmwareHistory({
    required String deviceId,
    required this.watchName,
    required this.versions,
    int? deviceSource,
    this.checkedAt,
  }) : id = DeviceId(deviceId.isEmpty ? 'unknown' : deviceId),
       source = deviceSource == null ? null : DeviceSource(deviceSource);

  factory StoredFirmwareHistory.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawVersions = json['versions'] as List<dynamic>? ?? <dynamic>[];
    return StoredFirmwareHistory(
      deviceId: json['deviceId'] as String? ?? 'unknown',
      watchName: json['watchName'] as String? ?? '',
      deviceSource: (json['deviceSource'] as num?)?.toInt(),
      versions: rawVersions.whereType<Map<String, dynamic>>().map(FirmwareInfo.fromJson).toList(),
      checkedAt: DateTime.tryParse(json['checkedAt'] as String? ?? ''),
    );
  }

  final DeviceId id;
  final String watchName;
  final DeviceSource? source;
  final List<FirmwareInfo> versions;
  final DateTime? checkedAt;

  String get deviceId => id.value;

  int? get deviceSource => source?.value;

  FirmwareInfo? get latest => versions.isEmpty ? null : versions.last;

  String get latestVersion => latest?.firmwareVersion ?? '0';

  static String storageKey(String deviceId, int deviceSource) =>
      '${DeviceId(deviceId).value}:${DeviceSource(deviceSource).value}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'deviceId': deviceId,
    'watchName': watchName,
    if (deviceSource != null) 'deviceSource': deviceSource,
    'checkedAt': (checkedAt ?? DateTime.now()).toIso8601String(),
    'versions': versions.map((FirmwareInfo v) => v.toJson()).toList(),
  };

  StoredFirmwareHistory copyWithMerged(List<FirmwareInfo> discovered) {
    final Set<String> known = <String>{for (final FirmwareInfo v in versions) v.firmwareVersion};
    final List<FirmwareInfo> merged = List<FirmwareInfo>.from(versions);
    for (final FirmwareInfo v in discovered) {
      final int index = merged.indexWhere(
        (FirmwareInfo e) => e.firmwareVersion == v.firmwareVersion,
      );
      if (index >= 0) {
        merged[index] = v;
      } else if (!known.contains(v.firmwareVersion)) {
        merged.add(v);
        known.add(v.firmwareVersion);
      }
    }
    merged.sort(FirmwareInfo.compareByReleaseTime);
    return StoredFirmwareHistory(
      deviceId: deviceId,
      watchName: watchName,
      deviceSource: deviceSource,
      versions: merged,
      checkedAt: DateTime.now(),
    );
  }
}
