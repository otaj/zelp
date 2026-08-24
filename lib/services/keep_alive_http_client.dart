import 'package:http/http.dart' as http;
import 'package:zelp/services/network_foreground_keep_alive.dart';

/// Production [http.Client] that holds [NetworkForegroundKeepAlive] for each
/// request, including until a streamed body is fully consumed or cancelled.
http.Client zelpHttpClient() => KeepAliveHttpClient(inner: http.Client(), ownsInner: true);

/// Wraps an [http.Client] so every [send] acquires the process foreground
/// keep-alive until the response stream completes, errors, or is cancelled.
class KeepAliveHttpClient extends http.BaseClient {
  KeepAliveHttpClient({
    required this.inner,
    this.ownsInner = false,
    this.keepAlive,
  });

  final http.Client inner;
  final bool ownsInner;
  final NetworkForegroundKeepAlive? keepAlive;

  NetworkForegroundKeepAlive get _active => keepAlive ?? NetworkForegroundKeepAlive.instance;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _active.acquire();
    bool released = false;
    Future<void> releaseOnce() async {
      if (released) return;
      released = true;
      await _active.release();
    }

    bool attachedToStream = false;
    try {
      final http.StreamedResponse response = await inner.send(request);
      attachedToStream = true;
      return http.StreamedResponse(
        _releaseWhenDone(response.stream, releaseOnce),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } finally {
      if (!attachedToStream) {
        await releaseOnce();
      }
    }
  }

  @override
  void close() {
    if (ownsInner) inner.close();
  }
}

Stream<List<int>> _releaseWhenDone(
  Stream<List<int>> source,
  Future<void> Function() releaseOnce,
) async* {
  try {
    yield* source;
  } finally {
    await releaseOnce();
  }
}
