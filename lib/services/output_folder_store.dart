import 'package:shared_preferences/shared_preferences.dart';

import '../domain/output/output_folder.dart';

/// Persists [OutputFolder] choice in SharedPreferences.
class OutputFolderStore {
  OutputFolderStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const prefsKind = 'output_folder_kind';
  static const prefsTreeUri = 'output_folder_tree_uri';
  static const prefsPath = 'output_folder_path';
  static const prefsDisplay = 'output_folder_display';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();
  }

  Future<OutputFolder> load() async {
    final prefs = await _ensurePrefs();
    final kindName = prefs.getString(prefsKind);
    var kind = OutputFolderKind.defaults;
    for (final candidate in OutputFolderKind.values) {
      if (candidate.name == kindName) {
        kind = candidate;
        break;
      }
    }
    return OutputFolder.normalized(
      kind: kind,
      treeUri: prefs.getString(prefsTreeUri),
      filesystemPath: prefs.getString(prefsPath),
      displayName: prefs.getString(prefsDisplay),
    );
  }

  Future<void> save(OutputFolder folder) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(prefsKind, folder.kind.name);
    if (folder.treeUri != null) {
      await prefs.setString(prefsTreeUri, folder.treeUri!);
    } else {
      await prefs.remove(prefsTreeUri);
    }
    if (folder.filesystemPath != null) {
      await prefs.setString(prefsPath, folder.filesystemPath!);
    } else {
      await prefs.remove(prefsPath);
    }
    if (folder.displayName != null) {
      await prefs.setString(prefsDisplay, folder.displayName!);
    } else {
      await prefs.remove(prefsDisplay);
    }
  }

  Future<void> reset() => save(OutputFolder.defaults);
}
