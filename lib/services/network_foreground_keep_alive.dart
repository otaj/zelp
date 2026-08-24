import 'dart:async';

/// Appearance of the Android foreground-service notification while HTTP is in
/// flight. Reset to [defaults] as soon as the service stops so it cannot linger
/// with stale download copy.
class NetworkForegroundAppearance {
  const NetworkForegroundAppearance({
    this.title = defaultTitle,
    this.body = defaultBody,
    this.progress,
    this.maxProgress,
  });

  static const String defaultTitle = 'Zelp';
  static const String defaultBody = 'Working in the background';
  static const NetworkForegroundAppearance defaults = NetworkForegroundAppearance();

  final String title;
  final String body;
  final int? progress;
  final int? maxProgress;
}

/// Keeps the process in the foreground for the duration of in-flight HTTP.
///
/// Android requires a visible notification for that; [dismissIfIdle] and the
/// short [NetworkForegroundSession.stopDelay] exist so the notification does
/// not stay up after the last request finishes.
abstract class NetworkForegroundKeepAlive {
  static NetworkForegroundKeepAlive instance = const NoopNetworkForegroundKeepAlive();

  Future<void> acquire();

  Future<void> release();

  Future<void> updateAppearance({
    String? title,
    String? body,
    int? progress,
    int? maxProgress,
  });

  /// Stops the foreground service immediately when nothing is in flight
  /// (cancels the coalescing delay). No-op if holders remain.
  Future<void> dismissIfIdle();
}

/// Default in tests and on platforms without a foreground service.
class NoopNetworkForegroundKeepAlive implements NetworkForegroundKeepAlive {
  const NoopNetworkForegroundKeepAlive();

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}

  @override
  Future<void> updateAppearance({
    String? title,
    String? body,
    int? progress,
    int? maxProgress,
  }) async {}

  @override
  Future<void> dismissIfIdle() async {}
}

/// Refcounted keep-alive that starts on 0→1 and stops after [stopDelay] at 0.
///
/// [stopDelay] coalesces back-to-back requests (catalog pages, GPS files) so
/// the notification does not flicker. Call [dismissIfIdle] after a download
/// completes to drop it immediately.
///
/// Start/stop plugin calls are serialized so a delayed stop cannot land after
/// a newer start and leave the service down while HTTP is still in flight.
class NetworkForegroundSession implements NetworkForegroundKeepAlive {
  NetworkForegroundSession({
    required this.onNotify,
    required this.onStop,
    this.stopDelay = defaultStopDelay,
  });

  static const Duration defaultStopDelay = Duration(milliseconds: 200);

  final Future<void> Function(NetworkForegroundAppearance appearance) onNotify;
  final Future<void> Function() onStop;
  final Duration stopDelay;

  int _holders = 0;
  bool _running = false;
  bool _appearanceDirty = false;
  Timer? _stopTimer;
  NetworkForegroundAppearance _appearance = NetworkForegroundAppearance.defaults;
  Future<void> _queue = Future<void>.value();

  int get holders => _holders;

  bool get isRunning => _running;

  @override
  Future<void> acquire() {
    _stopTimer?.cancel();
    _stopTimer = null;
    _holders++;
    return _enqueue(_apply);
  }

  @override
  Future<void> release() async {
    if (_holders == 0) return;
    _holders--;
    if (_holders > 0) return;
    _stopTimer?.cancel();
    _stopTimer = Timer(stopDelay, () {
      unawaited(_enqueue(_apply));
    });
  }

  @override
  Future<void> updateAppearance({
    String? title,
    String? body,
    int? progress,
    int? maxProgress,
  }) {
    _appearance = NetworkForegroundAppearance(
      title: title ?? _appearance.title,
      body: body ?? _appearance.body,
      progress: progress,
      maxProgress: maxProgress,
    );
    _appearanceDirty = true;
    if (_holders == 0) return Future<void>.value();
    return _enqueue(_apply);
  }

  @override
  Future<void> dismissIfIdle() {
    _stopTimer?.cancel();
    _stopTimer = null;
    if (_holders > 0) {
      _appearance = NetworkForegroundAppearance.defaults;
      _appearanceDirty = true;
    }
    return _enqueue(_apply);
  }

  Future<void> _apply() async {
    if (_holders > 0) {
      if (!_running || _appearanceDirty) {
        _running = true;
        _appearanceDirty = false;
        await onNotify(_appearance);
        return;
      }
      _running = true;
      return;
    }
    if (!_running) return;
    _running = false;
    _appearanceDirty = false;
    _appearance = NetworkForegroundAppearance.defaults;
    await onStop();
  }

  Future<void> _enqueue(Future<void> Function() fn) {
    final Completer<void> gate = Completer<void>();
    final Future<void> previous = _queue;
    _queue = gate.future;
    return previous.then<void>((_) => fn()).whenComplete(() {
      if (!gate.isCompleted) {
        gate.complete();
      }
    });
  }
}
