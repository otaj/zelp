/// Where exported GPS (and related) files are written.
enum OutputFolderKind {
  /// Android Downloads/Zelp or desktop ~/Downloads/Zelp.
  defaults,

  /// Android SAF tree URI (persistable).
  androidTree,

  /// Absolute filesystem directory.
  filesystem,
}

/// User-chosen export destination (value object).
class OutputFolder {
  const OutputFolder({
    required this.kind,
    this.treeUri,
    this.filesystemPath,
    this.displayName,
  });

  final OutputFolderKind kind;
  final String? treeUri;
  final String? filesystemPath;
  final String? displayName;

  static const defaults = OutputFolder(kind: OutputFolderKind.defaults);

  static const defaultLabel = 'Downloads/Zelp';

  /// Normalizes incomplete custom folders back to [defaults].
  factory OutputFolder.normalized({
    required OutputFolderKind kind,
    String? treeUri,
    String? filesystemPath,
    String? displayName,
  }) {
    if (kind == OutputFolderKind.androidTree &&
        (treeUri == null || treeUri.isEmpty)) {
      return defaults;
    }
    if (kind == OutputFolderKind.filesystem &&
        (filesystemPath == null || filesystemPath.isEmpty)) {
      return defaults;
    }
    return OutputFolder(
      kind: kind,
      treeUri: treeUri,
      filesystemPath: filesystemPath,
      displayName: displayName,
    );
  }

  String get label {
    switch (kind) {
      case OutputFolderKind.defaults:
        return defaultLabel;
      case OutputFolderKind.androidTree:
        return displayName ?? 'Selected folder';
      case OutputFolderKind.filesystem:
        return filesystemPath ?? displayName ?? 'Selected folder';
    }
  }

  /// SAF tree URI when using [OutputFolderKind.androidTree], otherwise null
  /// (native code treats null as the default Downloads/Zelp folder).
  String? get androidTreeUriOrNull =>
      kind == OutputFolderKind.androidTree ? treeUri : null;

  @override
  bool operator ==(Object other) =>
      other is OutputFolder &&
      other.kind == kind &&
      other.treeUri == treeUri &&
      other.filesystemPath == filesystemPath &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(kind, treeUri, filesystemPath, displayName);
}

/// Confirmation copy for clearing the output folder.
class ClearFolderWarning {
  const ClearFolderWarning(this.fileCount);

  final int fileCount;

  bool get shouldConfirm => fileCount > 0;

  /// Exact user-facing dialog body when files would be deleted.
  String get message {
    if (fileCount <= 0) {
      return 'This folder is empty.';
    }
    final noun = fileCount == 1 ? 'file' : 'files';
    return 'This folder contains $fileCount $noun. Delete them?';
  }
}
