import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/gps/gps_download_plan.dart';
import 'package:zelp/domain/gps/gps_payload_finder.dart';
import 'package:zelp/models/gps_file_type.dart';

void main() {
  group('GpsDownloadPlan', () {
    test('rejects empty selection without UIHH', () {
      expect(
        () => GpsDownloadPlan(selected: <GpsFileType>{}, buildUihh: false),
        throwsArgumentError,
      );
    });

    test('UIHH-only fetches AGPSZIP+LLE privately, exports none of them', () {
      final GpsDownloadPlan plan = GpsDownloadPlan(selected: <GpsFileType>{}, buildUihh: true);
      expect(plan.fetchTypes, <GpsFileType>{GpsFileType.agpsZip, GpsFileType.lle});
      expect(plan.exportTypes, isEmpty);
      expect(plan.shouldExport(GpsFileType.agpsZip), isFalse);
      expect(plan.exportsUihh, isTrue);
    });

    test('selected types are exported; UIHH adds private fetch only', () {
      final GpsDownloadPlan plan = GpsDownloadPlan(
        selected: <GpsFileType>{GpsFileType.epo},
        buildUihh: true,
      );
      expect(plan.fetchTypes, <GpsFileType>{
        GpsFileType.epo,
        GpsFileType.agpsZip,
        GpsFileType.lle,
      });
      expect(plan.exportTypes, <GpsFileType>{GpsFileType.epo});
      expect(plan.shouldExport(GpsFileType.epo), isTrue);
      expect(plan.shouldExport(GpsFileType.lle), isFalse);
    });

    test('explicit AGPSZIP+LLE with UIHH exports those zips too', () {
      final GpsDownloadPlan plan = GpsDownloadPlan(
        selected: <GpsFileType>{GpsFileType.agpsZip, GpsFileType.lle},
        buildUihh: true,
      );
      expect(plan.shouldExport(GpsFileType.agpsZip), isTrue);
      expect(plan.shouldExport(GpsFileType.lle), isTrue);
    });

    test('without UIHH fetch and export are exactly the selection', () {
      final GpsDownloadPlan plan = GpsDownloadPlan(
        selected: <GpsFileType>{GpsFileType.epo, GpsFileType.lto},
        buildUihh: false,
      );
      expect(plan.fetchTypes, <GpsFileType>{GpsFileType.epo, GpsFileType.lto});
      expect(plan.exportTypes, <GpsFileType>{GpsFileType.epo, GpsFileType.lto});
      expect(plan.exportsUihh, isFalse);
      expect(plan.shouldExport(GpsFileType.agpsZip), isFalse);
    });

    test('selected set is unmodifiable', () {
      final GpsDownloadPlan plan = GpsDownloadPlan(
        selected: <GpsFileType>{GpsFileType.agps},
        buildUihh: false,
      );
      expect(() => plan.selected.add(GpsFileType.epo), throwsUnsupportedError);
    });
  });

  group('GpsFileType', () {
    test('apiOrder covers every enum value exactly once', () {
      expect(GpsFileType.apiOrder.toSet(), GpsFileType.values.toSet());
      expect(GpsFileType.apiOrder.length, GpsFileType.values.length);
      expect(
        GpsFileType.values.map((GpsFileType t) => t.apiName).toSet().length,
        GpsFileType.values.length,
      );
    });
  });

  group('findNamedGpsPayload', () {
    test('returns first matching name substring', () {
      final List<({Uint8List bytes, String fileName})> files = <({Uint8List bytes, String fileName})>[
        (fileName: 'other.zip', bytes: Uint8List.fromList(<int>[1])),
        (fileName: 'x_cep_7days.zip', bytes: Uint8List.fromList(<int>[2, 3])),
      ];
      expect(findNamedGpsPayload(files, 'cep_7days'), <int>[2, 3]);
    });

    test('returns null when missing', () {
      expect(findNamedGpsPayload(null, 'cep_7days'), isNull);
      expect(
        findNamedGpsPayload(<({Uint8List bytes, String fileName})>[
          (fileName: 'a.zip', bytes: Uint8List(0)),
        ], 'cep_7days'),
        isNull,
      );
    });
  });
}
