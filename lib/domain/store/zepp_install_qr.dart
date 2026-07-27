import '../../models/store_item.dart';

/// Builds Zepp developer-mode install QR payloads (same schemes as Explorer).
///
/// **Apps (`lightapp`)** — Explorer replaces `https://` with `zpkd1://` on the
/// package download URL (`InstallButton.tsx`).
///
/// **Watchfaces (`watch`)** — Explorer uses the JSON-host scheme
/// `watchface://{host}/api/wf_json/{appTargetId}` (optional `/mirrored`).
/// Zepp fetches `https://{host}/api/wf_json/{id}` and expects
/// [watchfaceJsonDocument] / Explorer `WatchfaceJsonSchema`.
class ZeppInstallQr {
  const ZeppInstallQr._();

  /// Default host for watchface QR URLs (no scheme), matching Explorer’s
  /// `location.host` shape. Override via [payloadFor] / [forWatchface] when
  /// pointing at another Explorer (or compatible) JSON host.
  static const defaultJsonHost = 'zepp.gfd.lt';

  /// Returns the QR string, or `null` if [item] cannot produce a payload.
  static String? payloadFor(
    StoreItem item, {
    String jsonHost = defaultJsonHost,
    bool mirrored = false,
  }) {
    switch (item.entryType) {
      case StoreEntryType.lightapp:
        return fromDownloadUrl(item.downloadUrl);
      case StoreEntryType.watch:
        return forWatchface(
          appTargetId: item.appId,
          host: jsonHost,
          mirrored: mirrored,
        );
    }
  }

  /// Explorer-compatible transform: `https://cdn…/file.zpk` → `zpkd1://cdn…/file.zpk`.
  /// Also accepts `http://`. Returns `null` for blank/unsupported URLs.
  static String? fromDownloadUrl(String downloadUrl) {
    final url = downloadUrl.trim();
    if (url.isEmpty) return null;

    final lower = url.toLowerCase();
    if (lower.startsWith('zpkd1://')) return url;

    if (lower.startsWith('https://')) {
      return 'zpkd1://${url.substring('https://'.length)}';
    }
    if (lower.startsWith('http://')) {
      return 'zpkd1://${url.substring('http://'.length)}';
    }
    return null;
  }

  /// Explorer [InstallButton]: `watchface://${host}/api/wf_json/${appTargetId}`.
  ///
  /// [appTargetId] is Explorer’s `AppTarget.id` when the host is Explorer; for
  /// market-sourced [StoreItem] rows this app uses Amazfit [StoreItem.appId]
  /// (same numeric id shape in the URL path).
  static String? forWatchface({
    required int appTargetId,
    String host = defaultJsonHost,
    bool mirrored = false,
  }) {
    if (appTargetId <= 0) return null;
    final h = host.trim();
    if (h.isEmpty) return null;
    // Strip accidental scheme if a full URL was passed.
    final hostOnly = h
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .split('/')
        .first
        .trim();
    if (hostOnly.isEmpty) return null;
    final suffix = mirrored ? '/mirrored' : '';
    return 'watchface://$hostOnly/api/wf_json/$appTargetId$suffix';
  }

  /// Explorer watchface JSON shape (`WatchfaceJsonSchema`).
  static Map<String, Object?> watchfaceJsonDocument({
    required int appId,
    required String name,
    required int updatedAtUnix,
    required String downloadUrl,
    required String previewUrl,
    required List<int> deviceSources,
  }) {
    return {
      'appid': appId,
      'name': name,
      'updated_at': updatedAtUnix,
      'url': downloadUrl,
      'preview': previewUrl,
      'devices': deviceSources,
    };
  }

  /// Builds [watchfaceJsonDocument] fields from a catalog [item] when possible.
  static Map<String, Object?>? watchfaceJsonDocumentFor(StoreItem item) {
    if (item.entryType != StoreEntryType.watch) return null;
    if (item.appId <= 0 || !item.hasDownload) return null;
    final updated = item.updatedAt ?? item.refreshedAt;
    return watchfaceJsonDocument(
      appId: item.appId,
      name: item.name,
      updatedAtUnix: updated == null
          ? 0
          : updated.toUtc().millisecondsSinceEpoch ~/ 1000,
      downloadUrl: item.downloadUrl.trim(),
      previewUrl: item.iconUrl.trim(),
      deviceSources: item.deviceSource > 0
          ? <int>[item.deviceSource]
          : const <int>[],
    );
  }
}
