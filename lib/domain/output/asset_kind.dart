/// Kind of downloadable asset — maps to a subfolder under the output root.
enum AssetKind {
  firmware,
  app,
  watchface,
  gps;

  /// Subfolder name under Downloads/Zelp (or the user-picked folder).
  String get folderName => switch (this) {
    AssetKind.firmware => 'fw',
    AssetKind.app => 'apps',
    AssetKind.watchface => 'watchfaces',
    AssetKind.gps => 'gps',
  };
}
