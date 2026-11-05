/// Human-readable byte size (`1.5 KB`, `2.0 MB`), or empty when null/non-positive.
String formatByteSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// In-app download caption.
///
/// Determinate: `4.2 MB / 80.0 MB · 5%`. Unknown length: received size only
/// (`4.2 MB`), or `0 B` before the first byte.
String formatDownloadProgress({required int received, int? total}) {
  final String got = received <= 0 ? '0 B' : formatByteSize(received);
  if (total == null || total <= 0) return got;
  final int capped = received.clamp(0, total);
  final int pct = ((capped / total) * 100).round();
  return '$got / ${formatByteSize(total)} · $pct%';
}
