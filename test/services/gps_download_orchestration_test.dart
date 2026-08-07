import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/models/gps_file_type.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/output_folder_store.dart';
import 'package:zelp/services/zepp_client.dart';

import '../helpers/gps_zip_fixtures.dart';

Uint8List get _cepZip => cep7daysZip();

Uint8List get _lleZip => lle1weekZip();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory outDir;
  late DownloadStorage storage;
  late ZeppSession session;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    outDir = await Directory.systemTemp.createTemp('gps_orch_');
    final OutputFolderStore folderStore = OutputFolderStore(prefs: prefs);
    await folderStore.save(
      OutputFolder.normalized(
        kind: OutputFolderKind.filesystem,
        filesystemPath: outDir.path,
        displayName: outDir.path,
      ),
    );
    storage = DownloadStorage(folderStore: folderStore);
    session = ZeppSession.authenticated(
      username: 'user@example.com',
      password: 'x',
      appToken: 'app-token',
      userId: 'user-1',
      loginToken: 'login-token',
    );
  });

  tearDown(() async {
    if (outDir.existsSync()) await outDir.delete(recursive: true);
  });

  MockClient gpsMock({
    required bool includeAgpsZip,
    required bool includeLle,
    bool includeEpo = false,
  }) => MockClient((http.Request request) async {
    final String path = request.url.path;
    if (path.endsWith('/fileTypes/AGPSZIP/files') && includeAgpsZip) {
      return http.Response(
        jsonEncode(<Map<String, String>>[
          <String, String>{
            'fileUrl': 'https://cdn.example.test/files/cep_pack_cep_7days.zip',
          },
        ]),
        200,
      );
    }
    if (path.endsWith('/fileTypes/LLE/files') && includeLle) {
      return http.Response(
        jsonEncode(<Map<String, String>>[
          <String, String>{
            'fileUrl': 'https://cdn.example.test/files/lle_pack_lle_1week.zip',
          },
        ]),
        200,
      );
    }
    if (path.endsWith('/fileTypes/EPO/files') && includeEpo) {
      return http.Response(
        jsonEncode(<Map<String, String>>[
          <String, String>{'fileUrl': 'https://cdn.example.test/files/epo.bin'},
        ]),
        200,
      );
    }
    if (path.endsWith('cep_7days.zip')) {
      return http.Response.bytes(_cepZip, 200);
    }
    if (path.endsWith('lle_1week.zip')) {
      return http.Response.bytes(_lleZip, 200);
    }
    if (path.endsWith('epo.bin')) {
      return http.Response.bytes(Uint8List.fromList(<int>[1, 2, 3]), 200);
    }
    // Empty listing for unused types.
    if (path.contains('/fileTypes/')) {
      return http.Response('[]', 200);
    }
    return http.Response('missing', 404);
  });

  group('ZeppClient.downloadGpsFiles orchestration', () {
    test('UIHH-only exports gps_uihh.bin, not AGPSZIP/LLE zips', () async {
      final ZeppClient client = ZeppClient(
        session,
        httpClient: gpsMock(includeAgpsZip: true, includeLle: true),
      );
      addTearDown(client.close);

      final GpsDownloadResult result = await client.downloadGpsFiles(
        types: <GpsFileType>{},
        buildUihh: true,
        storage: storage,
      );

      final List<String> names = result.exports.map((SavedExport e) => e.fileName).toList();
      expect(names, <String>['gps_uihh.bin']);
      expect(File('${outDir.path}/gps/gps_uihh.bin').existsSync(), isTrue);
      expect(
        File('${outDir.path}/gps/cep_pack_cep_7days.zip').existsSync(),
        isFalse,
      );
      expect(
        File('${outDir.path}/gps/lle_pack_lle_1week.zip').existsSync(),
        isFalse,
      );
      expect(
        utf8.decode(
          File(
            '${outDir.path}/gps/gps_uihh.bin',
          ).readAsBytesSync().sublist(0, 4),
        ),
        'UIHH',
      );
    });

    test('explicit AGPSZIP+LLE with UIHH also exports the zips', () async {
      final ZeppClient client = ZeppClient(
        session,
        httpClient: gpsMock(includeAgpsZip: true, includeLle: true),
      );
      addTearDown(client.close);

      final GpsDownloadResult result = await client.downloadGpsFiles(
        types: <GpsFileType>{GpsFileType.agpsZip, GpsFileType.lle},
        buildUihh: true,
        storage: storage,
      );

      final Set<String> names = result.exports.map((SavedExport e) => e.fileName).toSet();
      expect(names, <String>{
        'cep_pack_cep_7days.zip',
        'lle_pack_lle_1week.zip',
        'gps_uihh.bin',
      });
    });

    test('selected EPO without UIHH exports only EPO', () async {
      final ZeppClient client = ZeppClient(
        session,
        httpClient: gpsMock(
          includeAgpsZip: false,
          includeLle: false,
          includeEpo: true,
        ),
      );
      addTearDown(client.close);

      final GpsDownloadResult result = await client.downloadGpsFiles(
        types: <GpsFileType>{GpsFileType.epo},
        storage: storage,
      );

      expect(result.exports.map((SavedExport e) => e.fileName), <String>['epo.bin']);
      expect(File('${outDir.path}/gps/epo.bin').readAsBytesSync(), <int>[1, 2, 3]);
    });

    test('rejects empty selection without UIHH before network', () async {
      final ZeppClient client = ZeppClient(
        session,
        httpClient: MockClient((_) async {
          fail('must not hit network for invalid plan');
        }),
      );
      addTearDown(client.close);

      await expectLater(
        () => client.downloadGpsFiles(
          types: <GpsFileType>{},
          storage: storage,
        ),
        throwsA(
          isA<Exception>().having(
            (Exception e) => e.toString(),
            'message',
            contains('Select at least one GPS'),
          ),
        ),
      );
    });

    test('UIHH warns when prerequisite payloads missing', () async {
      final ZeppClient client = ZeppClient(
        session,
        httpClient: gpsMock(
          includeAgpsZip: false,
          includeLle: false,
          includeEpo: true,
        ),
      );
      addTearDown(client.close);

      final GpsDownloadResult result = await client.downloadGpsFiles(
        types: <GpsFileType>{GpsFileType.epo},
        buildUihh: true,
        storage: storage,
      );

      expect(result.exports.map((SavedExport e) => e.fileName), <String>['epo.bin']);
      expect(
        result.warnings.any(
          (String w) => w.contains('UIHH') && w.contains('cep_7days'),
        ),
        isTrue,
      );
    });
  });
}
