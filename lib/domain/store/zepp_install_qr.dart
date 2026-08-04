import 'package:zelp/domain/store/store_item.dart';

/// Builds Zepp developer-mode install QR payloads from Amazfit download URLs.
///
/// Same host transform as Zepp Explorer’s install QR (`InstallButton.tsx`):
/// replace `https://` (or `http://`) on the **original** CDN package URL.
/// Apps use `zpkd1://…`; watchfaces use `watchface://…`.
class ZeppInstallQr {
  const ZeppInstallQr._();

  /// Returns the QR string, or `null` if [item] has no usable download URL.
  static String? payloadFor(StoreItem item) {
    final String scheme = switch (item.entryType) {
      StoreEntryType.lightapp => 'zpkd1',
      StoreEntryType.watch => 'watchface',
    };
    return fromDownloadUrl(item.downloadUrl, scheme: scheme);
  }

  /// Scheme transform: `https://cdn…/file.zpk` → `[scheme]://cdn…/file.zpk`.
  ///
  /// Defaults to `zpkd1` (apps). Also accepts `http://`. Returns `null` for
  /// blank/unsupported URLs. Passes through URLs already using [scheme].
  static String? fromDownloadUrl(
    String downloadUrl, {
    String scheme = 'zpkd1',
  }) {
    final String url = downloadUrl.trim();
    if (url.isEmpty) return null;

    final String lower = url.toLowerCase();
    final String prefix = '$scheme://';
    if (lower.startsWith(prefix)) return url;

    if (lower.startsWith('https://')) {
      return '$prefix${url.substring('https://'.length)}';
    }
    if (lower.startsWith('http://')) {
      return '$prefix${url.substring('http://'.length)}';
    }
    return null;
  }
}
