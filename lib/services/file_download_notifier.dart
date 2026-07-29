import 'package:zelp/services/download_notification_service.dart';

/// Application-layer orchestration for file download notifications.
///
/// Keeps titles, ids, and progress semantics out of widgets so they can be
/// unit-tested against a [DownloadNotificationService] fake (no plugins).
class FileDownloadNotifier {
  FileDownloadNotifier(
    this._notifications, {
    required this.progressTitle,
    required this.completedTitle,
    required this.failedTitle,
  });

  /// Firmware download titles (preserves historical copy).
  factory FileDownloadNotifier.firmware(
    DownloadNotificationService notifications,
  ) => FileDownloadNotifier(
    notifications,
    progressTitle: 'Downloading firmware',
    completedTitle: 'Firmware downloaded',
    failedTitle: 'Firmware download failed',
  );

  /// Store package titles for apps or watchfaces.
  factory FileDownloadNotifier.store(
    DownloadNotificationService notifications, {
    required String singular,
  }) {
    final String label = singular.trim().isEmpty ? 'package' : singular.trim();
    return FileDownloadNotifier(
      notifications,
      progressTitle: 'Downloading $label',
      completedTitle: '${_capitalize(label)} downloaded',
      failedTitle: '${_capitalize(label)} download failed',
    );
  }

  final DownloadNotificationService _notifications;
  final String progressTitle;
  final String completedTitle;
  final String failedTitle;

  /// Stable positive notification id for a file + version pair.
  static int idFor({required String fileName, required String version}) => Object.hash(fileName, version) & 0x7fffffff;

  Future<void> begin({
    required String fileName,
    required String version,
  }) async {
    final int id = idFor(fileName: fileName, version: version);
    await _notifications.ensurePermission();
    await _notifications.showProgress(
      id: id,
      title: progressTitle,
      body: fileName,
    );
  }

  /// Updates progress. When [total] is missing/non-positive, progress is
  /// indeterminate (null progress + maxProgress).
  Future<void> reportProgress({
    required String fileName,
    required String version,
    required int received,
    int? total,
  }) {
    final int id = idFor(fileName: fileName, version: version);
    final bool determinate = total != null && total > 0;
    return _notifications.showProgress(
      id: id,
      title: progressTitle,
      body: fileName,
      progress: determinate ? received : null,
      maxProgress: determinate ? total : null,
    );
  }

  Future<void> complete({required String fileName, required String version}) => _notifications.showCompleted(
    id: idFor(fileName: fileName, version: version),
    title: completedTitle,
    body: fileName,
  );

  Future<void> fail({required String fileName, required String version}) => _notifications.showFailed(
    id: idFor(fileName: fileName, version: version),
    title: failedTitle,
    body: fileName,
  );

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
