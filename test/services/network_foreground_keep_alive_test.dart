import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelp/services/keep_alive_http_client.dart';
import 'package:zelp/services/network_foreground_keep_alive.dart';

class _RecordingHost {
  final List<String> events = <String>[];
  final List<NetworkForegroundAppearance> notifications = <NetworkForegroundAppearance>[];

  Future<void> notify(NetworkForegroundAppearance appearance) async {
    events.add('start');
    notifications.add(appearance);
  }

  Future<void> stop() async {
    events.add('stop');
  }
}

void main() {
  tearDown(() {
    NetworkForegroundKeepAlive.instance = const NoopNetworkForegroundKeepAlive();
  });

  group('NetworkForegroundSession', () {
    test('starts on first acquire and stops after the coalescing delay', () async {
      final _RecordingHost host = _RecordingHost();
      final NetworkForegroundSession session = NetworkForegroundSession(
        onNotify: host.notify,
        onStop: host.stop,
        stopDelay: Duration.zero,
      );

      await session.acquire();
      expect(host.events, <String>['start']);
      expect(session.isRunning, isTrue);

      await session.release();
      expect(host.events, <String>['start']);

      await pumpEventQueue();
      expect(host.events, <String>['start', 'stop']);
      expect(session.isRunning, isFalse);
    });

    test('does not stop when a new request arrives during the delay', () async {
      final _RecordingHost host = _RecordingHost();
      final NetworkForegroundSession session = NetworkForegroundSession(
        onNotify: host.notify,
        onStop: host.stop,
        stopDelay: const Duration(milliseconds: 40),
      );

      await session.acquire();
      await session.release();
      await session.acquire();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(host.events, <String>['start']);
      expect(session.holders, 1);
      expect(session.isRunning, isTrue);
    });

    test('dismissIfIdle skips the delay so the notification does not linger', () async {
      final _RecordingHost host = _RecordingHost();
      final NetworkForegroundSession session = NetworkForegroundSession(
        onNotify: host.notify,
        onStop: host.stop,
        stopDelay: const Duration(seconds: 30),
      );

      await session.acquire();
      await session.release();
      await session.dismissIfIdle();

      expect(host.events, <String>['start', 'stop']);
    });

    test('overlapping holders keep the service up until the last release', () async {
      final _RecordingHost host = _RecordingHost();
      final NetworkForegroundSession session = NetworkForegroundSession(
        onNotify: host.notify,
        onStop: host.stop,
        stopDelay: Duration.zero,
      );

      await session.acquire();
      await session.acquire();
      await session.release();
      expect(host.events, <String>['start']);

      await session.release();
      await pumpEventQueue();
      expect(host.events, <String>['start', 'stop']);
    });

    test('updateAppearance is stored before start and pushed while running', () async {
      final _RecordingHost host = _RecordingHost();
      final NetworkForegroundSession session = NetworkForegroundSession(
        onNotify: host.notify,
        onStop: host.stop,
        stopDelay: Duration.zero,
      );

      await session.updateAppearance(
        title: 'Downloading firmware',
        body: 'fw.bin',
        progress: 1,
        maxProgress: 4,
      );
      await session.acquire();

      expect(host.notifications.single.title, 'Downloading firmware');
      expect(host.notifications.single.body, 'fw.bin');
      expect(host.notifications.single.progress, 1);
      expect(host.notifications.single.maxProgress, 4);

      await session.updateAppearance(
        title: 'Downloading firmware',
        body: 'fw.bin',
        progress: 4,
        maxProgress: 4,
      );
      expect(host.notifications.last.progress, 4);
    });

    test('dismissIfIdle while busy reverts to default copy without stopping', () async {
      final _RecordingHost host = _RecordingHost();
      final NetworkForegroundSession session = NetworkForegroundSession(
        onNotify: host.notify,
        onStop: host.stop,
        stopDelay: Duration.zero,
      );

      await session.acquire();
      await session.acquire();
      await session.updateAppearance(title: 'Downloading firmware', body: 'fw.bin');
      await session.release();
      await session.dismissIfIdle();

      expect(host.events, isNot(contains('stop')));
      expect(session.isRunning, isTrue);
      expect(host.notifications.last.title, NetworkForegroundAppearance.defaultTitle);
      expect(host.notifications.last.body, NetworkForegroundAppearance.defaultBody);
    });
  });

  group('KeepAliveHttpClient', () {
    test('acquires for the request and releases after the body is read', () async {
      final _RecordingKeepAlive keepAlive = _RecordingKeepAlive();
      final KeepAliveHttpClient client = KeepAliveHttpClient(
        inner: MockClient((_) async {
          expect(keepAlive.acquires, 1);
          expect(keepAlive.releases, 0);
          return http.Response('ok', 200);
        }),
        keepAlive: keepAlive,
      );

      final http.Response response = await client.get(Uri.parse('https://example.test/a'));
      expect(response.body, 'ok');
      expect(keepAlive.acquires, 1);
      expect(keepAlive.releases, 1);
    });

    test('releases when send fails before a stream is attached', () async {
      final _RecordingKeepAlive keepAlive = _RecordingKeepAlive();
      final KeepAliveHttpClient client = KeepAliveHttpClient(
        inner: _ThrowingClient(),
        keepAlive: keepAlive,
      );

      await expectLater(
        client.get(Uri.parse('https://example.test/a')),
        throwsA(isA<http.ClientException>()),
      );
      expect(keepAlive.acquires, 1);
      expect(keepAlive.releases, 1);
    });

    test('holds across overlapping requests', () async {
      final Completer<http.Response> first = Completer<http.Response>();
      final Completer<http.Response> second = Completer<http.Response>();
      int calls = 0;
      final _RecordingKeepAlive keepAlive = _RecordingKeepAlive();
      final KeepAliveHttpClient client = KeepAliveHttpClient(
        inner: MockClient((_) async {
          calls++;
          if (calls == 1) return first.future;
          return second.future;
        }),
        keepAlive: keepAlive,
      );

      final Future<http.Response> a = client.get(Uri.parse('https://example.test/a'));
      final Future<http.Response> b = client.get(Uri.parse('https://example.test/b'));
      await pumpEventQueue();
      expect(keepAlive.acquires, 2);
      expect(keepAlive.releases, 0);

      first.complete(http.Response('a', 200));
      await a;
      expect(keepAlive.releases, 1);

      second.complete(http.Response('b', 200));
      await b;
      expect(keepAlive.releases, 2);
    });
  });
}

class _RecordingKeepAlive implements NetworkForegroundKeepAlive {
  int acquires = 0;
  int releases = 0;

  @override
  Future<void> acquire() async {
    acquires++;
  }

  @override
  Future<void> release() async {
    releases++;
  }

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

class _ThrowingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException('Connection closed', request.url);
  }
}

Future<void> pumpEventQueue() => Future<void>.delayed(Duration.zero);
