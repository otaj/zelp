import '../domain/output/existing_download.dart';
import '../domain/primitives/device_id.dart';
import '../domain/primitives/device_source.dart';
import '../domain/primitives/firmware_version.dart';

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
  }) : id = DeviceId(deviceId);

  final DeviceId id;
  final String name;
  final String osVersion;
  final List<WatchVariant> variants;

  String get deviceId => id.value;

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
    this.raw = const {},
  }) : version = FirmwareVersion(firmwareVersion);

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
  final Map<String, dynamic> raw;

  String get firmwareVersion => version.value;

  bool get hasFirmware => firmwareUrl != null && firmwareUrl!.isNotEmpty;

  /// Non-empty changelog / release notes from the API, or null.
  String? get readmeOrChangelog {
    final text = changeLog?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  /// Parsed firmware file checksum only when the API provided one.
  FileChecksum? get firmwareChecksum => FileChecksum.tryParseMd5(firmwareMd5);

  factory FirmwareInfo.fromApi(Map<String, dynamic> data) {
    String? asString(Object? value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    int? asInt(Object? value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
      return null;
    }

    return FirmwareInfo(
      firmwareVersion: asString(data['firmwareVersion']) ?? 'unknown',
      firmwareUrl: asString(data['firmwareUrl']),
      firmwareMd5: asString(data['firmwareMd5']),
      firmwareSize: asInt(data['firmwareSize']),
      changeLog: asString(data['changeLog']) ?? asString(data['readme']),
      gpsVersion: asString(data['gpsVersion']),
      gpsUrl: asString(data['gpsUrl']),
      gpsMd5: asString(data['gpsMd5']),
      fontVersion: asString(data['fontVersion']),
      fontUrl: asString(data['fontUrl']),
      fontMd5: asString(data['fontMd5']),
      resourceVersion: asString(data['resourceVersion']),
      resourceUrl: asString(data['resourceUrl']),
      resourceMd5: asString(data['resourceMd5']),
      raw: Map<String, dynamic>.from(data),
    );
  }

  factory FirmwareInfo.fromJson(Map<String, dynamic> json) {
    return FirmwareInfo.fromApi(json);
  }

  Map<String, dynamic> toJson() {
    if (raw.isNotEmpty) return Map<String, dynamic>.from(raw);
    return {
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

  factory StoredFirmwareHistory.fromJson(Map<String, dynamic> json) {
    final rawVersions = json['versions'] as List<dynamic>? ?? [];
    return StoredFirmwareHistory(
      deviceId: json['deviceId'] as String? ?? 'unknown',
      watchName: json['watchName'] as String? ?? '',
      deviceSource: (json['deviceSource'] as num?)?.toInt(),
      versions: rawVersions
          .whereType<Map>()
          .map((e) => FirmwareInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      checkedAt: DateTime.tryParse(json['checkedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'watchName': watchName,
    if (deviceSource != null) 'deviceSource': deviceSource,
    'checkedAt': (checkedAt ?? DateTime.now()).toIso8601String(),
    'versions': versions.map((v) => v.toJson()).toList(),
  };

  StoredFirmwareHistory copyWithMerged(List<FirmwareInfo> discovered) {
    final known = {for (final v in versions) v.firmwareVersion};
    final merged = List<FirmwareInfo>.from(versions);
    for (final v in discovered) {
      final index = merged.indexWhere(
        (e) => e.firmwareVersion == v.firmwareVersion,
      );
      if (index >= 0) {
        merged[index] = v;
      } else if (!known.contains(v.firmwareVersion)) {
        merged.add(v);
        known.add(v.firmwareVersion);
      }
    }
    return StoredFirmwareHistory(
      deviceId: deviceId,
      watchName: watchName,
      deviceSource: deviceSource,
      versions: merged,
      checkedAt: DateTime.now(),
    );
  }
}
