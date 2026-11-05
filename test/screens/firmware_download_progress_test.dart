import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/firmware_check_screen.dart';
import 'package:zelp/screens/widgets/firmware/firmware_history_section.dart';
import 'package:zelp/screens/widgets/firmware/firmware_version_card.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/firmware_file_downloader.dart';
import 'package:zelp/services/firmware_store.dart';
import 'package:zelp/services/output_folder_store.dart';

import '../fixtures/watch_models.dart';
import '../helpers/network_clients.dart';
import '../helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('download spinner and progress stay on the firmware being downloaded', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirmwareStoredVersionsList(
            history: _history(),
            versionsSubtitle: 'GTR 4',
            downloadingVersion: '1.0.0',
            downloadProgress: 0.4,
            downloadProgressLabel: '40 B / 100 B · 40%',
            existingByVersion: const <String, ExistingDownloadMatch>{},
            onCopy: (String value, String label) async {},
            onDownloadFirmware: (FirmwareInfo info) {},
            onShareExisting: (ExistingDownloadMatch match) async {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: _card('1.0.0'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _card('2.0.0'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(tester.widget<IconButton>(_downloadButton('2.0.0')).onPressed, isNull);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,
      0.4,
    );
    expect(find.text('40 B / 100 B · 40%'), findsOneWidget);
    expect(
      find.descendant(of: _card('2.0.0'), matching: find.text('40 B / 100 B · 40%')),
      findsNothing,
    );
  });

  testWidgets('idle firmware cards show a download icon and no progress bar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirmwareStoredVersionsList(
            history: _history(),
            versionsSubtitle: null,
            downloadingVersion: null,
            existingByVersion: const <String, ExistingDownloadMatch>{},
            onCopy: (String value, String label) async {},
            onDownloadFirmware: (FirmwareInfo info) {},
            onShareExisting: (ExistingDownloadMatch match) async {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.widget<IconButton>(_downloadButton('1.0.0')).onPressed, isNotNull);
    expect(tester.widget<IconButton>(_downloadButton('2.0.0')).onPressed, isNotNull);
  });

  testWidgets('firmware screen reports byte progress only for the active download', (
    WidgetTester tester,
  ) async {
    final _PacedClient client = _PacedClient(contentLength: 100);
    addTearDown(() {
      if (!client.isClosed) unawaited(client.finish());
    });

    final SharedPreferences prefs = await mockEmptyPrefs();
    final WatchModel watch = gtr4Watch();
    final FirmwareStore firmwareStore = FirmwareStore(prefs: prefs);
    await firmwareStore.merge(
      watch: watch,
      variant: watch.variants.first,
      discovered: _history().versions,
    );
    final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
    await usage.touchWatch(watch.deviceId, at: DateTime.utc(2026, 6));

    final OutputFolderStore folderStore = OutputFolderStore(prefs: prefs);
    await folderStore.save(
      OutputFolder.normalized(
        kind: OutputFolderKind.filesystem,
        filesystemPath: '/tmp/zelp-fw-ui',
        displayName: '/tmp/zelp-fw-ui',
      ),
    );
    final DownloadStorage downloads = _InstantStorage(folderStore: folderStore);
    final FirmwareFileDownloader downloader = FirmwareFileDownloader(
      httpClient: client,
      storage: downloads,
    );

    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: FirmwareCheckScreen(
          catalog: DeviceCatalog(
            seed: <WatchModel>[watch],
            httpClient: neverHttpClient('device catalog must not hit the network'),
          ),
          versionClient: offlineZeppVersionClient(prefs),
          firmwareStore: firmwareStore,
          downloadStorage: downloads,
          firmwareDownloader: downloader,
          deviceUsageStore: usage,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(_downloadButton('1.0.0'), findsOneWidget);
    expect(_downloadButton('2.0.0'), findsOneWidget);

    await tester.ensureVisible(_downloadButton('1.0.0'));
    await tester.tap(_downloadButton('1.0.0'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Download firmware?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Download'));
    await _pumpUntilFound(tester, find.text('Starting…'));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: _card('2.0.0'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(tester.widget<IconButton>(_downloadButton('2.0.0')).onPressed, isNull);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,
      isNull,
    );

    client.addChunk(Uint8List(40));
    await _pumpUntilFound(tester, find.text('40 B / 100 B · 40%'));

    expect(find.text('40 B / 100 B · 40%'), findsOneWidget);
    expect(
      find.text('Downloading fw-1.0.0.bin · 40 B / 100 B · 40%'),
      findsOneWidget,
    );
    expect(
      tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,
      0.4,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.descendant(
        of: _card('2.0.0'),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );

    client.addChunk(Uint8List(60));
    await _pumpUntilFound(tester, find.text('Saving…'));
    expect(find.text('Saving fw-1.0.0.bin…'), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,
      1,
    );

    unawaited(client.finish());
    await _pumpUntilFound(tester, find.textContaining('Saved fw-1.0.0.bin'));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Already downloaded'), findsOneWidget);
  });
}

StoredFirmwareHistory _history() => StoredFirmwareHistory(
  deviceId: 'gtr4',
  watchName: 'GTR 4',
  versions: <FirmwareInfo>[
    FirmwareInfo(
      firmwareVersion: '1.0.0',
      firmwareUrl: 'https://cdn.example/fw-1.0.0.bin',
    ),
    FirmwareInfo(
      firmwareVersion: '2.0.0',
      firmwareUrl: 'https://cdn.example/fw-2.0.0.bin',
    ),
  ],
);

Finder _card(String version) => find.ancestor(
  of: find.text(version),
  matching: find.byType(FirmwareVersionCard),
);

Finder _downloadButton(String version) => find.descendant(
  of: _card(version),
  matching: find.byWidgetPredicate(
    (Widget widget) => widget is IconButton && widget.tooltip == 'Download to output folder',
  ),
);

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Not found: $finder');
}

/// Skips real filesystem writes so the widget test can finish inside fake async.
class _InstantStorage extends DownloadStorage {
  _InstantStorage({required super.folderStore});

  @override
  Future<SavedExport> saveFile({
    required String fileName,
    required Uint8List bytes,
    AssetKind? kind,
  }) async => SavedExport(
    fileName: fileName,
    displayPath: '/tmp/$fileName',
    localPath: '/tmp/$fileName',
  );
}

/// HTTP client whose body is pushed by the test, so the UI can be observed
/// mid-download.
class _PacedClient extends http.BaseClient {
  _PacedClient({required this.contentLength});

  final int contentLength;
  final StreamController<List<int>> _chunks = StreamController<List<int>>();

  bool get isClosed => _chunks.isClosed;

  void addChunk(List<int> bytes) => _chunks.add(bytes);

  Future<void> finish() => _chunks.close();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async => http.StreamedResponse(
    _chunks.stream,
    200,
    contentLength: contentLength,
    request: request,
  );

  @override
  void close() {
    if (!_chunks.isClosed) unawaited(_chunks.close());
  }
}
