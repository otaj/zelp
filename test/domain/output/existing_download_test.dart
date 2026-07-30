import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/services/file_checksum_hash.dart';

void main() {
  group('FileChecksum', () {
    test('tryParseMd5 accepts hex and rejects junk', () {
      expect(
        FileChecksum.tryParseMd5('098f6bcd4621d373cade4e832627b4f6')?.hex,
        '098f6bcd4621d373cade4e832627b4f6',
      );
      expect(FileChecksum.tryParseMd5(null), isNull);
      expect(FileChecksum.tryParseMd5(''), isNull);
      expect(FileChecksum.tryParseMd5('not-a-hash'), isNull);
      // API sometimes sends sentinel / placeholder values.
      expect(FileChecksum.tryParseMd5('null'), isNull);
      expect(FileChecksum.tryParseMd5('0'), isNull);
      expect(FileChecksum.tryParseMd5('NULL'), isNull);
    });

    test('tryParseMd5 strips separators and lowercases', () {
      expect(
        FileChecksum.tryParseMd5('098F6BCD-4621-D373-CADE-4E832627B4F6')?.hex,
        '098f6bcd4621d373cade4e832627b4f6',
      );
      expect(
        FileChecksum.tryParseMd5('098f6bcd4621d373cade4e832627b4f6ff'),
        isNull,
      );
    });

    test('matchesBytes for known md5 of "test"', () {
      final FileChecksum checksum = FileChecksum.tryParseMd5(
        '098f6bcd4621d373cade4e832627b4f6',
      )!;
      expect(
        checksum.matchesBytes(Uint8List.fromList('test'.codeUnits)),
        isTrue,
      );
      expect(
        checksum.matchesBytes(Uint8List.fromList('other'.codeUnits)),
        isFalse,
      );
    });

    test('matchesByteStream for known md5 of "test"', () async {
      final FileChecksum checksum = FileChecksum.tryParseMd5(
        '098f6bcd4621d373cade4e832627b4f6',
      )!;
      expect(
        await checksum.matchesByteStream(
          Stream<Uint8List>.value(Uint8List.fromList('test'.codeUnits)),
        ),
        isTrue,
      );
      expect(
        await checksum.matchesByteStream(
          Stream<Uint8List>.value(Uint8List.fromList('other'.codeUnits)),
        ),
        isFalse,
      );
    });
  });

  group('matchExistingDownload', () {
    StoredOutputFile file(String name) => StoredOutputFile(
      fileName: name,
      displayPath: '/out/$name',
      localPath: '/out/$name',
    );

    test('without checksum uses filename only', () {
      final ExistingDownloadMatch? match = matchExistingDownload(
        expectedFileName: 'fw.bin',
        filesByName: <String, StoredOutputFile>{'fw.bin': file('fw.bin'), 'other.bin': file('other.bin')},
        readBytes: (_) => throw StateError('must not hash without checksum'),
      );
      expect(match, isNotNull);
      expect(match!.matchedByChecksum, isFalse);
      expect(match.file.fileName, 'fw.bin');
    });

    test('without checksum returns null when filename missing', () {
      final ExistingDownloadMatch? match = matchExistingDownload(
        expectedFileName: 'fw.bin',
        filesByName: <String, StoredOutputFile>{'other.bin': file('other.bin')},
        readBytes: (_) => const <String, List<int>>{},
      );
      expect(match, isNull);
    });

    test('with checksum matches expected filename bytes', () {
      const FileChecksum checksum = FileChecksum.md5('098f6bcd4621d373cade4e832627b4f6');
      final ExistingDownloadMatch? match = matchExistingDownload(
        expectedFileName: 'fw.bin',
        checksum: checksum,
        filesByName: <String, StoredOutputFile>{'fw.bin': file('fw.bin')},
        readBytes: (_) => <String, List<int>>{'fw.bin': Uint8List.fromList('test'.codeUnits)},
        bytesMatch: checksum.matchesBytes,
      );
      expect(match!.matchedByChecksum, isTrue);
      expect(match.file.fileName, 'fw.bin');
    });

    test('with checksum returns null when expected bytes unavailable', () {
      const FileChecksum checksum = FileChecksum.md5('098f6bcd4621d373cade4e832627b4f6');
      final ExistingDownloadMatch? match = matchExistingDownload(
        expectedFileName: 'fw.bin',
        checksum: checksum,
        filesByName: <String, StoredOutputFile>{'fw.bin': file('fw.bin')},
        readBytes: (_) => const <String, List<int>>{},
        bytesMatch: checksum.matchesBytes,
      );
      expect(match, isNull);
    });

    test('matchesHexDigest is case-insensitive', () {
      const FileChecksum checksum = FileChecksum.md5('098f6bcd4621d373cade4e832627b4f6');
      expect(
        checksum.matchesHexDigest('098F6BCD4621D373CADE4E832627B4F6'),
        isTrue,
      );
      expect(checksum.matchesHexDigest('deadbeef'), isFalse);
    });

    test('with checksum scans other names when expected missing', () {
      const FileChecksum checksum = FileChecksum.md5('098f6bcd4621d373cade4e832627b4f6');
      final ExistingDownloadMatch? match = matchExistingDownload(
        expectedFileName: 'expected.bin',
        checksum: checksum,
        filesByName: <String, StoredOutputFile>{'renamed.bin': file('renamed.bin')},
        readBytes: (_) => <String, List<int>>{'renamed.bin': Uint8List.fromList('test'.codeUnits)},
        bytesMatch: checksum.matchesBytes,
      );
      expect(match!.file.fileName, 'renamed.bin');
      expect(match.matchedByChecksum, isTrue);
    });

    test('with checksum scans others when expected name mismatches', () {
      const FileChecksum checksum = FileChecksum.md5('098f6bcd4621d373cade4e832627b4f6');
      final ExistingDownloadMatch? match = matchExistingDownload(
        expectedFileName: 'fw.bin',
        checksum: checksum,
        filesByName: <String, StoredOutputFile>{
          'fw.bin': file('fw.bin'),
          'renamed.bin': file('renamed.bin'),
        },
        readBytes: (Iterable<String> names) {
          final Map<String, List<int>> map = <String, List<int>>{};
          for (final String name in names) {
            if (name == 'fw.bin') {
              map[name] = Uint8List.fromList('wrong'.codeUnits);
            } else if (name == 'renamed.bin') {
              map[name] = Uint8List.fromList('test'.codeUnits);
            }
          }
          return map;
        },
        bytesMatch: checksum.matchesBytes,
      );
      expect(match!.file.fileName, 'renamed.bin');
      expect(match.matchedByChecksum, isTrue);
    });

    test('with checksum returns null when no file matches', () {
      const FileChecksum checksum = FileChecksum.md5('098f6bcd4621d373cade4e832627b4f6');
      final ExistingDownloadMatch? match = matchExistingDownload(
        expectedFileName: 'fw.bin',
        checksum: checksum,
        filesByName: <String, StoredOutputFile>{'fw.bin': file('fw.bin'), 'other.bin': file('other.bin')},
        readBytes: (_) => <String, List<int>>{
          'fw.bin': Uint8List.fromList('wrong'.codeUnits),
          'other.bin': Uint8List.fromList('also-wrong'.codeUnits),
        },
        bytesMatch: checksum.matchesBytes,
      );
      expect(match, isNull);
    });

    test('blank expected filename returns null', () {
      expect(
        matchExistingDownload(
          expectedFileName: '  ',
          filesByName: <String, StoredOutputFile>{'fw.bin': file('fw.bin')},
          readBytes: (_) => const <String, List<int>>{},
        ),
        isNull,
      );
    });
  });
}
