import 'package:zelp/domain/store/store_item.dart';

/// Builds Zepp developer-mode install QR payloads from Amazfit download URLs.
///
/// Same scheme transform as Zepp Explorer’s app install QR (`InstallButton.tsx`):
/// replace `https://` (or `http://`) with `zpkd1://` on the **original** CDN
/// package URL. Used for both apps and watchfaces — Zelp does not proxy through
/// Explorer’s `watchface://…/api/wf_json/…` host.
class ZeppInstallQr {
  const ZeppInstallQr._();

  /// Returns the QR string, or `null` if [item] has no usable download URL.
  static String? payloadFor(StoreItem item) => fromDownloadUrl(item.downloadUrl);

  /// Explorer-compatible transform: `https://cdn…/file.zpk` → `zpkd1://cdn…/file.zpk`.
  ///
  /// Also accepts `http://`. Returns `null` for blank/unsupported URLs.
  static String? fromDownloadUrl(String downloadUrl) {
    final String url = downloadUrl.trim();
    if (url.isEmpty) return null;

    final String lower = url.toLowerCase();
    if (lower.startsWith('zpkd1://')) return url;

    if (lower.startsWith('https://')) {
      return 'zpkd1://${url.substring('https://'.length)}';
    }
    if (lower.startsWith('http://')) {
      return 'zpkd1://${url.substring('http://'.length)}';
    }
    return null;
  }
}
