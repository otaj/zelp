import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/services/file_checksum_hash.dart';
import 'package:zelp/services/output_folder_store.dart';

/// One row for [DownloadStorage.scanExistingMatches].
class ExistingDownloadProbe {
  const ExistingDownloadProbe({
    required this.key,
    required this.expectedFileName,
    this.kind,
    this.checksum,
    this.timeout,
  });

  /// Map key returned when a match is found (e.g. item or firmware version id).
  final String key;
  final String expectedFileName;
  final AssetKind? kind;
  final FileChecksum? checksum;

  /// Optional per-item timeout (store catalog uses a short bound for browse).
  final Duration? timeout;
}

/// Saves files into the user-selected output folder (default: Downloads/Zelp).
///
/// When [splitByType] is on (default), typed downloads go under an
/// `AssetKind` subfolder (`fw`, `apps`, …). When off, all files land in the
/// folder root. Omitting `kind` always writes at the folder root.
///
/// Always mirrors bytes to an app-local path so `FileShareService` can share
/// via FileProvider even when the public copy is MediaStore/SAF-only.
class DownloadStorage {
  DownloadStorage({
    OutputFolderStore? folderStore,
    MethodChannel? channel,
    this._shareCacheOverride,
  }) : _folderStore = folderStore ?? OutputFolderStore(),
       _channel = channel ?? const MethodChannel('dev.otaj.zelp/downloads');

  final OutputFolderStore _folderStore;
  final MethodChannel _channel;
  final Directory? _shareCacheOverride;

  OutputFolder _folder = OutputFolder.defaults;
  bool _splitByType = OutputFolderStore.defaultSplitByType;
  bool _semanticNames = OutputFolderStore.defaultSemanticNames;
  bool _loaded = false;

  OutputFolder get folder => _folder;

  /// Backward-compatible alias used by the Settings UI.
  OutputFolder get settings => _folder;

  /// When true, typed downloads use `AssetKind` subfolders.
  bool get splitByType => _splitByType;

  /// When true, downloads use compact name+version filenames.
  bool get semanticNames => _semanticNames;

  Future<OutputFolder> loadSettings({bool force = false}) async {
    if (_loaded && !force) return _folder;
    _folder = await _folderStore.load();
    _splitByType = await _folderStore.loadSplitByType();
    _semanticNames = await _folderStore.loadSemanticNames();
    _loaded = true;
    return _folder;
  }

  Future<bool> setSplitByType({required bool enabled}) async {
    await _folderStore.saveSplitByType(enabled: enabled);
    _splitByType = enabled;
    _loaded = true;
    return _splitByType;
  }

  Future<bool> setSemanticNames({required bool enabled}) async {
    await _folderStore.saveSemanticNames(enabled: enabled);
    _semanticNames = enabled;
    _loaded = true;
    return _semanticNames;
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

  /// Applies [splitByType]: when off, typed downloads behave as root saves.
  AssetKind? _effectiveKind(AssetKind? kind) {
    if (!_splitByType) return null;
    return kind;
  }

  /// Opens a folder picker and remembers the choice. Returns null if cancelled.
  Future<OutputFolder?> pickFolder() async {
    await loadSettings();
    if (Platform.isAndroid) {
      final Map<dynamic, dynamic>? picked = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'pickOutputFolder',
      );
      if (picked == null) return null;
      final String? uri = picked['uri'] as String?;
      final String? name = picked['displayName'] as String?;
      if (uri == null || uri.isEmpty) return null;
      final OutputFolder folder = OutputFolder.normalized(
        kind: OutputFolderKind.androidTree,
        treeUri: uri,
        displayName: name,
      );
      await _setFolder(folder);
      return _folder;
    }

    final String? path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose output folder',
    );
    if (path == null || path.isEmpty) return null;
    final OutputFolder folder = OutputFolder.normalized(
      kind: OutputFolderKind.filesystem,
      filesystemPath: path,
      displayName: path,
    );
    await _setFolder(folder);
    return _folder;
  }

  /// Writes [bytes] as [fileName] under the selected output folder.
  ///
  /// When [kind] is set and [splitByType] is on, the file is stored in that
  /// asset's subfolder; otherwise it is stored at the folder root.
  Future<SavedExport> saveFile({
    required String fileName,
    required Uint8List bytes,
    AssetKind? kind,
  }) async {
    await loadSettings();
    final String safeName = p.basename(fileName);
    final AssetKind? effective = _effectiveKind(kind);

    if (Platform.isAndroid) {
      await _ensureLegacyStoragePermission();
      final String localPath = await _mirrorForShare(safeName, bytes, kind: effective);
      final String? treeUri = _folder.androidTreeUriOrNull;
      if (treeUri != null) {
        final String? path = await _channel.invokeMethod<String>('saveToTreeUri', <String, Object>{
          'treeUri': treeUri,
          'fileName': safeName,
          'bytes': bytes,
          if (effective != null) 'relativeDir': effective.folderName,
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
      final String? path = await _channel.invokeMethod<String>('saveToDownloads', <String, Object>{
        'relativeDir': _relativeDir(effective),
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

    final Directory dir = await _resolveFilesystemDir(kind: effective);
    await dir.create(recursive: true);
    final File file = File('${dir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    // On desktop/filesystem the public file is already shareable.
    return SavedExport(
      fileName: safeName,
      displayPath: file.path,
      localPath: file.path,
    );
  }

  Future<String> _mirrorForShare(
    String fileName,
    Uint8List bytes, {
    AssetKind? kind,
  }) async {
    final Directory dir = await _shareCacheDir(kind: kind);
    await dir.create(recursive: true);
    final File file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Directory> _shareCacheDir({AssetKind? kind}) async {
    final Directory? override = _shareCacheOverride;
    final Directory base = override ?? Directory('${(await getApplicationSupportDirectory()).path}/share_cache');
    if (kind == null) return base;
    return Directory('${base.path}/${kind.folderName}');
  }

  /// Counts files that [clearFolder] would delete.
  Future<int> countFiles() async {
    await loadSettings();
    if (Platform.isAndroid) {
      final int? count = await _channel.invokeMethod<int>('countFiles', <String, String?>{
        'treeUri': _folder.androidTreeUriOrNull,
      });
      return count ?? 0;
    }

    final Directory dir = await _resolveFilesystemDir();
    if (!dir.existsSync()) return 0;
    int count = 0;
    await for (final FileSystemEntity entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) count++;
    }
    return count;
  }

  /// Deletes files in the selected output folder. Returns how many were removed.
  ///
  /// Also clears the app-local share cache so share mirrors cannot outlive
  /// the user-visible folder.
  Future<int> clearFolder() async {
    await loadSettings();
    int deleted = 0;
    if (Platform.isAndroid) {
      deleted =
          await _channel.invokeMethod<int>('clearFolder', <String, String?>{
            'treeUri': _folder.androidTreeUriOrNull,
          }) ??
          0;
    } else {
      final Directory dir = await _resolveFilesystemDir();
      if (dir.existsSync()) {
        await for (final FileSystemEntity entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              await entity.delete();
              deleted++;
            } on Exception {
              // Best-effort deletion; skip files we can't remove.
            }
          }
        }
      }
    }
    await _clearShareCache();
    return deleted;
  }

  Future<void> _clearShareCache() async {
    try {
      final Directory base = await _shareCacheDir().timeout(
        const Duration(seconds: 2),
      );
      if (!base.existsSync()) return;
      await for (final FileSystemEntity entity in base.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            await entity.delete();
          } on Exception {
            // Best-effort; leave undeleteable mirrors alone.
          }
        }
      }
    } on Exception {
      // Folder resolution can fail or hang without path_provider in tests.
    }
  }

  /// Warning model for the clear confirmation dialog.
  Future<ClearFolderWarning> clearWarning() async => ClearFolderWarning(await countFiles());

  /// Lists files in the output folder (or [kind] subfolder), non-recursive.
  Future<Map<String, StoredOutputFile>> listFilesByName({
    AssetKind? kind,
  }) async {
    await loadSettings();
    final AssetKind? effective = _effectiveKind(kind);
    if (Platform.isAndroid) {
      final List<dynamic>? listed = await _channel.invokeMethod<List<dynamic>>('listFiles', <String, String?>{
        'treeUri': _folder.androidTreeUriOrNull,
        'relativeDir': _relativeDir(effective),
      });
      final Map<String, StoredOutputFile> map = <String, StoredOutputFile>{};
      for (final Object? entry in listed ?? const <dynamic>[]) {
        if (entry is! Map) continue;
        final String? name = entry['fileName']?.toString();
        if (name == null || name.isEmpty) continue;
        map[name] = StoredOutputFile(
          fileName: name,
          displayPath: entry['displayPath']?.toString() ?? name,
          localPath: entry['localPath']?.toString(),
        );
      }
      return map;
    }

    final Directory dir = await _resolveFilesystemDir(kind: effective);
    if (!dir.existsSync()) return <String, StoredOutputFile>{};
    final Map<String, StoredOutputFile> map = <String, StoredOutputFile>{};
    await for (final FileSystemEntity entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final String name = p.basename(entity.path);
      map[name] = StoredOutputFile(
        fileName: name,
        displayPath: entity.path,
        localPath: entity.path,
      );
    }
    return map;
  }

  /// Reads file bytes from the output folder when available.
  Future<Uint8List?> readFileBytes(String fileName, {AssetKind? kind}) async {
    await loadSettings();
    final String safeName = p.basename(fileName);
    final AssetKind? effective = _effectiveKind(kind);
    if (Platform.isAndroid) {
      final Uint8List? bytes = await _channel.invokeMethod<Uint8List>('readFileBytes', <String, String?>{
        'treeUri': _folder.androidTreeUriOrNull,
        'fileName': safeName,
        'relativeDir': _relativeDir(effective),
      });
      return bytes;
    }
    final Directory dir = await _resolveFilesystemDir(kind: effective);
    final File file = File('${dir.path}/$safeName');
    if (!file.existsSync()) return null;
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
    AssetKind? kind,
  }) async {
    await loadSettings();
    final AssetKind? effective = _effectiveKind(kind);
    final Map<String, StoredOutputFile> files = await listFilesByName(kind: kind);
    if (files.isEmpty) return null;

    final StoredOutputFile? expected = files[expectedFileName];
    if (checksum == null) {
      if (expected == null) return null;
      return ExistingDownloadMatch(file: expected, matchedByChecksum: false);
    }

    bool? expectedVerified;
    if (expected != null) {
      expectedVerified = await _verifyChecksumStreaming(
        expected,
        checksum,
        kind: effective,
      );
      if (expectedVerified == true) {
        return ExistingDownloadMatch(file: expected, matchedByChecksum: true);
      }
    }

    for (final MapEntry<String, StoredOutputFile> entry in files.entries) {
      if (entry.key == expectedFileName) continue;
      final bool? verified = await _verifyChecksumStreaming(
        entry.value,
        checksum,
        kind: effective,
      );
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

  /// Probes [items] for existing output-folder matches (best-effort per item).
  ///
  /// Loads settings once, then runs [findExistingDownload] for each probe.
  /// Per-item failures (and optional timeouts) are swallowed — same as the
  /// prior store/firmware scan loops.
  Future<Map<String, ExistingDownloadMatch>> scanExistingMatches(
    Iterable<ExistingDownloadProbe> items, {
    bool forceReloadSettings = true,
  }) async {
    await loadSettings(force: forceReloadSettings);
    final Map<String, ExistingDownloadMatch> map = <String, ExistingDownloadMatch>{};
    for (final ExistingDownloadProbe item in items) {
      try {
        Future<ExistingDownloadMatch?> future = findExistingDownload(
          expectedFileName: item.expectedFileName,
          checksum: item.checksum,
          kind: item.kind,
        );
        final Duration? timeout = item.timeout;
        if (timeout != null) {
          future = future.timeout(timeout, onTimeout: () => null);
        }
        final ExistingDownloadMatch? match = await future;
        if (match != null) {
          map[item.key] = match;
        }
      } on Exception catch (_) {
        // Folder listing / hashing can fail; skip this item.
      }
    }
    return map;
  }

  /// Returns `true`/`false` when the file can be hashed, otherwise `null`.
  Future<bool?> _verifyChecksumStreaming(
    StoredOutputFile file,
    FileChecksum checksum, {
    AssetKind? kind,
  }) async {
    final String? path = file.localPath;
    if (path != null && path.isNotEmpty) {
      final File ioFile = File(path);
      if (ioFile.existsSync()) {
        try {
          return await checksum.matchesByteStream(ioFile.openRead());
        } on Exception {
          // Fall through to platform hashing when possible.
        }
      }
    }

    if (Platform.isAndroid && checksum.algorithm == FileChecksumAlgorithm.md5) {
      try {
        await loadSettings();
        final String? hex = await _channel.invokeMethod<String>('fileMd5', <String, String?>{
          'treeUri': _folder.androidTreeUriOrNull,
          'fileName': file.fileName,
          'relativeDir': _relativeDir(kind),
        });
        if (hex == null || hex.isEmpty) return null;
        return checksum.matchesHexDigest(hex);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  /// MediaStore / channel relative path under Downloads (`Zelp` or `Zelp/fw`).
  String _relativeDir(AssetKind? kind) {
    if (kind == null) return 'Zelp';
    return 'Zelp/${kind.folderName}';
  }

  Future<Directory> _resolveFilesystemDir({AssetKind? kind}) async {
    final Directory base;
    if (_folder.kind == OutputFolderKind.filesystem &&
        _folder.filesystemPath != null &&
        _folder.filesystemPath!.isNotEmpty) {
      base = Directory(_folder.filesystemPath!);
    } else {
      final Directory? downloads = await getDownloadsDirectory();
      final Directory root = downloads ?? await getApplicationDocumentsDirectory();
      base = Directory('${root.path}/Zelp');
    }
    if (kind == null) return base;
    return Directory('${base.path}/${kind.folderName}');
  }

  @Deprecated('Use saveFile')
  Future<SavedExport> saveEpoFile({
    required String fileName,
    required Uint8List bytes,
  }) => saveFile(fileName: fileName, bytes: bytes, kind: AssetKind.gps);

  Future<void> _ensureLegacyStoragePermission() async {
    if (!Platform.isAndroid) return;
    final PermissionStatus status = await Permission.storage.status;
    if (status.isGranted || status.isLimited) return;
    if (status.isDenied) {
      await Permission.storage.request();
    }
  }
}
