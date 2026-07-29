/// Kind of downloadable asset — maps to a subfolder under the output root.
///
/// Pairing-key exports are short text and stay at the output-folder root
/// (no [AssetKind]).
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
