import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/services/gps_uihh.dart';

Uint8List _zipWith(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('buildGpsUihh', () {
    test('builds UIHH header and embeds required entries', () {
      final cep = _zipWith({
        'gps_alm.bin': utf8.encode('gps'),
        'gln_alm.bin': utf8.encode('gln'),
      });
      final lle = _zipWith({
        'lle_bds.lle': utf8.encode('bds'),
        'lle_gps.lle': utf8.encode('gpslle'),
        'lle_glo.lle': utf8.encode('glo'),
        'lle_gal.lle': utf8.encode('gal'),
        'lle_qzss.lle': utf8.encode('qzss'),
      });

      final out = buildGpsUihh(cep7daysZipBytes: cep, lle1weekZipBytes: lle);

      expect(utf8.decode(out.sublist(0, 4)), 'UIHH');
      expect(out.length, greaterThan(32));
      // Body should include embedded payloads.
      final asString = String.fromCharCodes(out);
      expect(asString.contains('gps'), isTrue);
      expect(asString.contains('qzss'), isTrue);
    });

    test('throws when a required zip entry is missing', () {
      final cep = _zipWith({
        'gps_alm.bin': [1],
      });
      final lle = _zipWith({
        'lle_bds.lle': [2],
      });
      expect(
        () => buildGpsUihh(cep7daysZipBytes: cep, lle1weekZipBytes: lle),
        throwsA(isA<StateError>()),
      );
    });

    test('header encodes little-endian body length after fixed fields', () {
      final cep = _zipWith({
        'gps_alm.bin': [1, 2],
        'gln_alm.bin': [3],
      });
      final lle = _zipWith({
        'lle_bds.lle': [4],
        'lle_gps.lle': [5],
        'lle_glo.lle': [6],
        'lle_gal.lle': [7],
        'lle_qzss.lle': [8],
      });
      final out = buildGpsUihh(cep7daysZipBytes: cep, lle1weekZipBytes: lle);
      expect(out.length, greaterThan(32));
      final bodyLength = out.length - 32;
      // Layout: UIHH(4) + flags(8) + crc(4) + pad(6) + bodyLen(4) + pad(6) = 32
      expect(out[22], bodyLength & 0xff);
      expect(out[23], (bodyLength >> 8) & 0xff);
      expect(out[24], (bodyLength >> 16) & 0xff);
      expect(out[25], (bodyLength >> 24) & 0xff);
    });
  });
}
