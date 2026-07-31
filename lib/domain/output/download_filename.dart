/// Builds local download filenames (CDN basenames or compact semantic names).
class DownloadFilename {
  DownloadFilename._();

  static final RegExp _unsafe = RegExp('[^A-Za-z0-9._-]+');
  static final RegExp _collapsed = RegExp('_{2,}');

  /// Filesystem-safe segment: letters, digits, `.`, `_`, `-` only.
  static String sanitize(String input, {String fallback = 'file'}) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return fallback;
    final String replaced = trimmed.replaceAll(_unsafe, '_');
    final String collapsed = replaced.replaceAll(_collapsed, '_');
    final String stripped = collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
    if (stripped.isEmpty) return fallback;
    if (stripped.length <= 80) return stripped;
    return stripped.substring(0, 80);
  }

  /// Extension from a URL path basename, or [fallback] (including the dot).
  static String extensionFromUrl(String? url, {required String fallback}) {
    if (url == null || url.trim().isEmpty) return fallback;
    final String path = Uri.tryParse(url.trim())?.path ?? '';
    final int slash = path.lastIndexOf('/');
    final String basename = slash >= 0 ? path.substring(slash + 1) : path;
    final int dot = basename.lastIndexOf('.');
    if (dot <= 0 || dot == basename.length - 1) return fallback;
    final String ext = basename.substring(dot);
    if (_unsafe.hasMatch(ext.substring(1))) return fallback;
    return ext;
  }

  /// Basename from a URL path when it looks like a real file name.
  static String? basenameFromUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final String path = Uri.tryParse(url.trim())?.path ?? '';
    final List<String> segments = path.split('/').where((String s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final String last = segments.last;
    if (!last.contains('.')) return null;
    return last;
  }

  /// App / watchface filename. Semantic: `{name}_{version}.ext`.
  static String forStoreItem({
    required String name,
    required String version,
    required String downloadUrl,
    required int appId,
    required String kindSingular,
    required bool semantic,
  }) {
    final String? fromUrl = basenameFromUrl(downloadUrl);
    if (!semantic) {
      if (fromUrl != null) return fromUrl;
      final String safeVer = sanitize(version, fallback: 'unknown');
      return '${kindSingular}_${appId}_$safeVer.zip';
    }

    final String ext = extensionFromUrl(downloadUrl, fallback: '.zip');
    final String safeName = sanitize(name, fallback: kindSingular);
    final String safeVer = sanitize(version, fallback: 'unknown');
    return '${safeName}_$safeVer$ext';
  }

  /// Firmware filename. Semantic: `{deviceName}_{version}.ext`.
  static String forFirmware({
    required String firmwareVersion,
    required String? firmwareUrl,
    required bool semantic,
    String? deviceName,
  }) {
    final String? fromUrl = basenameFromUrl(firmwareUrl);
    if (!semantic) {
      if (fromUrl != null) return fromUrl;
      final String safe = sanitize(firmwareVersion, fallback: 'unknown');
      return 'firmware_$safe.bin';
    }

    final String ext = extensionFromUrl(firmwareUrl, fallback: '.bin');
    final String safeDevice = sanitize(
      deviceName?.trim().isNotEmpty == true ? deviceName! : 'firmware',
      fallback: 'firmware',
    );
    final String safeVer = sanitize(firmwareVersion, fallback: 'unknown');
    return '${safeDevice}_$safeVer$ext';
  }
}
