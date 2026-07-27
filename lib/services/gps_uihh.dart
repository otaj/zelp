import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds `gps_uihh.bin` from AGPSZIP (`*cep_7days.zip`) and LLE (`*lle_1week.zip`).
///
/// Port of `build_gps_uihh` from huami-token `helpers.py`.
Uint8List buildGpsUihh({
  required Uint8List cep7daysZipBytes,
  required Uint8List lle1weekZipBytes,
}) {
  const entries = <String, int>{
    'gps_alm.bin': 0x05,
    'gln_alm.bin': 0x0f,
    'lle_bds.lle': 0x86,
    'lle_gps.lle': 0x87,
    'lle_glo.lle': 0x88,
    'lle_gal.lle': 0x89,
    'lle_qzss.lle': 0x8a,
  };

  final cepArchive = ZipDecoder().decodeBytes(cep7daysZipBytes);
  final lleArchive = ZipDecoder().decodeBytes(lle1weekZipBytes);

  ArchiveFile requireFile(Archive archive, String name) {
    final file = archive.findFile(name);
    if (file == null) {
      throw StateError('Missing $name inside GPS zip');
    }
    return file;
  }

  final content = BytesBuilder();
  for (final entry in entries.entries) {
    final archive = entry.value >= 0x86 ? lleArchive : cepArchive;
    final fileContent = requireFile(archive, entry.key).content;
    content.add([1, entry.value]);
    content.add(_encodeUint32(fileContent.length));
    content.add(_encodeUint32(_crc32(fileContent)));
    content.add(fileContent);
  }

  final body = content.toBytes();
  final header = BytesBuilder()
    ..add('UIHH'.codeUnits)
    ..add([0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01])
    ..add(_encodeUint32(_crc32(body)))
    ..add([0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    ..add(_encodeUint32(body.length))
    ..add([0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);

  return Uint8List.fromList([...header.toBytes(), ...body]);
}

Uint8List _encodeUint32(int value) {
  return Uint8List.fromList([
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ]);
}

int _crc32(List<int> data) => getCrc32(data) & 0xffffffff;
