import 'dart:convert';

/// Market entry type — matches explorer / Amazfit `lightapp` vs `watch`.
enum StoreEntryType {
  lightapp,
  watch;

  String get apiValue => name;

  String get label => switch (this) {
    StoreEntryType.lightapp => 'Apps',
    StoreEntryType.watch => 'Watchfaces',
  };

  String get singular => switch (this) {
    StoreEntryType.lightapp => 'app',
    StoreEntryType.watch => 'watchface',
  };

  static StoreEntryType fromApi(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'watch':
        return StoreEntryType.watch;
      case 'lightapp':
      default:
        return StoreEntryType.lightapp;
    }
  }
}

/// Cached market catalog row (app or watchface for one watch model).
///
/// [deviceId] is the user-facing cache key. [deviceSource] is retained for
/// market download calls (canonical source used when the list was refreshed).
class StoreItem {
  const StoreItem({
    required this.appId,
    required this.entryType,
    required this.deviceSource,
    required this.version,
    required this.name,
    this.deviceId = '',
    this.brief = '',
    this.description = '',
    this.changelog = '',
    this.iconUrl = '',
    this.downloadUrl = '',
    this.downloadSize,
    this.publisherName = '',
    this.publisherId,
    this.categoryName = '',
    this.categoryId,
    this.builtinId,
    this.isFree = true,
    this.isRemoved = false,
    this.isStarred = false,
    this.starSeenVersion = '',
    this.minZeppVersion = '',
    this.updatedAt,
    this.refreshedAt,
  });

  final int appId;
  final StoreEntryType entryType;
  final String deviceId;
  final int deviceSource;
  final String version;
  final String name;
  final String brief;
  final String description;
  final String changelog;
  final String iconUrl;
  final String downloadUrl;
  final int? downloadSize;
  final String publisherName;
  final int? publisherId;
  final String categoryName;
  final int? categoryId;
  final int? builtinId;
  final bool isFree;
  final bool isRemoved;
  final bool isStarred;

  /// Version the user last acknowledged while starred (for “Updated” badges).
  final String starSeenVersion;
  final String minZeppVersion;
  final DateTime? updatedAt;
  final DateTime? refreshedAt;

  bool get hasDownload => downloadUrl.trim().isNotEmpty;

  bool get canDownload => isFree && hasDownload && !isRemoved;

  bool get hasStarredUpdate {
    if (!isStarred) return false;
    final seen = starSeenVersion.trim();
    if (seen.isEmpty) return false;
    return seen != version;
  }

  /// Non-empty description/changelog text for the collapsed detail section.
  String get expandableBody {
    final parts = <String>[
      if (description.trim().isNotEmpty) description.trim(),
      if (changelog.trim().isNotEmpty) changelog.trim(),
    ];
    return parts.join('\n\n');
  }

  /// Suggested local file name from the download URL, else a stable fallback.
  String get suggestedFileName {
    final url = downloadUrl.trim();
    if (url.isNotEmpty) {
      final path = Uri.tryParse(url)?.path ?? '';
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final last = segments.last;
        if (last.contains('.')) return last;
      }
    }
    final kind = entryType == StoreEntryType.watch ? 'watchface' : 'app';
    final safeVer = version.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return '${kind}_${appId}_$safeVer.zip';
  }

  StoreItem copyWith({
    String? deviceId,
    int? deviceSource,
    String? brief,
    String? description,
    String? changelog,
    String? iconUrl,
    String? downloadUrl,
    int? downloadSize,
    String? publisherName,
    int? publisherId,
    String? categoryName,
    int? categoryId,
    int? builtinId,
    bool? isFree,
    bool? isRemoved,
    bool? isStarred,
    String? starSeenVersion,
    String? minZeppVersion,
    DateTime? updatedAt,
    DateTime? refreshedAt,
    String? name,
    String? version,
  }) {
    return StoreItem(
      appId: appId,
      entryType: entryType,
      deviceId: deviceId ?? this.deviceId,
      deviceSource: deviceSource ?? this.deviceSource,
      version: version ?? this.version,
      name: name ?? this.name,
      brief: brief ?? this.brief,
      description: description ?? this.description,
      changelog: changelog ?? this.changelog,
      iconUrl: iconUrl ?? this.iconUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      downloadSize: downloadSize ?? this.downloadSize,
      publisherName: publisherName ?? this.publisherName,
      publisherId: publisherId ?? this.publisherId,
      categoryName: categoryName ?? this.categoryName,
      categoryId: categoryId ?? this.categoryId,
      builtinId: builtinId ?? this.builtinId,
      isFree: isFree ?? this.isFree,
      isRemoved: isRemoved ?? this.isRemoved,
      isStarred: isStarred ?? this.isStarred,
      starSeenVersion: starSeenVersion ?? this.starSeenVersion,
      minZeppVersion: minZeppVersion ?? this.minZeppVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      refreshedAt: refreshedAt ?? this.refreshedAt,
    );
  }

  Map<String, Object?> toRow() => {
    'app_id': appId,
    'entry_type': entryType.apiValue,
    'device_id': deviceId,
    'device_source': deviceSource,
    'version': version,
    'name': name,
    'brief': brief,
    'description': description,
    'changelog': changelog,
    'icon_url': iconUrl,
    'download_url': downloadUrl,
    'download_size': downloadSize,
    'publisher_name': publisherName,
    'publisher_id': publisherId,
    'category_name': categoryName,
    'category_id': categoryId,
    'builtin_id': builtinId,
    'is_free': isFree ? 1 : 0,
    'is_removed': isRemoved ? 1 : 0,
    'is_starred': isStarred ? 1 : 0,
    'star_seen_version': starSeenVersion,
    'min_zepp_version': minZeppVersion,
    'updated_at': updatedAt?.toIso8601String(),
    'refreshed_at': refreshedAt?.toIso8601String(),
  };

  factory StoreItem.fromRow(Map<String, Object?> row) {
    int? asInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    String asString(Object? v) => v?.toString() ?? '';

    return StoreItem(
      appId: asInt(row['app_id']) ?? 0,
      entryType: StoreEntryType.fromApi(asString(row['entry_type'])),
      deviceId: asString(row['device_id']),
      deviceSource: asInt(row['device_source']) ?? 0,
      version: asString(row['version']),
      name: asString(row['name']),
      brief: asString(row['brief']),
      description: asString(row['description']),
      changelog: asString(row['changelog']),
      iconUrl: asString(row['icon_url']),
      downloadUrl: asString(row['download_url']),
      downloadSize: asInt(row['download_size']),
      publisherName: asString(row['publisher_name']),
      publisherId: asInt(row['publisher_id']),
      categoryName: asString(row['category_name']),
      categoryId: asInt(row['category_id']),
      builtinId: asInt(row['builtin_id']),
      isFree: (asInt(row['is_free']) ?? 1) != 0,
      isRemoved: (asInt(row['is_removed']) ?? 0) != 0,
      isStarred: (asInt(row['is_starred']) ?? 0) != 0,
      starSeenVersion: asString(row['star_seen_version']),
      minZeppVersion: asString(row['min_zepp_version']),
      updatedAt: DateTime.tryParse(asString(row['updated_at'])),
      refreshedAt: DateTime.tryParse(asString(row['refreshed_at'])),
    );
  }

  /// Parses a categorized market list row (before detail fetch).
  factory StoreItem.fromListApi({
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

    var version = asString(row['device_support_version']);
    if (version.isEmpty) version = asString(row['version']);
    if (version.isEmpty) version = '1.0.0';

    final updatedRaw = row['updated_at'];
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

  /// Merges detail fields into a list row (download URL, publisher, …).
  StoreItem mergeDetail(Map<String, dynamic> detail) {
    String asString(Object? v) {
      if (v == null) return '';
      return v.toString().trim();
    }

    int? asInt(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final metas = detail['metas'];
    int? builtin;
    if (metas is Map) {
      builtin = asInt(metas['builtin_id']);
    }
    if (builtin != null && builtin >= (1 << 31) - 1) {
      builtin = appId;
    }
    builtin ??= appId;

    var minZepp = minZeppVersion;
    final configRaw = detail['config'];
    if (configRaw is String && configRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(configRaw);
        if (decoded is Map) {
          final runtime = decoded['runtime'];
          if (runtime is Map) {
            final apiVersion = runtime['apiVersion'];
            if (apiVersion is Map) {
              final min = asString(apiVersion['minVersion']);
              if (min.isNotEmpty) minZepp = min;
            }
          }
        }
      } catch (_) {}
    }

    final publisher = detail['publisher'];
    var pubName = publisherName;
    var pubId = publisherId;
    if (publisher is Map) {
      final name = asString(publisher['name']);
      if (name.isNotEmpty) pubName = name;
      pubId = asInt(publisher['id']) ?? pubId;
    }

    final detailName = asString(detail['name']);
    final detailImage = asString(detail['image']);
    final desc = asString(detail['description']);
    final change = asString(detail['new_description']);
    final url = asString(detail['download_url']);

    return copyWith(
      description: desc.isNotEmpty ? desc : description,
      changelog: change.isNotEmpty ? change : changelog,
      downloadUrl: url.isNotEmpty ? url : downloadUrl,
      downloadSize: asInt(detail['size']) ?? downloadSize,
      builtinId: builtin,
      publisherName: pubName,
      publisherId: pubId,
      minZeppVersion: minZepp,
      name: detailName.isNotEmpty ? detailName : name,
      iconUrl: detailImage.isNotEmpty ? detailImage : iconUrl,
    );
  }
}
