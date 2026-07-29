import '../domain/primitives/app_version.dart';
import '../domain/store/store_catalog_query.dart';
import '../models/store_item.dart';
import '../models/watch_model.dart';
import 'credential_store.dart';
import 'package:zelp/domain/exceptions.dart';
import 'store_catalog_db.dart';
import 'store_market_client.dart';
import 'zepp_client.dart';
import 'zepp_version_client.dart';

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
/// this service — except when the user explicitly taps refresh.
///
/// **Model vs source:** cache keys use [WatchModel.deviceId]. Market calls use
/// [WatchModel.canonicalVariant] (first catalog variant) as the deviceSource.
///
/// **Incremental refresh:** list pages are always re-walked (no since/delta on
/// the market). Detail (download URL, description, changelog/“What’s new”) is
/// fetched only when [detailFetchReason] says the cached row is missing or
/// changed — including when description/changelog were never stored.
class StoreCatalogService {
  StoreCatalogService({
    StoreCatalogDb? db,
    StoreMarketClient? marketClient,
    CredentialStore? credentialStore,
    ZeppVersionClient? versionClient,
    ZeppSession Function(Credentials credentials)? sessionFactory,
    this._credentialsLoader,
  }) : _db = db ?? StoreCatalogDb(),
       _market = marketClient ?? StoreMarketClient(),
       _credentials = credentialStore ?? CredentialStore(),
       _versions = versionClient ?? ZeppVersionClient(),
       _sessionFactory =
           sessionFactory ??
           ((c) => ZeppSession(username: c.email, password: c.password));

  final StoreCatalogDb _db;
  final StoreMarketClient _market;
  final CredentialStore _credentials;
  final ZeppVersionClient _versions;
  final ZeppSession Function(Credentials credentials) _sessionFactory;
  final Future<Credentials?> Function()? _credentialsLoader;

  StoreCatalogDb get db => _db;

  Future<Credentials?> _loadCredentials() async {
    final loader = _credentialsLoader;
    if (loader != null) return loader();
    return _credentials.load();
  }

  /// Lists cached items for a watch model (no network).
  Future<List<StoreItem>> browse({
    required StoreEntryType entryType,
    required String deviceId,
    StoreCatalogQuery query = const StoreCatalogQuery(),
  }) {
    return _db.listItems(
      entryType: entryType,
      deviceId: deviceId,
      query: query,
    );
  }

  Future<DateTime?> lastRefreshedAt({
    required StoreEntryType entryType,
    required String deviceId,
  }) {
    return _db.lastRefreshedAt(entryType: entryType, deviceId: deviceId);
  }

  Future<List<String>> categories({
    required StoreEntryType entryType,
    required String deviceId,
  }) {
    return _db.distinctCategories(entryType: entryType, deviceId: deviceId);
  }

  Future<List<String>> publishers({
    required StoreEntryType entryType,
    required String deviceId,
  }) {
    return _db.distinctPublishers(entryType: entryType, deviceId: deviceId);
  }

  /// Watch model ids already in cache for this app (multi-device availability).
  Future<List<String>> compatibleDeviceIds({
    required int appId,
    required StoreEntryType entryType,
  }) {
    return _db.listCompatibleDeviceIds(appId: appId, entryType: entryType);
  }

  /// Pulls the market list for [watch], detail-fetches only new/changed rows.
  Future<StoreRefreshResult> refreshForWatch({
    required WatchModel watch,
    required StoreEntryType entryType,
    int pageLimit = 80,
    StoreRefreshProgress? onProgress,
    Future<void> Function(ZeppSession session)? login,
  }) async {
    final variant = watch.canonicalVariant;
    final deviceId = watch.deviceId;

    final creds = await _loadCredentials();
    if (creds == null || creds.isEmpty) {
      throw AuthenticationException(
        'Sign in on Credentials with “Remember credentials” on before '
        'updating the ${entryType.label.toLowerCase()} list.',
        code: 'store-no-credentials',
      );
    }

    final session = _sessionFactory(creds);
    if (login != null) {
      await login(session);
    } else {
      await session.login();
    }

    final zepp = AppVersion(await _versions.current());
    final listed = await _market.fetchCategorizedCatalog(
      variant: variant,
      entryType: entryType,
      appToken: session.appToken,
      userId: session.userId,
      zeppVersion: zepp,
      deviceId: deviceId,
      pageLimit: pageLimit,
      onProgress: (count) => onProgress?.call(
        listed: count,
        detailed: 0,
        skipped: 0,
        total: count,
      ),
    );

    // Stamp model id; dedupe by appId+version (multi-category duplicates).
    final unique = <String, StoreItem>{};
    for (final item in listed) {
      if (item.appId <= 0) continue;
      unique['${item.appId}|${item.version}'] = item.copyWith(
        deviceId: deviceId,
        deviceSource: variant.deviceSource,
      );
    }
    final toProcess = unique.values.toList();
    final cachedByApp = await _db.mapActiveByAppId(
      entryType: entryType,
      deviceId: deviceId,
    );

    final detailed = <StoreItem>[];
    var fetched = 0;
    var skipped = 0;
    for (final item in toProcess) {
      final cachedLocal = cachedByApp[item.appId];
      // Prefer same-version row on this model; else any enriched row elsewhere.
      StoreItem? cachedSameVersion =
          cachedLocal != null && cachedLocal.version == item.version
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

      final reason = detailFetchReason(listed: item, cached: cachedSameVersion);

      if (reason == null && cachedSameVersion != null) {
        skipped++;
        onProgress?.call(
          listed: toProcess.length,
          detailed: fetched,
          skipped: skipped,
          total: toProcess.length,
        );
        // Reuse shared metadata; stamp this watch model + preserve local stars.
        final localStars = cachedLocal;
        detailed.add(
          mergeListIntoCached(item, cachedSameVersion).copyWith(
            deviceId: deviceId,
            deviceSource: variant.deviceSource,
            isRemoved: false,
            isStarred: localStars?.isStarred ?? cachedSameVersion.isStarred,
            starSeenVersion:
                localStars?.starSeenVersion ??
                cachedSameVersion.starSeenVersion,
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
        final detail = await _market.fetchItemDetail(
          variant: variant,
          entryType: entryType,
          appId: item.appId,
          appToken: session.appToken,
          userId: session.userId,
          zeppVersion: zepp,
        );
        // mergeDetail maps description + new_description (changelog).
        detailed.add(item.mergeDetail(detail));
      } on ZelpException {
        detailed.add(
          cachedSameVersion != null
              ? mergeListIntoCached(item, cachedSameVersion)
              : item,
        );
      }
    }

    await _db.replaceCatalog(
      entryType: entryType,
      deviceId: deviceId,
      deviceSource: variant.deviceSource,
      items: detailed,
    );
    return StoreRefreshResult(
      itemCount: detailed.length,
      detailedCount: fetched,
      skippedDetailCount: skipped,
    );
  }

  /// Ensures [item] has a download URL (fetches detail if missing) and persists it.
  Future<StoreItem> ensureDownloadUrl({
    required StoreItem item,
    required WatchVariant variant,
    Future<void> Function(ZeppSession session)? login,
  }) async {
    if (item.hasDownload) return item;

    final creds = await _loadCredentials();
    if (creds == null || creds.isEmpty) {
      throw AuthenticationException(
        'Sign in on Credentials to prepare this download.',
        code: 'store-no-credentials',
      );
    }
    final session = _sessionFactory(creds);
    if (login != null) {
      await login(session);
    } else {
      await session.login();
    }
    final zepp = AppVersion(await _versions.current());
    final detail = await _market.fetchItemDetail(
      variant: variant,
      entryType: item.entryType,
      appId: item.appId,
      appToken: session.appToken,
      userId: session.userId,
      zeppVersion: zepp,
    );
    final merged = item
        .mergeDetail(detail)
        .copyWith(refreshedAt: DateTime.now().toUtc());
    await _db.upsertItem(merged);
    return merged;
  }
}
