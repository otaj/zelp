import 'package:zelp/domain/gps/gps_file_type.dart';

/// Resolves which GPS types to fetch vs publicly export.
///
/// UIHH prerequisites (AGPSZIP / LLE) are fetched only into memory when
/// [buildUihh] is true; they are exported only if the user also selected them.
class GpsDownloadPlan {
  GpsDownloadPlan({required Set<GpsFileType> selected, required this.buildUihh})
    : selected = Set<GpsFileType>.unmodifiable(selected) {
    if (selected.isEmpty && !buildUihh) {
      throw ArgumentError('Select at least one GPS file type or enable UIHH');
    }
  }

  final Set<GpsFileType> selected;
  final bool buildUihh;

  /// Types requested from the Zepp API (includes private UIHH prerequisites).
  Set<GpsFileType> get fetchTypes {
    final Set<GpsFileType> types = <GpsFileType>{...selected};
    if (buildUihh) {
      types
        ..add(GpsFileType.agpsZip)
        ..add(GpsFileType.lle);
    }
    return types;
  }

  /// Types written to the user-visible output folder.
  Set<GpsFileType> get exportTypes => selected;

  bool shouldExport(GpsFileType type) => exportTypes.contains(type);

  bool get exportsUihh => buildUihh;
}
