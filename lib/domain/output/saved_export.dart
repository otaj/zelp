/// A file written to the user-visible output folder, with a local path for sharing.
class SavedExport {
  const SavedExport({
    required this.fileName,
    required this.displayPath,
    required this.localPath,
  });

  final String fileName;

  /// Path shown to the user (MediaStore/SAF display path or absolute path).
  final String displayPath;

  /// Absolute filesystem path usable with share_plus / FileProvider.
  final String localPath;
}
