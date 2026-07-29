import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/firmware_file_downloader.dart';
import 'package:zelp/services/output_folder_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirmwareFileDownloader', () {
    late Directory outDir;
    late Directory shareDir;
    late DownloadStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      outDir = await Directory.systemTemp.createTemp('fw_out_');
      shareDir = await Directory.systemTemp.createTemp('fw_share_');
      final OutputFolderStore folderStore = OutputFolderStore(prefs: prefs);
      await folderStore.save(
        OutputFolder.normalized(
          kind: OutputFolderKind.filesystem,
          filesystemPath: outDir.path,
          displayName: outDir.path,
        ),
      );
      storage = DownloadStorage(
        folderStore: folderStore,
        shareCacheOverride: shareDir,
      );
    });

    tearDown(() async {
      if (outDir.existsSync()) await outDir.delete(recursive: true);
      if (shareDir.existsSync()) await shareDir.delete(recursive: true);
    });

    test('downloads bytes via mock HTTP into output folder', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.url.toString(), 'https://example.test/fw/update.bin');
        return http.Response.bytes(Uint8List.fromList(<int>[1, 2, 3, 4]), 200);
      });

      final FirmwareFileDownloader downloader = FirmwareFileDownloader(
        httpClient: mock,
        storage: storage,
      );

      final List<(int, int?)> progress = <(int, int?)>[];
      final SavedExport export = await downloader.downloadToOutputFolder(
        url: Uri.parse('https://example.test/fw/update.bin'),
        onProgress: (int received, int? total) => progress.add((received, total)),
      );

      expect(export.fileName, 'update.bin');
      expect(File('${outDir.path}/fw/update.bin').readAsBytesSync(), <int>[1, 2, 3, 4]);
      expect(File(export.displayPath).readAsBytesSync(), <int>[1, 2, 3, 4]);
      expect(export.displayPath, endsWith('/fw/update.bin'));
      expect(File(export.localPath).existsSync(), isTrue);
      expect(progress, isNotEmpty);
    });

    test('verifies API checksum when provided', () async {
      final Uint8List bytes = Uint8List.fromList('test'.codeUnits);
      final String hex = md5.convert(bytes).toString();
      final MockClient mock = MockClient((_) async => http.Response.bytes(bytes, 200));
      final FirmwareFileDownloader downloader = FirmwareFileDownloader(
        httpClient: mock,
        storage: storage,
      );

      final SavedExport export = await downloader.downloadToOutputFolder(
        url: Uri.parse('https://example.test/fw.bin'),
        fileName: 'fw.bin',
        expectedChecksum: FileChecksum.md5(hex),
      );
      expect(export.fileName, 'fw.bin');
      expect(File('${outDir.path}/fw/fw.bin').existsSync(), isTrue);
    });

    test(
      'rejects checksum mismatch without relying on network truth',
      () async {
        final MockClient mock = MockClient(
          (_) async => http.Response.bytes(Uint8List.fromList(<int>[1, 2]), 200),
        );
        final FirmwareFileDownloader downloader = FirmwareFileDownloader(
          httpClient: mock,
          storage: storage,
        );

        await expectLater(
          () => downloader.downloadToOutputFolder(
            url: Uri.parse('https://example.test/fw.bin'),
            expectedChecksum: const FileChecksum.md5(
              '098f6bcd4621d373cade4e832627b4f6',
            ),
          ),
          throwsA(
            isA<Exception>().having(
              (Exception e) => e.toString(),
              'message',
              contains('checksum'),
            ),
          ),
        );
        expect(outDir.listSync(), isEmpty);
      },
    );

    test('fails on non-200 without writing', () async {
      final MockClient mock = MockClient((_) async => http.Response('nope', 404));
      final FirmwareFileDownloader downloader = FirmwareFileDownloader(
        httpClient: mock,
        storage: storage,
      );

      await expectLater(
        () => downloader.downloadToOutputFolder(
          url: Uri.parse('https://example.test/missing.bin'),
        ),
        throwsA(
          isA<Exception>().having(
            (Exception e) => e.toString(),
            'message',
            contains('404'),
          ),
        ),
      );
      expect(outDir.listSync(), isEmpty);
    });

    test('suggestedFileName prefers URL basename', () {
      expect(
        FirmwareFileDownloader.suggestedFileName(
          firmwareVersion: '1.2.3',
          firmwareUrl: 'https://cdn.example/path/Amazfit_GTR4_1.2.3.zip',
        ),
        'Amazfit_GTR4_1.2.3.zip',
      );
      expect(
        FirmwareFileDownloader.suggestedFileName(
          firmwareVersion: '1.2.3',
          firmwareUrl: null,
        ),
        'firmware_1.2.3.bin',
      );
    });

    test('suggestedFileName falls back when URL has no extension', () {
      expect(
        FirmwareFileDownloader.suggestedFileName(
          firmwareVersion: '1.2.3-beta',
          firmwareUrl: 'https://cdn.example/path/firmware',
        ),
        'firmware_1.2.3-beta.bin',
      );
      expect(
        FirmwareFileDownloader.suggestedFileName(
          firmwareVersion: '1.2.3/rc',
          firmwareUrl: '',
        ),
        'firmware_1.2.3_rc.bin',
      );
    });
  });

  group('DownloadStorage.findExistingDownload', () {
    late Directory outDir;
    late DownloadStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      outDir = await Directory.systemTemp.createTemp('fw_exist_');
      final OutputFolderStore folderStore = OutputFolderStore(prefs: prefs);
      await folderStore.save(
        OutputFolder.normalized(
          kind: OutputFolderKind.filesystem,
          filesystemPath: outDir.path,
          displayName: outDir.path,
        ),
      );
      storage = DownloadStorage(folderStore: folderStore);
    });

    tearDown(() async {
      if (outDir.existsSync()) await outDir.delete(recursive: true);
    });

    test('filename-only match when no checksum', () async {
      await Directory('${outDir.path}/fw').create();
      await File('${outDir.path}/fw/fw.bin').writeAsBytes(<int>[1, 2, 3]);
      final ExistingDownloadMatch? match = await storage.findExistingDownload(
        expectedFileName: 'fw.bin',
        kind: AssetKind.firmware,
      );
      expect(match, isNotNull);
      expect(match!.matchedByChecksum, isFalse);
      expect(match.file.fileName, 'fw.bin');
    });

    test('checksum match finds renamed file', () async {
      final Uint8List bytes = Uint8List.fromList('test'.codeUnits);
      await Directory('${outDir.path}/fw').create();
      await File('${outDir.path}/fw/renamed.bin').writeAsBytes(bytes);
      final ExistingDownloadMatch? match = await storage.findExistingDownload(
        expectedFileName: 'expected.bin',
        checksum: FileChecksum.md5(md5.convert(bytes).toString()),
        kind: AssetKind.firmware,
      );
      expect(match!.file.fileName, 'renamed.bin');
      expect(match.matchedByChecksum, isTrue);
    });

    test('expected name with checksum streams local file', () async {
      final Uint8List bytes = Uint8List.fromList('test'.codeUnits);
      await Directory('${outDir.path}/fw').create();
      await File('${outDir.path}/fw/fw.bin').writeAsBytes(bytes);
      final ExistingDownloadMatch? match = await storage.findExistingDownload(
        expectedFileName: 'fw.bin',
        checksum: FileChecksum.md5(md5.convert(bytes).toString()),
        kind: AssetKind.firmware,
      );
      expect(match!.file.fileName, 'fw.bin');
      expect(match.matchedByChecksum, isTrue);
    });

    test('does not match files in a sibling asset subfolder', () async {
      await Directory('${outDir.path}/apps').create(recursive: true);
      await File('${outDir.path}/apps/fw.bin').writeAsBytes([1, 2, 3]);
      final match = await storage.findExistingDownload(
        expectedFileName: 'fw.bin',
        kind: AssetKind.firmware,
      );
      expect(match, isNull);
    });
  });
}
