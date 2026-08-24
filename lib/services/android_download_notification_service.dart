import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zelp/services/download_notification_service.dart';
import 'package:zelp/services/network_foreground_keep_alive.dart';

/// Android system notifications for firmware (and similar) downloads.
class AndroidDownloadNotificationService implements DownloadNotificationService {
  AndroidDownloadNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'firmware_downloads';
  static const String _channelName = 'Firmware downloads';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Progress and completion for firmware downloads',
            importance: Importance.low,
          ),
        );
    _initialized = true;
  }

  @override
  Future<void> ensurePermission() async {
    await _ensureInitialized();
    final PermissionStatus status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) return;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  @override
  Future<void> showProgress({
    required int id,
    required String title,
    required String body,
    int? progress,
    int? maxProgress,
  }) async {
    // Drive the foreground-service notification (one notification, removed
    // when HTTP goes idle) instead of a second ongoing progress entry.
    await NetworkForegroundKeepAlive.instance.updateAppearance(
      title: title,
      body: body,
      progress: progress,
      maxProgress: maxProgress,
    );
  }

  @override
  Future<void> showCompleted({
    required int id,
    required String title,
    required String body,
  }) async {
    await NetworkForegroundKeepAlive.instance.dismissIfIdle();
    await _ensureInitialized();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Progress and completion for firmware downloads',
        ),
      ),
    );
  }

  @override
  Future<void> showFailed({
    required int id,
    required String title,
    required String body,
  }) async {
    await NetworkForegroundKeepAlive.instance.dismissIfIdle();
    await _ensureInitialized();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Progress and completion for firmware downloads',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    await NetworkForegroundKeepAlive.instance.dismissIfIdle();
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }
}
