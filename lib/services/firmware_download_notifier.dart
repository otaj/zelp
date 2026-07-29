import 'package:zelp/services/download_notification_service.dart';
import 'package:zelp/services/file_download_notifier.dart';

/// Application-layer orchestration for firmware download notifications.
///
/// Thin wrapper over [FileDownloadNotifier] that keeps the historical
/// `firmwareVersion` parameter names and fixed firmware titles so existing
/// unit tests and the Firmware tab stay stable.
class FirmwareDownloadNotifier {
  FirmwareDownloadNotifier(DownloadNotificationService notifications)
    : _inner = FileDownloadNotifier.firmware(notifications);

  final FileDownloadNotifier _inner;

  static const String progressTitle = 'Downloading firmware';
  static const String completedTitle = 'Firmware downloaded';
  static const String failedTitle = 'Firmware download failed';

  /// Stable positive notification id for a firmware file + version pair.
  static int idFor({
    required String fileName,
    required String firmwareVersion,
  }) => FileDownloadNotifier.idFor(fileName: fileName, version: firmwareVersion);

  Future<void> begin({
    required String fileName,
    required String firmwareVersion,
  }) => _inner.begin(fileName: fileName, version: firmwareVersion);

  /// Updates progress. When [total] is missing/non-positive, progress is
  /// indeterminate (null progress + maxProgress).
  Future<void> reportProgress({
    required String fileName,
    required String firmwareVersion,
    required int received,
    int? total,
  }) => _inner.reportProgress(
    fileName: fileName,
    version: firmwareVersion,
    received: received,
    total: total,
  );

  Future<void> complete({
    required String fileName,
    required String firmwareVersion,
  }) => _inner.complete(fileName: fileName, version: firmwareVersion);

  Future<void> fail({
    required String fileName,
    required String firmwareVersion,
  }) => _inner.fail(fileName: fileName, version: firmwareVersion);
}
