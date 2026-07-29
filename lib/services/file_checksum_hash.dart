import 'package:crypto/crypto.dart';

import 'package:zelp/domain/output/existing_download.dart';

/// MD5 helpers for [FileChecksum] (kept out of domain for purity).
extension FileChecksumHash on FileChecksum {
  bool matchesBytes(List<int> bytes) {
    switch (algorithm) {
      case FileChecksumAlgorithm.md5:
        return md5.convert(bytes).toString() == hex;
    }
  }

  /// Streaming compare — safe for large firmware binaries (no full-buffer load).
  Future<bool> matchesByteStream(Stream<List<int>> stream) async {
    switch (algorithm) {
      case FileChecksumAlgorithm.md5:
        final digest = await md5.bind(stream).single;
        return digest.toString() == hex;
    }
  }
}

String md5HexOf(List<int> bytes) => md5.convert(bytes).toString();
