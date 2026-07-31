import 'package:zelp/domain/output/download_filename.dart';

/// Market entry type — matches explorer / Amazfit `lightapp` vs `watch`.
enum StoreEntryType {
  lightapp,
  watch;

  /// Wire value used by the Amazfit market API and local cache.
  String get apiValue => name;

  String get label => switch (this) {
    StoreEntryType.lightapp => 'Apps',
    StoreEntryType.watch => 'Watchfaces',
  };

  String get singular => switch (this) {
    StoreEntryType.lightapp => 'app',
    StoreEntryType.watch => 'watchface',
  };
}

/// Cached market catalog entry (app or watchface for one watch model).
///
/// [deviceId] is the user-facing cache key. [deviceSource] is retained for
/// market download calls (canonical source used when the list was refreshed).
///
/// SQLite / Amazfit JSON mapping lives in the services layer, not here.
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
    final String seen = starSeenVersion.trim();
    if (seen.isEmpty) return false;
    return seen != version;
  }

  /// Non-empty description/changelog text for the collapsed detail section.
  String get expandableBody {
    final List<String> parts = <String>[
      if (description.trim().isNotEmpty) description.trim(),
      if (changelog.trim().isNotEmpty) changelog.trim(),
    ];
    return parts.join('\n\n');
  }

  /// Suggested local file name from the download URL, else a stable fallback.
  ///
  /// When [semantic] is true, uses `{name}_{version}` instead of the CDN basename.
  String suggestedFileName({bool semantic = false}) => DownloadFilename.forStoreItem(
    name: name,
    version: version,
    downloadUrl: downloadUrl,
    appId: appId,
    kindSingular: entryType.singular,
    semantic: semantic,
  );

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
  }) => StoreItem(
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
