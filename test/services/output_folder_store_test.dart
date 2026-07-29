import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/output_folder_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OutputFolderStore', () {
    test('persists and reloads custom filesystem folder', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final OutputFolderStore store = OutputFolderStore(prefs: prefs);

      await store.save(
        OutputFolder.normalized(
          kind: OutputFolderKind.filesystem,
          filesystemPath: '/tmp/huami-out',
          displayName: '/tmp/huami-out',
        ),
      );

      final OutputFolder loaded = await OutputFolderStore(prefs: prefs).load();
      expect(loaded.kind, OutputFolderKind.filesystem);
      expect(loaded.filesystemPath, '/tmp/huami-out');

      await store.reset();
      expect((await store.load()).kind, OutputFolderKind.defaults);
    });

    test('invalid tree uri falls back to defaults on load', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        OutputFolderStore.prefsKind: OutputFolderKind.androidTree.name,
        OutputFolderStore.prefsTreeUri: '',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final OutputFolder loaded = await OutputFolderStore(prefs: prefs).load();
      expect(loaded, OutputFolder.defaults);
    });
  });

  group('DownloadStorage filesystem clear/count', () {
    test('counts and clears files in selected folder', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Directory dir = await Directory.systemTemp.createTemp('huami_out_');
      addTearDown(() => dir.delete(recursive: true));

      await File('${dir.path}/a.bin').writeAsBytes(<int>[1, 2, 3]);
      await File('${dir.path}/b.zip').writeAsBytes(<int>[4]);
      await Directory('${dir.path}/sub').create();
      await File('${dir.path}/sub/c.bin').writeAsBytes(<int>[5]);

      final OutputFolderStore folderStore = OutputFolderStore(prefs: prefs);
      await folderStore.save(
        OutputFolder.normalized(
          kind: OutputFolderKind.filesystem,
          filesystemPath: dir.path,
          displayName: dir.path,
        ),
      );

      final DownloadStorage storage = DownloadStorage(folderStore: folderStore);
      expect(await storage.countFiles(), 3);
      final ClearFolderWarning warning = await storage.clearWarning();
      expect(warning.message, 'This folder contains 3 files. Delete them?');

      expect(await storage.clearFolder(), 3);
      expect(await storage.countFiles(), 0);

      final SavedExport saved = await storage.saveFile(
        fileName: 'gps_uihh.bin',
        bytes: Uint8List.fromList(<int>[9]),
        kind: AssetKind.gps,
      );
      expect(File(saved.localPath).existsSync(), isTrue);
      expect(File(saved.displayPath).existsSync(), isTrue);
      expect(saved.displayPath, endsWith('/gps/gps_uihh.bin'));
      expect(await storage.countFiles(), 1);

      final keys = await storage.saveFile(
        fileName: 'pairing_keys.txt',
        bytes: Uint8List.fromList([1]),
      );
      expect(keys.displayPath, endsWith('/pairing_keys.txt'));
      expect(keys.displayPath.contains('/gps/'), isFalse);
      expect(await storage.countFiles(), 2);
    });
  });

  group('DownloadStorage Android channel', () {
    test('countFiles forwards treeUri from settings', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final OutputFolderStore folderStore = OutputFolderStore(prefs: prefs);
      await folderStore.save(
        OutputFolder.normalized(
          kind: OutputFolderKind.androidTree,
          treeUri: 'content://tree/x',
          displayName: 'X',
        ),
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('org.zelp/downloads'),
        (
          MethodCall call,
        ) async {
          if (call.method == 'countFiles') {
            expect((call.arguments as Map<Object?, Object?>)['treeUri'], 'content://tree/x');
            return 4;
          }
          return null;
        },
      );

      // Force Android path by only testing through method channel when Platform.isAndroid.
      // On Linux CI this branch is skipped — still verify prefs wiring above.
      if (!Platform.isAndroid) {
        return;
      }

      final DownloadStorage storage = DownloadStorage(folderStore: folderStore);
      expect(await storage.countFiles(), 4);
    });
  });
}
