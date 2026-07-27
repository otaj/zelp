/// Abstraction for Android system download notifications (progress / done / fail).
///
/// UI and downloaders depend on this interface so unit tests can use
/// [NoopDownloadNotificationService] without plugins or network.
abstract class DownloadNotificationService {
  Future<void> ensurePermission();

  Future<void> showProgress({
    required int id,
    required String title,
    required String body,
    int? progress,
    int? maxProgress,
  });

  Future<void> showCompleted({
    required int id,
    required String title,
    required String body,
  });

  Future<void> showFailed({
    required int id,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);
}

/// Silent implementation for tests and platforms without notifications.
class NoopDownloadNotificationService implements DownloadNotificationService {
  const NoopDownloadNotificationService();

  @override
  Future<void> ensurePermission() async {}

  @override
  Future<void> showProgress({
    required int id,
    required String title,
    required String body,
    int? progress,
    int? maxProgress,
  }) async {}

  @override
  Future<void> showCompleted({
    required int id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> showFailed({
    required int id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancel(int id) async {}
}
