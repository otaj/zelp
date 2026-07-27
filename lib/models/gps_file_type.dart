import '../domain/output/saved_export.dart';

/// GPS assistance file kinds supported by huami-token / Zepp.
enum GpsFileType {
  agpsAlm(
    apiName: 'AGPS_ALM',
    label: 'AGPS ALM',
    description: 'Almanac assistance data from Zepp',
  ),
  agpsZip(
    apiName: 'AGPSZIP',
    label: 'AGPS ZIP',
    description: 'CEP package; includes cep_7days.zip (UIHH input)',
  ),
  lle(
    apiName: 'LLE',
    label: 'LLE',
    description: 'Long-term ephemeris; includes lle_1week.zip (UIHH input)',
  ),
  agps(apiName: 'AGPS', label: 'AGPS', description: 'AGPS assistance data'),
  epo(
    apiName: 'EPO',
    label: 'EPO',
    description: 'Extended prediction orbit files',
  ),
  lto(apiName: 'LTO', label: 'LTO', description: 'Long-term orbit data');

  const GpsFileType({
    required this.apiName,
    required this.label,
    required this.description,
  });

  final String apiName;
  final String label;
  final String description;

  static const apiOrder = [
    GpsFileType.agpsAlm,
    GpsFileType.agpsZip,
    GpsFileType.lle,
    GpsFileType.agps,
    GpsFileType.epo,
    GpsFileType.lto,
  ];
}

/// Result of a GPS download / UIHH build.
class GpsDownloadResult {
  const GpsDownloadResult({required this.exports, this.warnings = const []});

  final List<SavedExport> exports;
  final List<String> warnings;

  List<String> get savedPaths =>
      exports.map((e) => e.displayPath).toList(growable: false);
}
