import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/services/download_notification_service.dart';
import 'package:zelp/services/file_download_notifier.dart';
import 'package:zelp/services/firmware_download_notifier.dart';

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

void main() {
  group('FirmwareDownloadNotifier.idFor', () {
    test('is stable, positive, and distinct per file/version', () {
      final int a = FirmwareDownloadNotifier.idFor(
        fileName: 'fw.bin',
        firmwareVersion: '1.0.0',
      );
      final int same = FirmwareDownloadNotifier.idFor(
        fileName: 'fw.bin',
        firmwareVersion: '1.0.0',
      );
      final int otherFile = FirmwareDownloadNotifier.idFor(
        fileName: 'other.bin',
        firmwareVersion: '1.0.0',
      );
      final int otherVersion = FirmwareDownloadNotifier.idFor(
        fileName: 'fw.bin',
        firmwareVersion: '2.0.0',
      );

      expect(a, same);
      expect(a, greaterThanOrEqualTo(0));
      expect(a, lessThanOrEqualTo(0x7fffffff));
      expect(a, isNot(equals(otherFile)));
      expect(a, isNot(equals(otherVersion)));
    });
  });

  group('FirmwareDownloadNotifier lifecycle', () {
    late RecordingDownloadNotificationService recording;
    late FirmwareDownloadNotifier notifier;

    setUp(() {
      recording = RecordingDownloadNotificationService();
      notifier = FirmwareDownloadNotifier(recording);
    });

    test(
      'begin requests permission then shows indeterminate progress',
      () async {
        await notifier.begin(fileName: 'Amazfit.bin', firmwareVersion: '3.2.1');

        expect(recording.permissionCalls, 1);
        expect(recording.events.map((NotificationEvent e) => e.kind), <NotificationKind>[
          NotificationKind.permission,
          NotificationKind.progress,
        ]);
        final NotificationEvent progress = recording.events.last;
        expect(
          progress.id,
          FirmwareDownloadNotifier.idFor(
            fileName: 'Amazfit.bin',
            firmwareVersion: '3.2.1',
          ),
        );
        expect(progress.title, FirmwareDownloadNotifier.progressTitle);
        expect(progress.body, 'Amazfit.bin');
        expect(progress.progress, isNull);
        expect(progress.maxProgress, isNull);
      },
    );

    test('reportProgress is determinate when total is known', () async {
      await notifier.reportProgress(
        fileName: 'fw.bin',
        firmwareVersion: '1.0',
        received: 40,
        total: 100,
      );

      final NotificationEvent event = recording.events.single;
      expect(event.kind, NotificationKind.progress);
      expect(event.progress, 40);
      expect(event.maxProgress, 100);
      expect(event.title, 'Downloading firmware');
      expect(event.body, 'fw.bin');
    });

    test(
      'reportProgress stays indeterminate when total missing or zero',
      () async {
        await notifier.reportProgress(
          fileName: 'fw.bin',
          firmwareVersion: '1.0',
          received: 10,
        );
        await notifier.reportProgress(
          fileName: 'fw.bin',
          firmwareVersion: '1.0',
          received: 20,
          total: 0,
        );

        expect(recording.events, hasLength(2));
        for (final NotificationEvent event in recording.events) {
          expect(event.progress, isNull);
          expect(event.maxProgress, isNull);
        }
      },
    );

    test('complete and fail reuse the same id and fixed titles', () async {
      const String fileName = 'update.zip';
      const String version = '9.9.9';
      final int expectedId = FirmwareDownloadNotifier.idFor(
        fileName: fileName,
        firmwareVersion: version,
      );

      await notifier.begin(fileName: fileName, firmwareVersion: version);
      await notifier.reportProgress(
        fileName: fileName,
        firmwareVersion: version,
        received: 50,
        total: 100,
      );
      await notifier.complete(fileName: fileName, firmwareVersion: version);

      expect(recording.events.map((NotificationEvent e) => e.kind).toList(), <NotificationKind>[
        NotificationKind.permission,
        NotificationKind.progress,
        NotificationKind.progress,
        NotificationKind.completed,
      ]);
      expect(
        recording.events
            .where((NotificationEvent e) => e.id != null)
            .every((NotificationEvent e) => e.id == expectedId),
        isTrue,
      );
      expect(
        recording.events.last.title,
        FirmwareDownloadNotifier.completedTitle,
      );
      expect(recording.events.last.body, fileName);

      recording.events.clear();
      await notifier.fail(fileName: fileName, firmwareVersion: version);
      expect(recording.events.single.kind, NotificationKind.failed);
      expect(recording.events.single.id, expectedId);
      expect(
        recording.events.single.title,
        FirmwareDownloadNotifier.failedTitle,
      );
      expect(recording.events.single.body, fileName);
    });

    test('success path: begin → progress updates → complete', () async {
      const String file = 'gtr4.bin';
      const String ver = '1.2.3';
      await notifier.begin(fileName: file, firmwareVersion: ver);
      await notifier.reportProgress(
        fileName: file,
        firmwareVersion: ver,
        received: 1,
        total: 3,
      );
      await notifier.reportProgress(
        fileName: file,
        firmwareVersion: ver,
        received: 3,
        total: 3,
      );
      await notifier.complete(fileName: file, firmwareVersion: ver);

      expect(recording.events.map((NotificationEvent e) => e.kind), <NotificationKind>[
        NotificationKind.permission,
        NotificationKind.progress,
        NotificationKind.progress,
        NotificationKind.progress,
        NotificationKind.completed,
      ]);
      expect(recording.events[2].progress, 1);
      expect(recording.events[3].progress, 3);
      expect(recording.events[3].maxProgress, 3);
    });

    test('failure path: begin → fail (no completed event)', () async {
      await notifier.begin(fileName: 'bad.bin', firmwareVersion: '0');
      await notifier.fail(fileName: 'bad.bin', firmwareVersion: '0');

      expect(recording.events.map((NotificationEvent e) => e.kind), <NotificationKind>[
        NotificationKind.permission,
        NotificationKind.progress,
        NotificationKind.failed,
      ]);
      expect(
        recording.events.any((NotificationEvent e) => e.kind == NotificationKind.completed),
        isFalse,
      );
    });
  });

  group('FileDownloadNotifier.store', () {
    test('uses app/watchface titles and shared id scheme', () async {
      final RecordingDownloadNotificationService recording = RecordingDownloadNotificationService();
      final FileDownloadNotifier notifier = FileDownloadNotifier.store(recording, singular: 'app');
      await notifier.begin(fileName: 'timer.zpk', version: '11:1.0');
      await notifier.complete(fileName: 'timer.zpk', version: '11:1.0');
      expect(recording.events[1].title, 'Downloading app');
      expect(recording.events.last.title, 'App downloaded');
      expect(
        recording.events[1].id,
        FileDownloadNotifier.idFor(fileName: 'timer.zpk', version: '11:1.0'),
      );
    });
  });

  group('NoopDownloadNotificationService', () {
    test('methods complete without throwing', () async {
      const NoopDownloadNotificationService noop = NoopDownloadNotificationService();
      await noop.ensurePermission();
      await noop.showProgress(
        id: 1,
        title: 't',
        body: 'b',
        progress: 1,
        maxProgress: 2,
      );
      await noop.showCompleted(id: 1, title: 't', body: 'b');
      await noop.showFailed(id: 1, title: 't', body: 'b');
      await noop.cancel(1);
    });
  });
}
