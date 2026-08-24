import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/primitives/app_version.dart';
import 'package:zelp/domain/store/market_countries.dart';
import 'package:zelp/domain/store/store_catalog_query.dart';
import 'package:zelp/domain/store/store_device_cache_meta.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/credential_store.dart';
import 'package:zelp/services/store_catalog_db.dart';
import 'package:zelp/services/store_market_client.dart';
import 'package:zelp/services/zepp_client.dart';
import 'package:zelp/services/zepp_version_client.dart';

typedef StoreRefreshProgress =
    void Function({
      required int listed,
      required int detailed,
      required int skipped,
      required int total,
    });

/// Result of an incremental catalog refresh for one watch model.
class StoreRefreshResult {
  const StoreRefreshResult({
    required this.itemCount,
    required this.detailedCount,
    required this.skippedDetailCount,
  });

  final int itemCount;
  final int detailedCount;
  final int skippedDetailCount;
}

/// Refreshes the local Apps / Watchfaces cache using saved Amazfit credentials.
///
/// Browse paths should call [browse] / [StoreCatalogDb.listItems] only — never
/// this service — except when the user explicitly refreshes (button or
/// pull-to-refresh).
///
/// **Model vs source:** cache keys use [WatchModel.deviceId]. Market calls use
/// [WatchModel.canonicalVariant] (first catalog variant) as the deviceSource.
///
/// **Incremental refresh:** list pages are always re-walked (no since/delta on
/// the market). Detail (download URL, description, changelog/“What’s new”) is
/// fetched only when [detailFetchReason] says the cached row is missing or
/// changed — including when description/changelog were never stored.
///
/// **Geo coverage:** list + detail calls are repeated for each entry in
/// [marketCountries] (same idea as Zepp Explorer). Amazfit filters catalogs by
/// country; merging regions surfaces apps/watchfaces that a single `US` query
/// would omit.
class StoreCatalogService {
  StoreCatalogService({
    StoreCatalogDb? db,
    StoreMarketClient? marketClient,
    CredentialStore? credentialStore,
    ZeppVersionClient? versionClient,
    ZeppSession Function(Credentials credentials)? sessionFactory,
    List<String>? marketCountries,
    this._credentialsLoader,
  }) : _db = db ?? StoreCatalogDb(),
       _market = marketClient ?? StoreMarketClient(),
       _credentials = credentialStore ?? CredentialStore(),
       _versions = versionClient ?? ZeppVersionClient(),
       _sessionFactory = sessionFactory ?? ((Credentials c) => ZeppSession(username: c.email, password: c.password)),
       _marketCountries = List<String>.unmodifiable(
         marketCountries ?? kDefaultMarketCountries,
       );

  final StoreCatalogDb _db;
  final StoreMarketClient _market;
  final CredentialStore _credentials;
  final ZeppVersionClient _versions;
  final ZeppSession Function(Credentials credentials) _sessionFactory;
  final List<String> _marketCountries;
  final Future<Credentials?> Function()? _credentialsLoader;

  StoreCatalogDb get db => _db;

  /// Closes the underlying catalog DB when this service owns it.
  Future<void> close() => _db.close();

  /// Regions queried on refresh (injected for tests).
  List<String> get marketCountries => _marketCountries;

  Future<Credentials?> _loadCredentials() async {
    final Future<Credentials?> Function()? loader = _credentialsLoader;
    if (loader != null) return loader();
    return _credentials.load();
  }

  /// Lists cached items for a watch model (no network).
  Future<List<StoreItem>> browse({
    required StoreEntryType entryType,
    required String deviceId,
    StoreCatalogQuery query = const StoreCatalogQuery(),
  }) => _db.listItems(
    entryType: entryType,
    deviceId: deviceId,
    query: query,
  );

  Future<DateTime?> lastRefreshedAt({
    required StoreEntryType entryType,
    required String deviceId,
  }) => _db.lastRefreshedAt(entryType: entryType, deviceId: deviceId);

  /// Watch models that already have a local [entryType] catalog refresh.
  Future<List<StoreDeviceCacheMeta>> listCollectedDevices({
    required StoreEntryType entryType,
  }) => _db.listRefreshMeta(entryType: entryType);

  Future<List<String>> categories({
    required StoreEntryType entryType,
    required String deviceId,
  }) => _db.distinctCategories(entryType: entryType, deviceId: deviceId);

  Future<List<String>> publishers({
    required StoreEntryType entryType,
    required String deviceId,
  }) => _db.distinctPublishers(entryType: entryType, deviceId: deviceId);

  /// Watch model ids already in the local cache for this app.
  Future<List<String>> compatibleDeviceIds({
    required int appId,
    required StoreEntryType entryType,
  }) => _db.listCompatibleDeviceIds(appId: appId, entryType: entryType);

  /// Pulls the market list for [watch], detail-fetches only new/changed rows.
  Future<StoreRefreshResult> refreshForWatch({
    required WatchModel watch,
    required StoreEntryType entryType,
    int pageLimit = 80,
    StoreRefreshProgress? onProgress,
    Future<void> Function(ZeppSession session)? login,
  }) async {
    final WatchVariant variant = watch.canonicalVariant;
    final String deviceId = watch.deviceId;

    final Credentials? creds = await _loadCredentials();
    if (creds == null || creds.isEmpty) {
      throw AuthenticationException(
        'Sign in in Settings before updating the '
        '${entryType.label.toLowerCase()} list.',
        code: 'store-no-credentials',
      );
    }

    final ZeppSession session = _sessionFactory(creds);
    if (login != null) {
      await login(session);
    } else {
      await session.login();
    }

    final AppVersion zepp = AppVersion(await _versions.current());

    final ({
      Map<String, StoreItem> unique,
      Map<String, String> countryByKey,
    })
    listed = await _fetchListAcrossCountries(
      session: session,
      watch: watch,
      variant: variant,
      entryType: entryType,
      deviceId: deviceId,
      zepp: zepp,
      pageLimit: pageLimit,
      onProgress: onProgress,
    );

    final ({List<StoreItem> detailed, int fetched, int skipped}) enriched = await _enrichItemsWithDetail(
      session: session,
      watch: watch,
      variant: variant,
      entryType: entryType,
      deviceId: deviceId,
      zepp: zepp,
      unique: listed.unique,
      countryByKey: listed.countryByKey,
      onProgress: onProgress,
    );

    await _db.replaceCatalog(
      entryType: entryType,
      deviceId: deviceId,
      deviceSource: variant.deviceSource,
      items: enriched.detailed,
    );
    return StoreRefreshResult(
      itemCount: enriched.detailed.length,
      detailedCount: enriched.fetched,
      skippedDetailCount: enriched.skipped,
    );
  }

  Future<({Map<String, StoreItem> unique, Map<String, String> countryByKey})> _fetchListAcrossCountries({
    required ZeppSession session,
    required WatchModel watch,
    required WatchVariant variant,
    required StoreEntryType entryType,
    required String deviceId,
    required AppVersion zepp,
    required int pageLimit,
    StoreRefreshProgress? onProgress,
  }) async {
    // Union of regional catalogs; first country that listed a row wins and is
    // reused for that row's detail fetch.
    final Map<String, StoreItem> unique = <String, StoreItem>{};
    final Map<String, String> countryByKey = <String, String>{};
    ZelpException? lastListError;
    int countriesOk = 0;

    for (final String marketCountry in _marketCountries) {
      try {
        await _market.fetchCategorizedCatalog(
          variant: variant,
          entryType: entryType,
          appToken: session.appToken,
          userId: session.userId,
          zeppVersion: zepp,
          apiLevel: watch.marketApiLevel,
          deviceId: deviceId,
          pageLimit: pageLimit,
          forCountry: marketCountry,
          // Count only net-new appId|version keys so multi-region overlap
          // (and within-region category duplicates) do not inflate progress.
          onItem: (StoreItem item) {
            if (item.appId <= 0) return;
            final String key = '${item.appId}|${item.version}';
            if (unique.containsKey(key)) return;
            unique[key] = item.copyWith(
              deviceId: deviceId,
              deviceSource: variant.deviceSource,
            );
            countryByKey[key] = marketCountry;
            onProgress?.call(
              listed: unique.length,
              detailed: 0,
              skipped: 0,
              total: unique.length,
            );
          },
        );
        countriesOk++;
      } on ZelpException catch (e) {
        lastListError = e;
      }
    }

    if (unique.isEmpty && countriesOk == 0) {
      throw lastListError ??
          DeviceException(
            'Market list failed for all regions',
            code: 'store-list-failed',
          );
    }
    return (unique: unique, countryByKey: countryByKey);
  }

  Future<({List<StoreItem> detailed, int fetched, int skipped})> _enrichItemsWithDetail({
    required ZeppSession session,
    required WatchModel watch,
    required WatchVariant variant,
    required StoreEntryType entryType,
    required String deviceId,
    required AppVersion zepp,
    required Map<String, StoreItem> unique,
    required Map<String, String> countryByKey,
    StoreRefreshProgress? onProgress,
  }) async {
    final List<StoreItem> toProcess = unique.values.toList();
    final Map<int, StoreItem> cachedByApp = await _db.mapActiveByAppId(
      entryType: entryType,
      deviceId: deviceId,
    );

    final List<StoreItem> detailed = <StoreItem>[];
    int fetched = 0;
    int skipped = 0;
    for (final StoreItem item in toProcess) {
      final String itemKey = '${item.appId}|${item.version}';
      final String listedCountry = countryByKey[itemKey] ?? _marketCountries.first;
      final StoreItem? cachedLocal = cachedByApp[item.appId];
      // Prefer same-version row on this model; else any enriched row elsewhere.
      StoreItem? cachedSameVersion = cachedLocal != null && cachedLocal.version == item.version
          ? cachedLocal
          : await _db.getItem(
              appId: item.appId,
              entryType: entryType,
              deviceId: deviceId,
              version: item.version,
            );
      cachedSameVersion ??= await _db.findEnrichedCache(
        appId: item.appId,
        entryType: entryType,
        version: item.version,
      );

      final StoreDetailFetchReason? reason = detailFetchReason(listed: item, cached: cachedSameVersion);

      if (reason == null && cachedSameVersion != null) {
        skipped++;
        onProgress?.call(
          listed: toProcess.length,
          detailed: fetched,
          skipped: skipped,
          total: toProcess.length,
        );
        // Reuse shared metadata; stamp this watch model + preserve local stars.
        final StoreItem? localStars = cachedLocal;
        detailed.add(
          mergeListIntoCached(item, cachedSameVersion).copyWith(
            deviceId: deviceId,
            deviceSource: variant.deviceSource,
            isRemoved: false,
            isStarred: localStars?.isStarred ?? cachedSameVersion.isStarred,
            starSeenVersion: localStars?.starSeenVersion ?? cachedSameVersion.starSeenVersion,
          ),
        );
        continue;
      }

      if (!item.isFree) {
        skipped++;
        detailed.add(item);
        onProgress?.call(
          listed: toProcess.length,
          detailed: fetched,
          skipped: skipped,
          total: toProcess.length,
        );
        continue;
      }

      fetched++;
      onProgress?.call(
        listed: toProcess.length,
        detailed: fetched,
        skipped: skipped,
        total: toProcess.length,
      );
      try {
        final Map<String, dynamic> detail = await _fetchDetailAcrossCountries(
          variant: variant,
          entryType: entryType,
          appId: item.appId,
          appToken: session.appToken,
          userId: session.userId,
          zeppVersion: zepp,
          apiLevel: watch.marketApiLevel,
          preferredCountry: listedCountry,
        );
        // mergeDetail maps description + new_description (changelog).
        detailed.add(StoreMarketClient.mergeDetail(item, detail));
      } on ZelpException {
        detailed.add(
          cachedSameVersion != null ? mergeListIntoCached(item, cachedSameVersion) : item,
        );
      }
    }
    return (detailed: detailed, fetched: fetched, skipped: skipped);
  }

  /// Ensures [item] has a download URL (fetches detail if missing) and persists it.
  Future<StoreItem> ensureDownloadUrl({
    required StoreItem item,
    required WatchVariant variant,
    required int apiLevel,
    Future<void> Function(ZeppSession session)? login,
  }) async {
    if (item.hasDownload) return item;

    final Credentials? creds = await _loadCredentials();
    if (creds == null || creds.isEmpty) {
      throw AuthenticationException(
        'Sign in in Settings to prepare this download.',
        code: 'store-no-credentials',
      );
    }
    final ZeppSession session = _sessionFactory(creds);
    if (login != null) {
      await login(session);
    } else {
      await session.login();
    }
    final AppVersion zepp = AppVersion(await _versions.current());
    final Map<String, dynamic> detail = await _fetchDetailAcrossCountries(
      variant: variant,
      entryType: item.entryType,
      appId: item.appId,
      appToken: session.appToken,
      userId: session.userId,
      zeppVersion: zepp,
      apiLevel: apiLevel,
      preferredCountry: _marketCountries.first,
    );
    final StoreItem merged = StoreMarketClient.mergeDetail(
      item,
      detail,
    ).copyWith(refreshedAt: DateTime.now().toUtc());
    await _db.upsertItem(merged);
    return merged;
  }

  /// Tries [preferredCountry] first, then the rest of [_marketCountries].
  Future<Map<String, dynamic>> _fetchDetailAcrossCountries({
    required WatchVariant variant,
    required StoreEntryType entryType,
    required int appId,
    required String appToken,
    required String userId,
    required AppVersion zeppVersion,
    required int apiLevel,
    required String preferredCountry,
  }) async {
    final List<String> order = <String>[
      preferredCountry,
      for (final String c in _marketCountries)
        if (c != preferredCountry) c,
    ];
    ZelpException? lastError;
    for (final String marketCountry in order) {
      try {
        return await _market.fetchItemDetail(
          variant: variant,
          entryType: entryType,
          appId: appId,
          appToken: appToken,
          userId: userId,
          zeppVersion: zeppVersion,
          apiLevel: apiLevel,
          forCountry: marketCountry,
        );
      } on ZelpException catch (e) {
        lastError = e;
      }
    }
    throw lastError ??
        DeviceException(
          'Market detail failed for all regions',
          code: 'store-detail-failed',
        );
  }
}
