import 'package:shared_preferences/shared_preferences.dart';

import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/services/prefs_store.dart';

/// Persists [OutputFolder] choice in SharedPreferences.
class OutputFolderStore extends PrefsStore {
  OutputFolderStore({super.prefs});

  static const String prefsKind = 'output_folder_kind';
  static const String prefsTreeUri = 'output_folder_tree_uri';
  static const String prefsPath = 'output_folder_path';
  static const String prefsDisplay = 'output_folder_display';
  static const String prefsSplitByType = 'output_split_by_type';
  static const String prefsSemanticNames = 'output_semantic_names';

  /// Default: organize downloads into type subfolders (`fw`, `apps`, …).
  static const bool defaultSplitByType = true;

  /// Default: keep CDN / API basenames instead of name+version filenames.
  static const bool defaultSemanticNames = false;

  Future<OutputFolder> load() async {
    final SharedPreferences prefs = await ensurePrefs();
    final String? kindName = prefs.getString(prefsKind);
    OutputFolderKind kind = OutputFolderKind.defaults;
    for (final OutputFolderKind candidate in OutputFolderKind.values) {
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
    final SharedPreferences prefs = await ensurePrefs();
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

  Future<bool> loadSplitByType() async {
    final SharedPreferences prefs = await ensurePrefs();
    return prefs.getBool(prefsSplitByType) ?? defaultSplitByType;
  }

  Future<void> saveSplitByType({required bool enabled}) async {
    final SharedPreferences prefs = await ensurePrefs();
    await prefs.setBool(prefsSplitByType, enabled);
  }

  Future<bool> loadSemanticNames() async {
    final SharedPreferences prefs = await ensurePrefs();
    return prefs.getBool(prefsSemanticNames) ?? defaultSemanticNames;
  }

  Future<void> saveSemanticNames({required bool enabled}) async {
    final SharedPreferences prefs = await ensurePrefs();
    await prefs.setBool(prefsSemanticNames, enabled);
  }

  Future<void> reset() => save(OutputFolder.defaults);
}
