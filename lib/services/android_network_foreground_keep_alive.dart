import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:zelp/services/network_foreground_keep_alive.dart';

/// Android foreground service (`dataSync`) used to keep HTTP alive off-screen.
///
/// The notification is the platform requirement for a foreground service. It is
/// removed as soon as the last in-flight request ends ([dismissIfIdle] or the
/// short coalescing delay in [NetworkForegroundSession]).
class AndroidNetworkForegroundKeepAlive implements NetworkForegroundKeepAlive {
  AndroidNetworkForegroundKeepAlive({
    FlutterLocalNotificationsPlugin? plugin,
    Duration stopDelay = NetworkForegroundSession.defaultStopDelay,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin() {
    _session = NetworkForegroundSession(
      onNotify: _notify,
      onStop: _stop,
      stopDelay: stopDelay,
    );
  }

  static const int _notificationId = 0x5a454c50; // 'ZELP'
  static const String _channelId = 'network_activity';
  static const String _channelName = 'Background activity';

  final FlutterLocalNotificationsPlugin _plugin;
  late final NetworkForegroundSession _session;
  bool _initialized = false;

  @override
  Future<void> acquire() => _session.acquire();

  @override
  Future<void> release() => _session.release();

  @override
  Future<void> updateAppearance({
    String? title,
    String? body,
    int? progress,
    int? maxProgress,
  }) => _session.updateAppearance(
    title: title,
    body: body,
    progress: progress,
    maxProgress: maxProgress,
  );

  @override
  Future<void> dismissIfIdle() => _session.dismissIfIdle();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Shown only while Zelp is transferring data in the background',
            importance: Importance.low,
          ),
        );
    _initialized = true;
  }

  Future<void> _notify(NetworkForegroundAppearance appearance) async {
    try {
      await _ensureInitialized();
      final bool determinate =
          appearance.progress != null && appearance.maxProgress != null && appearance.maxProgress! > 0;
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.startForegroundService(
            id: _notificationId,
            title: appearance.title,
            body: appearance.body,
            notificationDetails: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: 'Shown only while Zelp is transferring data in the background',
              importance: Importance.low,
              priority: Priority.low,
              onlyAlertOnce: true,
              showProgress: true,
              maxProgress: determinate ? appearance.maxProgress! : 0,
              progress: determinate ? appearance.progress!.clamp(0, appearance.maxProgress!) : 0,
              indeterminate: !determinate,
              ongoing: true,
              autoCancel: false,
            ),
            startType: AndroidServiceStartType.startNotSticky,
            foregroundServiceTypes: <AndroidServiceForegroundType>{
              AndroidServiceForegroundType.foregroundServiceTypeDataSync,
            },
          );
    } on Exception catch (_) {
      // Starting from the background can fail on Android 12+; HTTP still proceeds.
    }
  }

  Future<void> _stop() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.stopForegroundService();
    } on Exception catch (_) {
      // Already stopped, or the plugin is unavailable in tests.
    }
  }
}
