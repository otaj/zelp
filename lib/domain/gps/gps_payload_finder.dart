import 'dart:typed_data';

/// Finds the first GPS payload whose file name contains [needle].
Uint8List? findNamedGpsPayload(
  List<({String fileName, Uint8List bytes})>? files,
  String needle,
) {
  if (files == null) return null;
  for (final ({Uint8List bytes, String fileName}) file in files) {
    if (file.fileName.contains(needle)) return file.bytes;
  }
  return null;
}
