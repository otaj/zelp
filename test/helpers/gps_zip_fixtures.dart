import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds an in-memory zip from [files] (path → bytes).
Uint8List zipWith(Map<String, List<int>> files) {
  final Archive archive = Archive();
  for (final MapEntry<String, List<int>> entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// Minimal CEP AGPSZIP fixture used by GPS UIHH / download tests.
Uint8List cep7daysZip({
  List<int>? gps,
  List<int>? gln,
}) => zipWith(<String, List<int>>{
  'gps_alm.bin': gps ?? utf8.encode('gps'),
  'gln_alm.bin': gln ?? utf8.encode('gln'),
});

/// Minimal LLE 1-week fixture used by GPS UIHH / download tests.
Uint8List lle1weekZip({
  List<int>? bds,
  List<int>? gps,
  List<int>? glo,
  List<int>? gal,
  List<int>? qzss,
}) => zipWith(<String, List<int>>{
  'lle_bds.lle': bds ?? utf8.encode('bds'),
  'lle_gps.lle': gps ?? utf8.encode('gpslle'),
  'lle_glo.lle': glo ?? utf8.encode('glo'),
  'lle_gal.lle': gal ?? utf8.encode('gal'),
  'lle_qzss.lle': qzss ?? utf8.encode('qzss'),
});
