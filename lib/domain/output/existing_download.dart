/// Checksum supplied by the Zepp/Huami API for a downloadable file.
///
/// Only constructed when the API provides a value — callers must not invent
/// checksums when the field is absent.
///
/// Hashing (`package:crypto`) lives in services; this type stays pure Dart.
class FileChecksum {
  const FileChecksum.md5(this.hex) : algorithm = FileChecksumAlgorithm.md5;

  final FileChecksumAlgorithm algorithm;
  final String hex;

  /// Parses known API field shapes (hex MD5). Returns null if blank/unknown.
  static FileChecksum? tryParseMd5(Object? raw) {
    if (raw == null) return null;
    final value = raw.toString().trim().toLowerCase();
    if (value.isEmpty || value == 'null' || value == '0') return null;
    final hex = value.replaceAll(RegExp(r'[^0-9a-f]'), '');
    if (hex.length != 32) return null;
    return FileChecksum.md5(hex);
  }

  /// Compares against an already-computed lowercase/uppercase hex digest.
  bool matchesHexDigest(String digest) {
    final normalized = digest.trim().toLowerCase();
    return normalized.isNotEmpty && normalized == hex.toLowerCase();
  }

  @override
  bool operator ==(Object other) =>
      other is FileChecksum && other.algorithm == algorithm && other.hex == hex;

  @override
  int get hashCode => Object.hash(algorithm, hex);

  @override
  String toString() => '${algorithm.name}:$hex';
}

enum FileChecksumAlgorithm { md5 }

/// A file already present in the configured output folder.
class StoredOutputFile {
  const StoredOutputFile({
    required this.fileName,
    required this.displayPath,
    this.localPath,
  });

  final String fileName;
  final String displayPath;
  final String? localPath;
}

/// Result of checking whether a remote download is already on disk.
class ExistingDownloadMatch {
  const ExistingDownloadMatch({
    required this.file,
    required this.matchedByChecksum,
  });

  final StoredOutputFile file;

  /// True when an API checksum matched file bytes; false when filename-only.
  final bool matchedByChecksum;
}

/// Pure matching logic (no I/O, no hashing libraries).
///
/// - Without [checksum]: filename presence only — never invent hashing.
/// - With [checksum]: prefer a byte match (expected name first, then scan).
///   Callers supply [bytesMatch] (e.g. MD5 via services) for verification.
ExistingDownloadMatch? matchExistingDownload({
  required String expectedFileName,
  FileChecksum? checksum,
  required Map<String, StoredOutputFile> filesByName,
  required Map<String, List<int>> Function(Iterable<String> names) readBytes,
  bool Function(List<int> bytes)? bytesMatch,
}) {
  final expected = expectedFileName.trim();
  if (expected.isEmpty) return null;

  if (checksum == null) {
    final byName = filesByName[expected];
    if (byName == null) return null;
    return ExistingDownloadMatch(file: byName, matchedByChecksum: false);
  }

  final matchBytes = bytesMatch;
  if (matchBytes == null) {
    throw ArgumentError('bytesMatch is required when checksum is provided');
  }

  // Prefer hashing the expected filename when it exists.
  if (filesByName.containsKey(expected)) {
    final bytes = readBytes([expected])[expected];
    if (bytes != null && matchBytes(bytes)) {
      return ExistingDownloadMatch(
        file: filesByName[expected]!,
        matchedByChecksum: true,
      );
    }
    // Bytes missing or mismatch — keep scanning for a rename.
  }

  // Scan other files for a checksum match (handles slight rename differences).
  final others = filesByName.keys.where((n) => n != expected);
  if (others.isEmpty) return null;
  final bytesMap = readBytes(others);
  for (final entry in bytesMap.entries) {
    if (matchBytes(entry.value)) {
      return ExistingDownloadMatch(
        file: filesByName[entry.key]!,
        matchedByChecksum: true,
      );
    }
  }
  return null;
}
