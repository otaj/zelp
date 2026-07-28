import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/output/existing_download.dart';
import '../domain/output/output_folder.dart';
import '../domain/output/saved_export.dart';
import 'output_folder_store.dart';

/// Saves files into the user-selected output folder (default: Downloads/Zelp).
///
/// Always mirrors bytes to an app-local path so [FileShareService] can share
/// via FileProvider even when the public copy is MediaStore/SAF-only.
class DownloadStorage {
  DownloadStorage({
    OutputFolderStore? folderStore,
    MethodChannel? channel,
    this._shareCacheOverride,
  }) : _folderStore = folderStore ?? OutputFolderStore(),
       _channel = channel ?? const MethodChannel('org.zelp/downloads');

  final OutputFolderStore _folderStore;
  final MethodChannel _channel;
  final Directory? _shareCacheOverride;

  OutputFolder _folder = OutputFolder.defaults;
  bool _loaded = false;

  OutputFolder get folder => _folder;

  /// Backward-compatible alias used by the Credentials UI.
  OutputFolder get settings => _folder;

  Future<OutputFolder> loadSettings({bool force = false}) async {
    if (_loaded && !force) return _folder;
    _folder = await _folderStore.load();
    _loaded = true;
    return _folder;
  }

  Future<OutputFolder> resetToDefault() async {
    await _folderStore.reset();
    _folder = OutputFolder.defaults;
    _loaded = true;
    return _folder;
  }

  Future<void> _setFolder(OutputFolder folder) async {
    await _folderStore.save(folder);
    _folder = folder;
    _loaded = true;
  }

  /// Opens a folder picker and remembers the choice. Returns null if cancelled.
  Future<OutputFolder?> pickFolder() async {
    await loadSettings();
    if (Platform.isAndroid) {
      final picked = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'pickOutputFolder',
      );
      if (picked == null) return null;
      final uri = picked['uri'] as String?;
      final name = picked['displayName'] as String?;
      if (uri == null || uri.isEmpty) return null;
      final folder = OutputFolder.normalized(
        kind: OutputFolderKind.androidTree,
        treeUri: uri,
        displayName: name,
      );
      await _setFolder(folder);
      return _folder;
    }

    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose output folder',
    );
    if (path == null || path.isEmpty) return null;
    final folder = OutputFolder.normalized(
      kind: OutputFolderKind.filesystem,
      filesystemPath: path,
      displayName: path,
    );
    await _setFolder(folder);
    return _folder;
  }

  /// Writes [bytes] as [fileName] under the selected output folder.
  Future<SavedExport> saveFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    await loadSettings();
    final safeName = p.basename(fileName);

    if (Platform.isAndroid) {
      await _ensureLegacyStoragePermission();
      final localPath = await _mirrorForShare(safeName, bytes);
      final treeUri = _folder.androidTreeUriOrNull;
      if (treeUri != null) {
        final path = await _channel.invokeMethod<String>('saveToTreeUri', {
          'treeUri': treeUri,
          'fileName': safeName,
          'bytes': bytes,
        });
        if (path == null || path.isEmpty) {
          throw StateError('Failed to save $safeName to selected folder');
        }
        return SavedExport(
          fileName: safeName,
          displayPath: path,
          localPath: localPath,
        );
      }
      final path = await _channel.invokeMethod<String>('saveToDownloads', {
        'relativeDir': 'Zelp',
        'fileName': safeName,
        'bytes': bytes,
      });
      if (path == null || path.isEmpty) {
        throw StateError('Failed to save $safeName to Downloads');
      }
      return SavedExport(
        fileName: safeName,
        displayPath: path,
        localPath: localPath,
      );
    }

    final dir = await _resolveFilesystemDir();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    // On desktop/filesystem the public file is already shareable.
    return SavedExport(
      fileName: safeName,
      displayPath: file.path,
      localPath: file.path,
    );
  }

  Future<String> _mirrorForShare(String fileName, Uint8List bytes) async {
    final dir = await _shareCacheDir();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Directory> _shareCacheDir() async {
    final override = _shareCacheOverride;
    if (override != null) return override;
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/share_cache');
  }

  /// Counts files that [clearFolder] would delete.
  Future<int> countFiles() async {
    await loadSettings();
    if (Platform.isAndroid) {
      final count = await _channel.invokeMethod<int>('countFiles', {
        'treeUri': _folder.androidTreeUriOrNull,
      });
      return count ?? 0;
    }

    final dir = await _resolveFilesystemDir();
    if (!await dir.exists()) return 0;
    var count = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) count++;
    }
    return count;
  }

  /// Deletes files in the selected output folder. Returns how many were removed.
  Future<int> clearFolder() async {
    await loadSettings();
    if (Platform.isAndroid) {
      final deleted = await _channel.invokeMethod<int>('clearFolder', {
        'treeUri': _folder.androidTreeUriOrNull,
      });
      return deleted ?? 0;
    }

    final dir = await _resolveFilesystemDir();
    if (!await dir.exists()) return 0;
    var deleted = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          await entity.delete();
          deleted++;
        } catch (_) {}
      }
    }
    return deleted;
  }

  /// Warning model for the clear confirmation dialog.
  Future<ClearFolderWarning> clearWarning() async {
    return ClearFolderWarning(await countFiles());
  }

  /// Lists files in the output folder (non-recursive name map).
  Future<Map<String, StoredOutputFile>> listFilesByName() async {
    await loadSettings();
    if (Platform.isAndroid) {
      final listed = await _channel.invokeMethod<List<dynamic>>('listFiles', {
        'treeUri': _folder.androidTreeUriOrNull,
      });
      final map = <String, StoredOutputFile>{};
      for (final entry in listed ?? const []) {
        if (entry is! Map) continue;
        final name = entry['fileName']?.toString();
        if (name == null || name.isEmpty) continue;
        map[name] = StoredOutputFile(
          fileName: name,
          displayPath: entry['displayPath']?.toString() ?? name,
          localPath: entry['localPath']?.toString(),
        );
      }
      return map;
    }

    final dir = await _resolveFilesystemDir();
    if (!await dir.exists()) return {};
    final map = <String, StoredOutputFile>{};
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      map[name] = StoredOutputFile(
        fileName: name,
        displayPath: entity.path,
        localPath: entity.path,
      );
    }
    return map;
  }

  /// Reads file bytes from the output folder when available.
  Future<Uint8List?> readFileBytes(String fileName) async {
    await loadSettings();
    final safeName = p.basename(fileName);
    if (Platform.isAndroid) {
      final bytes = await _channel.invokeMethod<Uint8List>('readFileBytes', {
        'treeUri': _folder.androidTreeUriOrNull,
        'fileName': safeName,
      });
      return bytes;
    }
    final dir = await _resolveFilesystemDir();
    final file = File('${dir.path}/$safeName');
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Finds an already-stored download by filename and optional API checksum.
  ///
  /// When [checksum] is provided, files are verified by streaming MD5 (local
  /// filesystem openRead, or Android native `fileMd5`) — never by loading the
  /// whole binary into Dart/Binder memory.
  Future<ExistingDownloadMatch?> findExistingDownload({
    required String expectedFileName,
    FileChecksum? checksum,
  }) async {
    final files = await listFilesByName();
    if (files.isEmpty) return null;

    final expected = files[expectedFileName];
    if (checksum == null) {
      if (expected == null) return null;
      return ExistingDownloadMatch(file: expected, matchedByChecksum: false);
    }

    bool? expectedVerified;
    if (expected != null) {
      expectedVerified = await _verifyChecksumStreaming(expected, checksum);
      if (expectedVerified == true) {
        return ExistingDownloadMatch(file: expected, matchedByChecksum: true);
      }
    }

    for (final entry in files.entries) {
      if (entry.key == expectedFileName) continue;
      final verified = await _verifyChecksumStreaming(entry.value, checksum);
      if (verified == true) {
        return ExistingDownloadMatch(
          file: entry.value,
          matchedByChecksum: true,
        );
      }
    }

    // Hashing unavailable (rare) but expected name is present — filename only.
    if (expected != null && expectedVerified == null) {
      return ExistingDownloadMatch(file: expected, matchedByChecksum: false);
    }
    return null;
  }

  /// Returns `true`/`false` when the file can be hashed, otherwise `null`.
  Future<bool?> _verifyChecksumStreaming(
    StoredOutputFile file,
    FileChecksum checksum,
  ) async {
    final path = file.localPath;
    if (path != null && path.isNotEmpty) {
      final ioFile = File(path);
      if (await ioFile.exists()) {
        try {
          return await checksum.matchesByteStream(ioFile.openRead());
        } catch (_) {
          // Fall through to platform hashing when possible.
        }
      }
    }

    if (Platform.isAndroid && checksum.algorithm == FileChecksumAlgorithm.md5) {
      try {
        await loadSettings();
        final hex = await _channel.invokeMethod<String>('fileMd5', {
          'treeUri': _folder.androidTreeUriOrNull,
          'fileName': file.fileName,
        });
        if (hex == null || hex.isEmpty) return null;
        return checksum.matchesHexDigest(hex);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<Directory> _resolveFilesystemDir() async {
    if (_folder.kind == OutputFolderKind.filesystem &&
        _folder.filesystemPath != null &&
        _folder.filesystemPath!.isNotEmpty) {
      return Directory(_folder.filesystemPath!);
    }
    final downloads = await getDownloadsDirectory();
    final base = downloads ?? await getApplicationDocumentsDirectory();
    return Directory('${base.path}/Zelp');
  }

  @Deprecated('Use saveFile')
  Future<SavedExport> saveEpoFile({
    required String fileName,
    required Uint8List bytes,
  }) => saveFile(fileName: fileName, bytes: bytes);

  Future<void> _ensureLegacyStoragePermission() async {
    if (!Platform.isAndroid) return;
    final status = await Permission.storage.status;
    if (status.isGranted || status.isLimited) return;
    if (status.isDenied) {
      await Permission.storage.request();
    }
  }
}
