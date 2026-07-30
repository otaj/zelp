import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds `gps_uihh.bin` from AGPSZIP (`*cep_7days.zip`) and LLE (`*lle_1week.zip`).
///
/// Port of `build_gps_uihh` from huami-token `helpers.py`.
Uint8List buildGpsUihh({
  required Uint8List cep7daysZipBytes,
  required Uint8List lle1weekZipBytes,
}) {
  const Map<String, int> entries = <String, int>{
    'gps_alm.bin': 0x05,
    'gln_alm.bin': 0x0f,
    'lle_bds.lle': 0x86,
    'lle_gps.lle': 0x87,
    'lle_glo.lle': 0x88,
    'lle_gal.lle': 0x89,
    'lle_qzss.lle': 0x8a,
  };

  final Archive cepArchive = ZipDecoder().decodeBytes(cep7daysZipBytes);
  final Archive lleArchive = ZipDecoder().decodeBytes(lle1weekZipBytes);

  ArchiveFile requireFile(Archive archive, String name) {
    final ArchiveFile? file = archive.findFile(name);
    if (file == null) {
      throw StateError('Missing $name inside GPS zip');
    }
    return file;
  }

  final BytesBuilder content = BytesBuilder();
  for (final MapEntry<String, int> entry in entries.entries) {
    final Archive archive = entry.value >= 0x86 ? lleArchive : cepArchive;
    final Uint8List fileContent = requireFile(archive, entry.key).content;
    content
      ..add(<int>[1, entry.value])
      ..add(_encodeUint32(fileContent.length))
      ..add(_encodeUint32(_crc32(fileContent)))
      ..add(fileContent);
  }

  final Uint8List body = content.toBytes();
  final BytesBuilder header = BytesBuilder()
    ..add('UIHH'.codeUnits)
    ..add(<int>[0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01])
    ..add(_encodeUint32(_crc32(body)))
    ..add(<int>[0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    ..add(_encodeUint32(body.length))
    ..add(<int>[0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);

  return Uint8List.fromList(<int>[...header.toBytes(), ...body]);
}

Uint8List _encodeUint32(int value) => Uint8List.fromList(<int>[
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
]);

int _crc32(List<int> data) => getCrc32(data) & 0xffffffff;
