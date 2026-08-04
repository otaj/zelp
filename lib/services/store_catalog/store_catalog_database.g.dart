// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_catalog_database.dart';

// ignore_for_file: type=lint
class $StoreItemsTable extends StoreItems with TableInfo<$StoreItemsTable, StoreItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoreItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _appIdMeta = const VerificationMeta('appId');
  @override
  late final GeneratedColumn<int> appId = GeneratedColumn<int>(
    'app_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryTypeMeta = const VerificationMeta(
    'entryType',
  );
  @override
  late final GeneratedColumn<String> entryType = GeneratedColumn<String>(
    'entry_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceSourceMeta = const VerificationMeta(
    'deviceSource',
  );
  @override
  late final GeneratedColumn<int> deviceSource = GeneratedColumn<int>(
    'device_source',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _briefMeta = const VerificationMeta('brief');
  @override
  late final GeneratedColumn<String> brief = GeneratedColumn<String>(
    'brief',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _changelogMeta = const VerificationMeta(
    'changelog',
  );
  @override
  late final GeneratedColumn<String> changelog = GeneratedColumn<String>(
    'changelog',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _iconUrlMeta = const VerificationMeta(
    'iconUrl',
  );
  @override
  late final GeneratedColumn<String> iconUrl = GeneratedColumn<String>(
    'icon_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> screenshotUrls = GeneratedColumn<String>(
    'screenshot_urls',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  ).withConverter<List<String>>($StoreItemsTable.$converterscreenshotUrls);
  static const VerificationMeta _downloadUrlMeta = const VerificationMeta(
    'downloadUrl',
  );
  @override
  late final GeneratedColumn<String> downloadUrl = GeneratedColumn<String>(
    'download_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _downloadSizeMeta = const VerificationMeta(
    'downloadSize',
  );
  @override
  late final GeneratedColumn<int> downloadSize = GeneratedColumn<int>(
    'download_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publisherNameMeta = const VerificationMeta(
    'publisherName',
  );
  @override
  late final GeneratedColumn<String> publisherName = GeneratedColumn<String>(
    'publisher_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _publisherIdMeta = const VerificationMeta(
    'publisherId',
  );
  @override
  late final GeneratedColumn<int> publisherId = GeneratedColumn<int>(
    'publisher_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryNameMeta = const VerificationMeta(
    'categoryName',
  );
  @override
  late final GeneratedColumn<String> categoryName = GeneratedColumn<String>(
    'category_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _builtinIdMeta = const VerificationMeta(
    'builtinId',
  );
  @override
  late final GeneratedColumn<int> builtinId = GeneratedColumn<int>(
    'builtin_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFreeMeta = const VerificationMeta('isFree');
  @override
  late final GeneratedColumn<bool> isFree = GeneratedColumn<bool>(
    'is_free',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_free" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isRemovedMeta = const VerificationMeta(
    'isRemoved',
  );
  @override
  late final GeneratedColumn<bool> isRemoved = GeneratedColumn<bool>(
    'is_removed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_removed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isStarredMeta = const VerificationMeta(
    'isStarred',
  );
  @override
  late final GeneratedColumn<bool> isStarred = GeneratedColumn<bool>(
    'is_starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _starSeenVersionMeta = const VerificationMeta(
    'starSeenVersion',
  );
  @override
  late final GeneratedColumn<String> starSeenVersion = GeneratedColumn<String>(
    'star_seen_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _minZeppVersionMeta = const VerificationMeta(
    'minZeppVersion',
  );
  @override
  late final GeneratedColumn<String> minZeppVersion = GeneratedColumn<String>(
    'min_zepp_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refreshedAtMeta = const VerificationMeta(
    'refreshedAt',
  );
  @override
  late final GeneratedColumn<String> refreshedAt = GeneratedColumn<String>(
    'refreshed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    appId,
    entryType,
    deviceId,
    deviceSource,
    version,
    name,
    brief,
    description,
    changelog,
    iconUrl,
    screenshotUrls,
    downloadUrl,
    downloadSize,
    publisherName,
    publisherId,
    categoryName,
    categoryId,
    builtinId,
    isFree,
    isRemoved,
    isStarred,
    starSeenVersion,
    minZeppVersion,
    updatedAt,
    refreshedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'store_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoreItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('app_id')) {
      context.handle(
        _appIdMeta,
        appId.isAcceptableOrUnknown(data['app_id']!, _appIdMeta),
      );
    } else if (isInserting) {
      context.missing(_appIdMeta);
    }
    if (data.containsKey('entry_type')) {
      context.handle(
        _entryTypeMeta,
        entryType.isAcceptableOrUnknown(data['entry_type']!, _entryTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entryTypeMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('device_source')) {
      context.handle(
        _deviceSourceMeta,
        deviceSource.isAcceptableOrUnknown(
          data['device_source']!,
          _deviceSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deviceSourceMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('brief')) {
      context.handle(
        _briefMeta,
        brief.isAcceptableOrUnknown(data['brief']!, _briefMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('changelog')) {
      context.handle(
        _changelogMeta,
        changelog.isAcceptableOrUnknown(data['changelog']!, _changelogMeta),
      );
    }
    if (data.containsKey('icon_url')) {
      context.handle(
        _iconUrlMeta,
        iconUrl.isAcceptableOrUnknown(data['icon_url']!, _iconUrlMeta),
      );
    }
    if (data.containsKey('download_url')) {
      context.handle(
        _downloadUrlMeta,
        downloadUrl.isAcceptableOrUnknown(
          data['download_url']!,
          _downloadUrlMeta,
        ),
      );
    }
    if (data.containsKey('download_size')) {
      context.handle(
        _downloadSizeMeta,
        downloadSize.isAcceptableOrUnknown(
          data['download_size']!,
          _downloadSizeMeta,
        ),
      );
    }
    if (data.containsKey('publisher_name')) {
      context.handle(
        _publisherNameMeta,
        publisherName.isAcceptableOrUnknown(
          data['publisher_name']!,
          _publisherNameMeta,
        ),
      );
    }
    if (data.containsKey('publisher_id')) {
      context.handle(
        _publisherIdMeta,
        publisherId.isAcceptableOrUnknown(
          data['publisher_id']!,
          _publisherIdMeta,
        ),
      );
    }
    if (data.containsKey('category_name')) {
      context.handle(
        _categoryNameMeta,
        categoryName.isAcceptableOrUnknown(
          data['category_name']!,
          _categoryNameMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('builtin_id')) {
      context.handle(
        _builtinIdMeta,
        builtinId.isAcceptableOrUnknown(data['builtin_id']!, _builtinIdMeta),
      );
    }
    if (data.containsKey('is_free')) {
      context.handle(
        _isFreeMeta,
        isFree.isAcceptableOrUnknown(data['is_free']!, _isFreeMeta),
      );
    }
    if (data.containsKey('is_removed')) {
      context.handle(
        _isRemovedMeta,
        isRemoved.isAcceptableOrUnknown(data['is_removed']!, _isRemovedMeta),
      );
    }
    if (data.containsKey('is_starred')) {
      context.handle(
        _isStarredMeta,
        isStarred.isAcceptableOrUnknown(data['is_starred']!, _isStarredMeta),
      );
    }
    if (data.containsKey('star_seen_version')) {
      context.handle(
        _starSeenVersionMeta,
        starSeenVersion.isAcceptableOrUnknown(
          data['star_seen_version']!,
          _starSeenVersionMeta,
        ),
      );
    }
    if (data.containsKey('min_zepp_version')) {
      context.handle(
        _minZeppVersionMeta,
        minZeppVersion.isAcceptableOrUnknown(
          data['min_zepp_version']!,
          _minZeppVersionMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('refreshed_at')) {
      context.handle(
        _refreshedAtMeta,
        refreshedAt.isAcceptableOrUnknown(
          data['refreshed_at']!,
          _refreshedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {appId, entryType, deviceId, version};
  @override
  StoreItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoreItemRow(
      appId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}app_id'],
      )!,
      entryType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_type'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      deviceSource: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_source'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      brief: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brief'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      changelog: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changelog'],
      )!,
      iconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_url'],
      )!,
      screenshotUrls: $StoreItemsTable.$converterscreenshotUrls.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}screenshot_urls'],
        )!,
      ),
      downloadUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_url'],
      )!,
      downloadSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}download_size'],
      ),
      publisherName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher_name'],
      )!,
      publisherId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}publisher_id'],
      ),
      categoryName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_name'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      builtinId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}builtin_id'],
      ),
      isFree: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_free'],
      )!,
      isRemoved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_removed'],
      )!,
      isStarred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_starred'],
      )!,
      starSeenVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}star_seen_version'],
      )!,
      minZeppVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}min_zepp_version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      refreshedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refreshed_at'],
      ),
    );
  }

  @override
  $StoreItemsTable createAlias(String alias) {
    return $StoreItemsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterscreenshotUrls = const ScreenshotUrlsConverter();
}

class StoreItemRow extends DataClass implements Insertable<StoreItemRow> {
  final int appId;
  final String entryType;
  final String deviceId;
  final int deviceSource;
  final String version;
  final String name;
  final String brief;
  final String description;
  final String changelog;
  final String iconUrl;
  final List<String> screenshotUrls;
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
  final String starSeenVersion;
  final String minZeppVersion;

  /// ISO-8601 text (same as the previous sqflite schema).
  final String? updatedAt;
  final String? refreshedAt;
  const StoreItemRow({
    required this.appId,
    required this.entryType,
    required this.deviceId,
    required this.deviceSource,
    required this.version,
    required this.name,
    required this.brief,
    required this.description,
    required this.changelog,
    required this.iconUrl,
    required this.screenshotUrls,
    required this.downloadUrl,
    this.downloadSize,
    required this.publisherName,
    this.publisherId,
    required this.categoryName,
    this.categoryId,
    this.builtinId,
    required this.isFree,
    required this.isRemoved,
    required this.isStarred,
    required this.starSeenVersion,
    required this.minZeppVersion,
    this.updatedAt,
    this.refreshedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['app_id'] = Variable<int>(appId);
    map['entry_type'] = Variable<String>(entryType);
    map['device_id'] = Variable<String>(deviceId);
    map['device_source'] = Variable<int>(deviceSource);
    map['version'] = Variable<String>(version);
    map['name'] = Variable<String>(name);
    map['brief'] = Variable<String>(brief);
    map['description'] = Variable<String>(description);
    map['changelog'] = Variable<String>(changelog);
    map['icon_url'] = Variable<String>(iconUrl);
    {
      map['screenshot_urls'] = Variable<String>(
        $StoreItemsTable.$converterscreenshotUrls.toSql(screenshotUrls),
      );
    }
    map['download_url'] = Variable<String>(downloadUrl);
    if (!nullToAbsent || downloadSize != null) {
      map['download_size'] = Variable<int>(downloadSize);
    }
    map['publisher_name'] = Variable<String>(publisherName);
    if (!nullToAbsent || publisherId != null) {
      map['publisher_id'] = Variable<int>(publisherId);
    }
    map['category_name'] = Variable<String>(categoryName);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || builtinId != null) {
      map['builtin_id'] = Variable<int>(builtinId);
    }
    map['is_free'] = Variable<bool>(isFree);
    map['is_removed'] = Variable<bool>(isRemoved);
    map['is_starred'] = Variable<bool>(isStarred);
    map['star_seen_version'] = Variable<String>(starSeenVersion);
    map['min_zepp_version'] = Variable<String>(minZeppVersion);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || refreshedAt != null) {
      map['refreshed_at'] = Variable<String>(refreshedAt);
    }
    return map;
  }

  StoreItemsCompanion toCompanion(bool nullToAbsent) {
    return StoreItemsCompanion(
      appId: Value(appId),
      entryType: Value(entryType),
      deviceId: Value(deviceId),
      deviceSource: Value(deviceSource),
      version: Value(version),
      name: Value(name),
      brief: Value(brief),
      description: Value(description),
      changelog: Value(changelog),
      iconUrl: Value(iconUrl),
      screenshotUrls: Value(screenshotUrls),
      downloadUrl: Value(downloadUrl),
      downloadSize: downloadSize == null && nullToAbsent ? const Value.absent() : Value(downloadSize),
      publisherName: Value(publisherName),
      publisherId: publisherId == null && nullToAbsent ? const Value.absent() : Value(publisherId),
      categoryName: Value(categoryName),
      categoryId: categoryId == null && nullToAbsent ? const Value.absent() : Value(categoryId),
      builtinId: builtinId == null && nullToAbsent ? const Value.absent() : Value(builtinId),
      isFree: Value(isFree),
      isRemoved: Value(isRemoved),
      isStarred: Value(isStarred),
      starSeenVersion: Value(starSeenVersion),
      minZeppVersion: Value(minZeppVersion),
      updatedAt: updatedAt == null && nullToAbsent ? const Value.absent() : Value(updatedAt),
      refreshedAt: refreshedAt == null && nullToAbsent ? const Value.absent() : Value(refreshedAt),
    );
  }

  factory StoreItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoreItemRow(
      appId: serializer.fromJson<int>(json['appId']),
      entryType: serializer.fromJson<String>(json['entryType']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      deviceSource: serializer.fromJson<int>(json['deviceSource']),
      version: serializer.fromJson<String>(json['version']),
      name: serializer.fromJson<String>(json['name']),
      brief: serializer.fromJson<String>(json['brief']),
      description: serializer.fromJson<String>(json['description']),
      changelog: serializer.fromJson<String>(json['changelog']),
      iconUrl: serializer.fromJson<String>(json['iconUrl']),
      screenshotUrls: serializer.fromJson<List<String>>(json['screenshotUrls']),
      downloadUrl: serializer.fromJson<String>(json['downloadUrl']),
      downloadSize: serializer.fromJson<int?>(json['downloadSize']),
      publisherName: serializer.fromJson<String>(json['publisherName']),
      publisherId: serializer.fromJson<int?>(json['publisherId']),
      categoryName: serializer.fromJson<String>(json['categoryName']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      builtinId: serializer.fromJson<int?>(json['builtinId']),
      isFree: serializer.fromJson<bool>(json['isFree']),
      isRemoved: serializer.fromJson<bool>(json['isRemoved']),
      isStarred: serializer.fromJson<bool>(json['isStarred']),
      starSeenVersion: serializer.fromJson<String>(json['starSeenVersion']),
      minZeppVersion: serializer.fromJson<String>(json['minZeppVersion']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      refreshedAt: serializer.fromJson<String?>(json['refreshedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'appId': serializer.toJson<int>(appId),
      'entryType': serializer.toJson<String>(entryType),
      'deviceId': serializer.toJson<String>(deviceId),
      'deviceSource': serializer.toJson<int>(deviceSource),
      'version': serializer.toJson<String>(version),
      'name': serializer.toJson<String>(name),
      'brief': serializer.toJson<String>(brief),
      'description': serializer.toJson<String>(description),
      'changelog': serializer.toJson<String>(changelog),
      'iconUrl': serializer.toJson<String>(iconUrl),
      'screenshotUrls': serializer.toJson<List<String>>(screenshotUrls),
      'downloadUrl': serializer.toJson<String>(downloadUrl),
      'downloadSize': serializer.toJson<int?>(downloadSize),
      'publisherName': serializer.toJson<String>(publisherName),
      'publisherId': serializer.toJson<int?>(publisherId),
      'categoryName': serializer.toJson<String>(categoryName),
      'categoryId': serializer.toJson<int?>(categoryId),
      'builtinId': serializer.toJson<int?>(builtinId),
      'isFree': serializer.toJson<bool>(isFree),
      'isRemoved': serializer.toJson<bool>(isRemoved),
      'isStarred': serializer.toJson<bool>(isStarred),
      'starSeenVersion': serializer.toJson<String>(starSeenVersion),
      'minZeppVersion': serializer.toJson<String>(minZeppVersion),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'refreshedAt': serializer.toJson<String?>(refreshedAt),
    };
  }

  StoreItemRow copyWith({
    int? appId,
    String? entryType,
    String? deviceId,
    int? deviceSource,
    String? version,
    String? name,
    String? brief,
    String? description,
    String? changelog,
    String? iconUrl,
    List<String>? screenshotUrls,
    String? downloadUrl,
    Value<int?> downloadSize = const Value.absent(),
    String? publisherName,
    Value<int?> publisherId = const Value.absent(),
    String? categoryName,
    Value<int?> categoryId = const Value.absent(),
    Value<int?> builtinId = const Value.absent(),
    bool? isFree,
    bool? isRemoved,
    bool? isStarred,
    String? starSeenVersion,
    String? minZeppVersion,
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> refreshedAt = const Value.absent(),
  }) => StoreItemRow(
    appId: appId ?? this.appId,
    entryType: entryType ?? this.entryType,
    deviceId: deviceId ?? this.deviceId,
    deviceSource: deviceSource ?? this.deviceSource,
    version: version ?? this.version,
    name: name ?? this.name,
    brief: brief ?? this.brief,
    description: description ?? this.description,
    changelog: changelog ?? this.changelog,
    iconUrl: iconUrl ?? this.iconUrl,
    screenshotUrls: screenshotUrls ?? this.screenshotUrls,
    downloadUrl: downloadUrl ?? this.downloadUrl,
    downloadSize: downloadSize.present ? downloadSize.value : this.downloadSize,
    publisherName: publisherName ?? this.publisherName,
    publisherId: publisherId.present ? publisherId.value : this.publisherId,
    categoryName: categoryName ?? this.categoryName,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    builtinId: builtinId.present ? builtinId.value : this.builtinId,
    isFree: isFree ?? this.isFree,
    isRemoved: isRemoved ?? this.isRemoved,
    isStarred: isStarred ?? this.isStarred,
    starSeenVersion: starSeenVersion ?? this.starSeenVersion,
    minZeppVersion: minZeppVersion ?? this.minZeppVersion,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    refreshedAt: refreshedAt.present ? refreshedAt.value : this.refreshedAt,
  );
  StoreItemRow copyWithCompanion(StoreItemsCompanion data) {
    return StoreItemRow(
      appId: data.appId.present ? data.appId.value : this.appId,
      entryType: data.entryType.present ? data.entryType.value : this.entryType,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deviceSource: data.deviceSource.present ? data.deviceSource.value : this.deviceSource,
      version: data.version.present ? data.version.value : this.version,
      name: data.name.present ? data.name.value : this.name,
      brief: data.brief.present ? data.brief.value : this.brief,
      description: data.description.present ? data.description.value : this.description,
      changelog: data.changelog.present ? data.changelog.value : this.changelog,
      iconUrl: data.iconUrl.present ? data.iconUrl.value : this.iconUrl,
      screenshotUrls: data.screenshotUrls.present ? data.screenshotUrls.value : this.screenshotUrls,
      downloadUrl: data.downloadUrl.present ? data.downloadUrl.value : this.downloadUrl,
      downloadSize: data.downloadSize.present ? data.downloadSize.value : this.downloadSize,
      publisherName: data.publisherName.present ? data.publisherName.value : this.publisherName,
      publisherId: data.publisherId.present ? data.publisherId.value : this.publisherId,
      categoryName: data.categoryName.present ? data.categoryName.value : this.categoryName,
      categoryId: data.categoryId.present ? data.categoryId.value : this.categoryId,
      builtinId: data.builtinId.present ? data.builtinId.value : this.builtinId,
      isFree: data.isFree.present ? data.isFree.value : this.isFree,
      isRemoved: data.isRemoved.present ? data.isRemoved.value : this.isRemoved,
      isStarred: data.isStarred.present ? data.isStarred.value : this.isStarred,
      starSeenVersion: data.starSeenVersion.present ? data.starSeenVersion.value : this.starSeenVersion,
      minZeppVersion: data.minZeppVersion.present ? data.minZeppVersion.value : this.minZeppVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      refreshedAt: data.refreshedAt.present ? data.refreshedAt.value : this.refreshedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoreItemRow(')
          ..write('appId: $appId, ')
          ..write('entryType: $entryType, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceSource: $deviceSource, ')
          ..write('version: $version, ')
          ..write('name: $name, ')
          ..write('brief: $brief, ')
          ..write('description: $description, ')
          ..write('changelog: $changelog, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('screenshotUrls: $screenshotUrls, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('downloadSize: $downloadSize, ')
          ..write('publisherName: $publisherName, ')
          ..write('publisherId: $publisherId, ')
          ..write('categoryName: $categoryName, ')
          ..write('categoryId: $categoryId, ')
          ..write('builtinId: $builtinId, ')
          ..write('isFree: $isFree, ')
          ..write('isRemoved: $isRemoved, ')
          ..write('isStarred: $isStarred, ')
          ..write('starSeenVersion: $starSeenVersion, ')
          ..write('minZeppVersion: $minZeppVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('refreshedAt: $refreshedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    appId,
    entryType,
    deviceId,
    deviceSource,
    version,
    name,
    brief,
    description,
    changelog,
    iconUrl,
    screenshotUrls,
    downloadUrl,
    downloadSize,
    publisherName,
    publisherId,
    categoryName,
    categoryId,
    builtinId,
    isFree,
    isRemoved,
    isStarred,
    starSeenVersion,
    minZeppVersion,
    updatedAt,
    refreshedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoreItemRow &&
          other.appId == this.appId &&
          other.entryType == this.entryType &&
          other.deviceId == this.deviceId &&
          other.deviceSource == this.deviceSource &&
          other.version == this.version &&
          other.name == this.name &&
          other.brief == this.brief &&
          other.description == this.description &&
          other.changelog == this.changelog &&
          other.iconUrl == this.iconUrl &&
          other.screenshotUrls == this.screenshotUrls &&
          other.downloadUrl == this.downloadUrl &&
          other.downloadSize == this.downloadSize &&
          other.publisherName == this.publisherName &&
          other.publisherId == this.publisherId &&
          other.categoryName == this.categoryName &&
          other.categoryId == this.categoryId &&
          other.builtinId == this.builtinId &&
          other.isFree == this.isFree &&
          other.isRemoved == this.isRemoved &&
          other.isStarred == this.isStarred &&
          other.starSeenVersion == this.starSeenVersion &&
          other.minZeppVersion == this.minZeppVersion &&
          other.updatedAt == this.updatedAt &&
          other.refreshedAt == this.refreshedAt);
}

class StoreItemsCompanion extends UpdateCompanion<StoreItemRow> {
  final Value<int> appId;
  final Value<String> entryType;
  final Value<String> deviceId;
  final Value<int> deviceSource;
  final Value<String> version;
  final Value<String> name;
  final Value<String> brief;
  final Value<String> description;
  final Value<String> changelog;
  final Value<String> iconUrl;
  final Value<List<String>> screenshotUrls;
  final Value<String> downloadUrl;
  final Value<int?> downloadSize;
  final Value<String> publisherName;
  final Value<int?> publisherId;
  final Value<String> categoryName;
  final Value<int?> categoryId;
  final Value<int?> builtinId;
  final Value<bool> isFree;
  final Value<bool> isRemoved;
  final Value<bool> isStarred;
  final Value<String> starSeenVersion;
  final Value<String> minZeppVersion;
  final Value<String?> updatedAt;
  final Value<String?> refreshedAt;
  final Value<int> rowid;
  const StoreItemsCompanion({
    this.appId = const Value.absent(),
    this.entryType = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deviceSource = const Value.absent(),
    this.version = const Value.absent(),
    this.name = const Value.absent(),
    this.brief = const Value.absent(),
    this.description = const Value.absent(),
    this.changelog = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.screenshotUrls = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.downloadSize = const Value.absent(),
    this.publisherName = const Value.absent(),
    this.publisherId = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.builtinId = const Value.absent(),
    this.isFree = const Value.absent(),
    this.isRemoved = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.starSeenVersion = const Value.absent(),
    this.minZeppVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.refreshedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoreItemsCompanion.insert({
    required int appId,
    required String entryType,
    required String deviceId,
    required int deviceSource,
    required String version,
    required String name,
    this.brief = const Value.absent(),
    this.description = const Value.absent(),
    this.changelog = const Value.absent(),
    this.iconUrl = const Value.absent(),
    this.screenshotUrls = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.downloadSize = const Value.absent(),
    this.publisherName = const Value.absent(),
    this.publisherId = const Value.absent(),
    this.categoryName = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.builtinId = const Value.absent(),
    this.isFree = const Value.absent(),
    this.isRemoved = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.starSeenVersion = const Value.absent(),
    this.minZeppVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.refreshedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : appId = Value(appId),
       entryType = Value(entryType),
       deviceId = Value(deviceId),
       deviceSource = Value(deviceSource),
       version = Value(version),
       name = Value(name);
  static Insertable<StoreItemRow> custom({
    Expression<int>? appId,
    Expression<String>? entryType,
    Expression<String>? deviceId,
    Expression<int>? deviceSource,
    Expression<String>? version,
    Expression<String>? name,
    Expression<String>? brief,
    Expression<String>? description,
    Expression<String>? changelog,
    Expression<String>? iconUrl,
    Expression<String>? screenshotUrls,
    Expression<String>? downloadUrl,
    Expression<int>? downloadSize,
    Expression<String>? publisherName,
    Expression<int>? publisherId,
    Expression<String>? categoryName,
    Expression<int>? categoryId,
    Expression<int>? builtinId,
    Expression<bool>? isFree,
    Expression<bool>? isRemoved,
    Expression<bool>? isStarred,
    Expression<String>? starSeenVersion,
    Expression<String>? minZeppVersion,
    Expression<String>? updatedAt,
    Expression<String>? refreshedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (appId != null) 'app_id': appId,
      if (entryType != null) 'entry_type': entryType,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceSource != null) 'device_source': deviceSource,
      if (version != null) 'version': version,
      if (name != null) 'name': name,
      if (brief != null) 'brief': brief,
      if (description != null) 'description': description,
      if (changelog != null) 'changelog': changelog,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (screenshotUrls != null) 'screenshot_urls': screenshotUrls,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (downloadSize != null) 'download_size': downloadSize,
      if (publisherName != null) 'publisher_name': publisherName,
      if (publisherId != null) 'publisher_id': publisherId,
      if (categoryName != null) 'category_name': categoryName,
      if (categoryId != null) 'category_id': categoryId,
      if (builtinId != null) 'builtin_id': builtinId,
      if (isFree != null) 'is_free': isFree,
      if (isRemoved != null) 'is_removed': isRemoved,
      if (isStarred != null) 'is_starred': isStarred,
      if (starSeenVersion != null) 'star_seen_version': starSeenVersion,
      if (minZeppVersion != null) 'min_zepp_version': minZeppVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (refreshedAt != null) 'refreshed_at': refreshedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoreItemsCompanion copyWith({
    Value<int>? appId,
    Value<String>? entryType,
    Value<String>? deviceId,
    Value<int>? deviceSource,
    Value<String>? version,
    Value<String>? name,
    Value<String>? brief,
    Value<String>? description,
    Value<String>? changelog,
    Value<String>? iconUrl,
    Value<List<String>>? screenshotUrls,
    Value<String>? downloadUrl,
    Value<int?>? downloadSize,
    Value<String>? publisherName,
    Value<int?>? publisherId,
    Value<String>? categoryName,
    Value<int?>? categoryId,
    Value<int?>? builtinId,
    Value<bool>? isFree,
    Value<bool>? isRemoved,
    Value<bool>? isStarred,
    Value<String>? starSeenVersion,
    Value<String>? minZeppVersion,
    Value<String?>? updatedAt,
    Value<String?>? refreshedAt,
    Value<int>? rowid,
  }) {
    return StoreItemsCompanion(
      appId: appId ?? this.appId,
      entryType: entryType ?? this.entryType,
      deviceId: deviceId ?? this.deviceId,
      deviceSource: deviceSource ?? this.deviceSource,
      version: version ?? this.version,
      name: name ?? this.name,
      brief: brief ?? this.brief,
      description: description ?? this.description,
      changelog: changelog ?? this.changelog,
      iconUrl: iconUrl ?? this.iconUrl,
      screenshotUrls: screenshotUrls ?? this.screenshotUrls,
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
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (appId.present) {
      map['app_id'] = Variable<int>(appId.value);
    }
    if (entryType.present) {
      map['entry_type'] = Variable<String>(entryType.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (deviceSource.present) {
      map['device_source'] = Variable<int>(deviceSource.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (brief.present) {
      map['brief'] = Variable<String>(brief.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (changelog.present) {
      map['changelog'] = Variable<String>(changelog.value);
    }
    if (iconUrl.present) {
      map['icon_url'] = Variable<String>(iconUrl.value);
    }
    if (screenshotUrls.present) {
      map['screenshot_urls'] = Variable<String>(
        $StoreItemsTable.$converterscreenshotUrls.toSql(screenshotUrls.value),
      );
    }
    if (downloadUrl.present) {
      map['download_url'] = Variable<String>(downloadUrl.value);
    }
    if (downloadSize.present) {
      map['download_size'] = Variable<int>(downloadSize.value);
    }
    if (publisherName.present) {
      map['publisher_name'] = Variable<String>(publisherName.value);
    }
    if (publisherId.present) {
      map['publisher_id'] = Variable<int>(publisherId.value);
    }
    if (categoryName.present) {
      map['category_name'] = Variable<String>(categoryName.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (builtinId.present) {
      map['builtin_id'] = Variable<int>(builtinId.value);
    }
    if (isFree.present) {
      map['is_free'] = Variable<bool>(isFree.value);
    }
    if (isRemoved.present) {
      map['is_removed'] = Variable<bool>(isRemoved.value);
    }
    if (isStarred.present) {
      map['is_starred'] = Variable<bool>(isStarred.value);
    }
    if (starSeenVersion.present) {
      map['star_seen_version'] = Variable<String>(starSeenVersion.value);
    }
    if (minZeppVersion.present) {
      map['min_zepp_version'] = Variable<String>(minZeppVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (refreshedAt.present) {
      map['refreshed_at'] = Variable<String>(refreshedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoreItemsCompanion(')
          ..write('appId: $appId, ')
          ..write('entryType: $entryType, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceSource: $deviceSource, ')
          ..write('version: $version, ')
          ..write('name: $name, ')
          ..write('brief: $brief, ')
          ..write('description: $description, ')
          ..write('changelog: $changelog, ')
          ..write('iconUrl: $iconUrl, ')
          ..write('screenshotUrls: $screenshotUrls, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('downloadSize: $downloadSize, ')
          ..write('publisherName: $publisherName, ')
          ..write('publisherId: $publisherId, ')
          ..write('categoryName: $categoryName, ')
          ..write('categoryId: $categoryId, ')
          ..write('builtinId: $builtinId, ')
          ..write('isFree: $isFree, ')
          ..write('isRemoved: $isRemoved, ')
          ..write('isStarred: $isStarred, ')
          ..write('starSeenVersion: $starSeenVersion, ')
          ..write('minZeppVersion: $minZeppVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('refreshedAt: $refreshedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoreRefreshMetaTable extends StoreRefreshMeta with TableInfo<$StoreRefreshMetaTable, StoreRefreshMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoreRefreshMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryTypeMeta = const VerificationMeta(
    'entryType',
  );
  @override
  late final GeneratedColumn<String> entryType = GeneratedColumn<String>(
    'entry_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceSourceMeta = const VerificationMeta(
    'deviceSource',
  );
  @override
  late final GeneratedColumn<int> deviceSource = GeneratedColumn<int>(
    'device_source',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refreshedAtMeta = const VerificationMeta(
    'refreshedAt',
  );
  @override
  late final GeneratedColumn<String> refreshedAt = GeneratedColumn<String>(
    'refreshed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    entryType,
    deviceSource,
    refreshedAt,
    itemCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'store_refresh_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoreRefreshMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('entry_type')) {
      context.handle(
        _entryTypeMeta,
        entryType.isAcceptableOrUnknown(data['entry_type']!, _entryTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entryTypeMeta);
    }
    if (data.containsKey('device_source')) {
      context.handle(
        _deviceSourceMeta,
        deviceSource.isAcceptableOrUnknown(
          data['device_source']!,
          _deviceSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deviceSourceMeta);
    }
    if (data.containsKey('refreshed_at')) {
      context.handle(
        _refreshedAtMeta,
        refreshedAt.isAcceptableOrUnknown(
          data['refreshed_at']!,
          _refreshedAtMeta,
        ),
      );
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId, entryType};
  @override
  StoreRefreshMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoreRefreshMetaRow(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      entryType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_type'],
      )!,
      deviceSource: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_source'],
      )!,
      refreshedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refreshed_at'],
      ),
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
    );
  }

  @override
  $StoreRefreshMetaTable createAlias(String alias) {
    return $StoreRefreshMetaTable(attachedDatabase, alias);
  }
}

class StoreRefreshMetaRow extends DataClass implements Insertable<StoreRefreshMetaRow> {
  final String deviceId;
  final String entryType;
  final int deviceSource;
  final String? refreshedAt;
  final int itemCount;
  const StoreRefreshMetaRow({
    required this.deviceId,
    required this.entryType,
    required this.deviceSource,
    this.refreshedAt,
    required this.itemCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['entry_type'] = Variable<String>(entryType);
    map['device_source'] = Variable<int>(deviceSource);
    if (!nullToAbsent || refreshedAt != null) {
      map['refreshed_at'] = Variable<String>(refreshedAt);
    }
    map['item_count'] = Variable<int>(itemCount);
    return map;
  }

  StoreRefreshMetaCompanion toCompanion(bool nullToAbsent) {
    return StoreRefreshMetaCompanion(
      deviceId: Value(deviceId),
      entryType: Value(entryType),
      deviceSource: Value(deviceSource),
      refreshedAt: refreshedAt == null && nullToAbsent ? const Value.absent() : Value(refreshedAt),
      itemCount: Value(itemCount),
    );
  }

  factory StoreRefreshMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoreRefreshMetaRow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      entryType: serializer.fromJson<String>(json['entryType']),
      deviceSource: serializer.fromJson<int>(json['deviceSource']),
      refreshedAt: serializer.fromJson<String?>(json['refreshedAt']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'entryType': serializer.toJson<String>(entryType),
      'deviceSource': serializer.toJson<int>(deviceSource),
      'refreshedAt': serializer.toJson<String?>(refreshedAt),
      'itemCount': serializer.toJson<int>(itemCount),
    };
  }

  StoreRefreshMetaRow copyWith({
    String? deviceId,
    String? entryType,
    int? deviceSource,
    Value<String?> refreshedAt = const Value.absent(),
    int? itemCount,
  }) => StoreRefreshMetaRow(
    deviceId: deviceId ?? this.deviceId,
    entryType: entryType ?? this.entryType,
    deviceSource: deviceSource ?? this.deviceSource,
    refreshedAt: refreshedAt.present ? refreshedAt.value : this.refreshedAt,
    itemCount: itemCount ?? this.itemCount,
  );
  StoreRefreshMetaRow copyWithCompanion(StoreRefreshMetaCompanion data) {
    return StoreRefreshMetaRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      entryType: data.entryType.present ? data.entryType.value : this.entryType,
      deviceSource: data.deviceSource.present ? data.deviceSource.value : this.deviceSource,
      refreshedAt: data.refreshedAt.present ? data.refreshedAt.value : this.refreshedAt,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoreRefreshMetaRow(')
          ..write('deviceId: $deviceId, ')
          ..write('entryType: $entryType, ')
          ..write('deviceSource: $deviceSource, ')
          ..write('refreshedAt: $refreshedAt, ')
          ..write('itemCount: $itemCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deviceId, entryType, deviceSource, refreshedAt, itemCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoreRefreshMetaRow &&
          other.deviceId == this.deviceId &&
          other.entryType == this.entryType &&
          other.deviceSource == this.deviceSource &&
          other.refreshedAt == this.refreshedAt &&
          other.itemCount == this.itemCount);
}

class StoreRefreshMetaCompanion extends UpdateCompanion<StoreRefreshMetaRow> {
  final Value<String> deviceId;
  final Value<String> entryType;
  final Value<int> deviceSource;
  final Value<String?> refreshedAt;
  final Value<int> itemCount;
  final Value<int> rowid;
  const StoreRefreshMetaCompanion({
    this.deviceId = const Value.absent(),
    this.entryType = const Value.absent(),
    this.deviceSource = const Value.absent(),
    this.refreshedAt = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoreRefreshMetaCompanion.insert({
    required String deviceId,
    required String entryType,
    required int deviceSource,
    this.refreshedAt = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       entryType = Value(entryType),
       deviceSource = Value(deviceSource);
  static Insertable<StoreRefreshMetaRow> custom({
    Expression<String>? deviceId,
    Expression<String>? entryType,
    Expression<int>? deviceSource,
    Expression<String>? refreshedAt,
    Expression<int>? itemCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (entryType != null) 'entry_type': entryType,
      if (deviceSource != null) 'device_source': deviceSource,
      if (refreshedAt != null) 'refreshed_at': refreshedAt,
      if (itemCount != null) 'item_count': itemCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoreRefreshMetaCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? entryType,
    Value<int>? deviceSource,
    Value<String?>? refreshedAt,
    Value<int>? itemCount,
    Value<int>? rowid,
  }) {
    return StoreRefreshMetaCompanion(
      deviceId: deviceId ?? this.deviceId,
      entryType: entryType ?? this.entryType,
      deviceSource: deviceSource ?? this.deviceSource,
      refreshedAt: refreshedAt ?? this.refreshedAt,
      itemCount: itemCount ?? this.itemCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (entryType.present) {
      map['entry_type'] = Variable<String>(entryType.value);
    }
    if (deviceSource.present) {
      map['device_source'] = Variable<int>(deviceSource.value);
    }
    if (refreshedAt.present) {
      map['refreshed_at'] = Variable<String>(refreshedAt.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoreRefreshMetaCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('entryType: $entryType, ')
          ..write('deviceSource: $deviceSource, ')
          ..write('refreshedAt: $refreshedAt, ')
          ..write('itemCount: $itemCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$StoreCatalogDatabase extends GeneratedDatabase {
  _$StoreCatalogDatabase(QueryExecutor e) : super(e);
  $StoreCatalogDatabaseManager get managers => $StoreCatalogDatabaseManager(this);
  late final $StoreItemsTable storeItems = $StoreItemsTable(this);
  late final $StoreRefreshMetaTable storeRefreshMeta = $StoreRefreshMetaTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    storeItems,
    storeRefreshMeta,
  ];
}

typedef $$StoreItemsTableCreateCompanionBuilder =
    StoreItemsCompanion Function({
      required int appId,
      required String entryType,
      required String deviceId,
      required int deviceSource,
      required String version,
      required String name,
      Value<String> brief,
      Value<String> description,
      Value<String> changelog,
      Value<String> iconUrl,
      Value<List<String>> screenshotUrls,
      Value<String> downloadUrl,
      Value<int?> downloadSize,
      Value<String> publisherName,
      Value<int?> publisherId,
      Value<String> categoryName,
      Value<int?> categoryId,
      Value<int?> builtinId,
      Value<bool> isFree,
      Value<bool> isRemoved,
      Value<bool> isStarred,
      Value<String> starSeenVersion,
      Value<String> minZeppVersion,
      Value<String?> updatedAt,
      Value<String?> refreshedAt,
      Value<int> rowid,
    });
typedef $$StoreItemsTableUpdateCompanionBuilder =
    StoreItemsCompanion Function({
      Value<int> appId,
      Value<String> entryType,
      Value<String> deviceId,
      Value<int> deviceSource,
      Value<String> version,
      Value<String> name,
      Value<String> brief,
      Value<String> description,
      Value<String> changelog,
      Value<String> iconUrl,
      Value<List<String>> screenshotUrls,
      Value<String> downloadUrl,
      Value<int?> downloadSize,
      Value<String> publisherName,
      Value<int?> publisherId,
      Value<String> categoryName,
      Value<int?> categoryId,
      Value<int?> builtinId,
      Value<bool> isFree,
      Value<bool> isRemoved,
      Value<bool> isStarred,
      Value<String> starSeenVersion,
      Value<String> minZeppVersion,
      Value<String?> updatedAt,
      Value<String?> refreshedAt,
      Value<int> rowid,
    });

class $$StoreItemsTableFilterComposer extends Composer<_$StoreCatalogDatabase, $StoreItemsTable> {
  $$StoreItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryType => $composableBuilder(
    column: $table.entryType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceSource => $composableBuilder(
    column: $table.deviceSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brief => $composableBuilder(
    column: $table.brief,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changelog => $composableBuilder(
    column: $table.changelog,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get screenshotUrls => $composableBuilder(
    column: $table.screenshotUrls,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadSize => $composableBuilder(
    column: $table.downloadSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publisherName => $composableBuilder(
    column: $table.publisherName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get builtinId => $composableBuilder(
    column: $table.builtinId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFree => $composableBuilder(
    column: $table.isFree,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRemoved => $composableBuilder(
    column: $table.isRemoved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get starSeenVersion => $composableBuilder(
    column: $table.starSeenVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get minZeppVersion => $composableBuilder(
    column: $table.minZeppVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoreItemsTableOrderingComposer extends Composer<_$StoreCatalogDatabase, $StoreItemsTable> {
  $$StoreItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get appId => $composableBuilder(
    column: $table.appId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryType => $composableBuilder(
    column: $table.entryType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceSource => $composableBuilder(
    column: $table.deviceSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brief => $composableBuilder(
    column: $table.brief,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changelog => $composableBuilder(
    column: $table.changelog,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconUrl => $composableBuilder(
    column: $table.iconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get screenshotUrls => $composableBuilder(
    column: $table.screenshotUrls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadSize => $composableBuilder(
    column: $table.downloadSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publisherName => $composableBuilder(
    column: $table.publisherName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get builtinId => $composableBuilder(
    column: $table.builtinId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFree => $composableBuilder(
    column: $table.isFree,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRemoved => $composableBuilder(
    column: $table.isRemoved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get starSeenVersion => $composableBuilder(
    column: $table.starSeenVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get minZeppVersion => $composableBuilder(
    column: $table.minZeppVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoreItemsTableAnnotationComposer extends Composer<_$StoreCatalogDatabase, $StoreItemsTable> {
  $$StoreItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get appId => $composableBuilder(column: $table.appId, builder: (column) => column);

  GeneratedColumn<String> get entryType => $composableBuilder(column: $table.entryType, builder: (column) => column);

  GeneratedColumn<String> get deviceId => $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get deviceSource => $composableBuilder(
    column: $table.deviceSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get version => $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get brief => $composableBuilder(column: $table.brief, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get changelog => $composableBuilder(column: $table.changelog, builder: (column) => column);

  GeneratedColumn<String> get iconUrl => $composableBuilder(column: $table.iconUrl, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get screenshotUrls => $composableBuilder(
    column: $table.screenshotUrls,
    builder: (column) => column,
  );

  GeneratedColumn<String> get downloadUrl => $composableBuilder(
    column: $table.downloadUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadSize => $composableBuilder(
    column: $table.downloadSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get publisherName => $composableBuilder(
    column: $table.publisherName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get publisherId => $composableBuilder(
    column: $table.publisherId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoryName => $composableBuilder(
    column: $table.categoryName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get builtinId => $composableBuilder(column: $table.builtinId, builder: (column) => column);

  GeneratedColumn<bool> get isFree => $composableBuilder(column: $table.isFree, builder: (column) => column);

  GeneratedColumn<bool> get isRemoved => $composableBuilder(column: $table.isRemoved, builder: (column) => column);

  GeneratedColumn<bool> get isStarred => $composableBuilder(column: $table.isStarred, builder: (column) => column);

  GeneratedColumn<String> get starSeenVersion => $composableBuilder(
    column: $table.starSeenVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get minZeppVersion => $composableBuilder(
    column: $table.minZeppVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => column,
  );
}

class $$StoreItemsTableTableManager
    extends
        RootTableManager<
          _$StoreCatalogDatabase,
          $StoreItemsTable,
          StoreItemRow,
          $$StoreItemsTableFilterComposer,
          $$StoreItemsTableOrderingComposer,
          $$StoreItemsTableAnnotationComposer,
          $$StoreItemsTableCreateCompanionBuilder,
          $$StoreItemsTableUpdateCompanionBuilder,
          (
            StoreItemRow,
            BaseReferences<_$StoreCatalogDatabase, $StoreItemsTable, StoreItemRow>,
          ),
          StoreItemRow,
          PrefetchHooks Function()
        > {
  $$StoreItemsTableTableManager(
    _$StoreCatalogDatabase db,
    $StoreItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$StoreItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$StoreItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$StoreItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> appId = const Value.absent(),
                Value<String> entryType = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> deviceSource = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> brief = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> changelog = const Value.absent(),
                Value<String> iconUrl = const Value.absent(),
                Value<List<String>> screenshotUrls = const Value.absent(),
                Value<String> downloadUrl = const Value.absent(),
                Value<int?> downloadSize = const Value.absent(),
                Value<String> publisherName = const Value.absent(),
                Value<int?> publisherId = const Value.absent(),
                Value<String> categoryName = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int?> builtinId = const Value.absent(),
                Value<bool> isFree = const Value.absent(),
                Value<bool> isRemoved = const Value.absent(),
                Value<bool> isStarred = const Value.absent(),
                Value<String> starSeenVersion = const Value.absent(),
                Value<String> minZeppVersion = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> refreshedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoreItemsCompanion(
                appId: appId,
                entryType: entryType,
                deviceId: deviceId,
                deviceSource: deviceSource,
                version: version,
                name: name,
                brief: brief,
                description: description,
                changelog: changelog,
                iconUrl: iconUrl,
                screenshotUrls: screenshotUrls,
                downloadUrl: downloadUrl,
                downloadSize: downloadSize,
                publisherName: publisherName,
                publisherId: publisherId,
                categoryName: categoryName,
                categoryId: categoryId,
                builtinId: builtinId,
                isFree: isFree,
                isRemoved: isRemoved,
                isStarred: isStarred,
                starSeenVersion: starSeenVersion,
                minZeppVersion: minZeppVersion,
                updatedAt: updatedAt,
                refreshedAt: refreshedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int appId,
                required String entryType,
                required String deviceId,
                required int deviceSource,
                required String version,
                required String name,
                Value<String> brief = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> changelog = const Value.absent(),
                Value<String> iconUrl = const Value.absent(),
                Value<List<String>> screenshotUrls = const Value.absent(),
                Value<String> downloadUrl = const Value.absent(),
                Value<int?> downloadSize = const Value.absent(),
                Value<String> publisherName = const Value.absent(),
                Value<int?> publisherId = const Value.absent(),
                Value<String> categoryName = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int?> builtinId = const Value.absent(),
                Value<bool> isFree = const Value.absent(),
                Value<bool> isRemoved = const Value.absent(),
                Value<bool> isStarred = const Value.absent(),
                Value<String> starSeenVersion = const Value.absent(),
                Value<String> minZeppVersion = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> refreshedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoreItemsCompanion.insert(
                appId: appId,
                entryType: entryType,
                deviceId: deviceId,
                deviceSource: deviceSource,
                version: version,
                name: name,
                brief: brief,
                description: description,
                changelog: changelog,
                iconUrl: iconUrl,
                screenshotUrls: screenshotUrls,
                downloadUrl: downloadUrl,
                downloadSize: downloadSize,
                publisherName: publisherName,
                publisherId: publisherId,
                categoryName: categoryName,
                categoryId: categoryId,
                builtinId: builtinId,
                isFree: isFree,
                isRemoved: isRemoved,
                isStarred: isStarred,
                starSeenVersion: starSeenVersion,
                minZeppVersion: minZeppVersion,
                updatedAt: updatedAt,
                refreshedAt: refreshedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoreItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$StoreCatalogDatabase,
      $StoreItemsTable,
      StoreItemRow,
      $$StoreItemsTableFilterComposer,
      $$StoreItemsTableOrderingComposer,
      $$StoreItemsTableAnnotationComposer,
      $$StoreItemsTableCreateCompanionBuilder,
      $$StoreItemsTableUpdateCompanionBuilder,
      (
        StoreItemRow,
        BaseReferences<_$StoreCatalogDatabase, $StoreItemsTable, StoreItemRow>,
      ),
      StoreItemRow,
      PrefetchHooks Function()
    >;
typedef $$StoreRefreshMetaTableCreateCompanionBuilder =
    StoreRefreshMetaCompanion Function({
      required String deviceId,
      required String entryType,
      required int deviceSource,
      Value<String?> refreshedAt,
      Value<int> itemCount,
      Value<int> rowid,
    });
typedef $$StoreRefreshMetaTableUpdateCompanionBuilder =
    StoreRefreshMetaCompanion Function({
      Value<String> deviceId,
      Value<String> entryType,
      Value<int> deviceSource,
      Value<String?> refreshedAt,
      Value<int> itemCount,
      Value<int> rowid,
    });

class $$StoreRefreshMetaTableFilterComposer extends Composer<_$StoreCatalogDatabase, $StoreRefreshMetaTable> {
  $$StoreRefreshMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryType => $composableBuilder(
    column: $table.entryType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceSource => $composableBuilder(
    column: $table.deviceSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoreRefreshMetaTableOrderingComposer extends Composer<_$StoreCatalogDatabase, $StoreRefreshMetaTable> {
  $$StoreRefreshMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryType => $composableBuilder(
    column: $table.entryType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceSource => $composableBuilder(
    column: $table.deviceSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoreRefreshMetaTableAnnotationComposer extends Composer<_$StoreCatalogDatabase, $StoreRefreshMetaTable> {
  $$StoreRefreshMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId => $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get entryType => $composableBuilder(column: $table.entryType, builder: (column) => column);

  GeneratedColumn<int> get deviceSource => $composableBuilder(
    column: $table.deviceSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refreshedAt => $composableBuilder(
    column: $table.refreshedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemCount => $composableBuilder(column: $table.itemCount, builder: (column) => column);
}

class $$StoreRefreshMetaTableTableManager
    extends
        RootTableManager<
          _$StoreCatalogDatabase,
          $StoreRefreshMetaTable,
          StoreRefreshMetaRow,
          $$StoreRefreshMetaTableFilterComposer,
          $$StoreRefreshMetaTableOrderingComposer,
          $$StoreRefreshMetaTableAnnotationComposer,
          $$StoreRefreshMetaTableCreateCompanionBuilder,
          $$StoreRefreshMetaTableUpdateCompanionBuilder,
          (
            StoreRefreshMetaRow,
            BaseReferences<_$StoreCatalogDatabase, $StoreRefreshMetaTable, StoreRefreshMetaRow>,
          ),
          StoreRefreshMetaRow,
          PrefetchHooks Function()
        > {
  $$StoreRefreshMetaTableTableManager(
    _$StoreCatalogDatabase db,
    $StoreRefreshMetaTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$StoreRefreshMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$StoreRefreshMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$StoreRefreshMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> entryType = const Value.absent(),
                Value<int> deviceSource = const Value.absent(),
                Value<String?> refreshedAt = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoreRefreshMetaCompanion(
                deviceId: deviceId,
                entryType: entryType,
                deviceSource: deviceSource,
                refreshedAt: refreshedAt,
                itemCount: itemCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String entryType,
                required int deviceSource,
                Value<String?> refreshedAt = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoreRefreshMetaCompanion.insert(
                deviceId: deviceId,
                entryType: entryType,
                deviceSource: deviceSource,
                refreshedAt: refreshedAt,
                itemCount: itemCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoreRefreshMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$StoreCatalogDatabase,
      $StoreRefreshMetaTable,
      StoreRefreshMetaRow,
      $$StoreRefreshMetaTableFilterComposer,
      $$StoreRefreshMetaTableOrderingComposer,
      $$StoreRefreshMetaTableAnnotationComposer,
      $$StoreRefreshMetaTableCreateCompanionBuilder,
      $$StoreRefreshMetaTableUpdateCompanionBuilder,
      (
        StoreRefreshMetaRow,
        BaseReferences<_$StoreCatalogDatabase, $StoreRefreshMetaTable, StoreRefreshMetaRow>,
      ),
      StoreRefreshMetaRow,
      PrefetchHooks Function()
    >;

class $StoreCatalogDatabaseManager {
  final _$StoreCatalogDatabase _db;
  $StoreCatalogDatabaseManager(this._db);
  $$StoreItemsTableTableManager get storeItems => $$StoreItemsTableTableManager(_db, _db.storeItems);
  $$StoreRefreshMetaTableTableManager get storeRefreshMeta =>
      $$StoreRefreshMetaTableTableManager(_db, _db.storeRefreshMeta);
}
