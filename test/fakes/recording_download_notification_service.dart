import 'package:zelp/services/download_notification_service.dart';

/// In-memory [DownloadNotificationService] that records every call.
class RecordingDownloadNotificationService implements DownloadNotificationService {
  final List<NotificationEvent> events = <NotificationEvent>[];
  int permissionCalls = 0;

  @override
  Future<void> ensurePermission() async {
    permissionCalls++;
    events.add(const NotificationEvent.permission());
  }

  @override
  Future<void> showProgress({
    required int id,
    required String title,
    required String body,
    int? progress,
    int? maxProgress,
  }) async {
    events.add(
      NotificationEvent.progress(
        id: id,
        title: title,
        body: body,
        progress: progress,
        maxProgress: maxProgress,
      ),
    );
  }

  @override
  Future<void> showCompleted({
    required int id,
    required String title,
    required String body,
  }) async {
    events.add(NotificationEvent.completed(id: id, title: title, body: body));
  }

  @override
  Future<void> showFailed({
    required int id,
    required String title,
    required String body,
  }) async {
    events.add(NotificationEvent.failed(id: id, title: title, body: body));
  }

  @override
  Future<void> cancel(int id) async {
    events.add(NotificationEvent.cancel(id: id));
  }
}

enum NotificationKind { permission, progress, completed, failed, cancel }

class NotificationEvent {
  const NotificationEvent._({
    required this.kind,
    this.id,
    this.title,
    this.body,
    this.progress,
    this.maxProgress,
  });

  const NotificationEvent.permission() : this._(kind: NotificationKind.permission);

  const NotificationEvent.progress({
    required int id,
    required String title,
    required String body,
    int? progress,
    int? maxProgress,
  }) : this._(
         kind: NotificationKind.progress,
         id: id,
         title: title,
         body: body,
         progress: progress,
         maxProgress: maxProgress,
       );

  const NotificationEvent.completed({
    required int id,
    required String title,
    required String body,
  }) : this._(
         kind: NotificationKind.completed,
         id: id,
         title: title,
         body: body,
       );

  const NotificationEvent.failed({
    required int id,
    required String title,
    required String body,
  }) : this._(kind: NotificationKind.failed, id: id, title: title, body: body);

  const NotificationEvent.cancel({required int id}) : this._(kind: NotificationKind.cancel, id: id);

  final NotificationKind kind;
  final int? id;
  final String? title;
  final String? body;
  final int? progress;
  final int? maxProgress;
}
