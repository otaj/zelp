import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/models/gps_file_type.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/output_folder_store.dart';
import 'package:zelp/services/zepp_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _zipWith(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Uint8List get _cepZip => _zipWith({
  'gps_alm.bin': utf8.encode('gps'),
  'gln_alm.bin': utf8.encode('gln'),
});

Uint8List get _lleZip => _zipWith({
  'lle_bds.lle': utf8.encode('bds'),
  'lle_gps.lle': utf8.encode('gpslle'),
  'lle_glo.lle': utf8.encode('glo'),
  'lle_gal.lle': utf8.encode('gal'),
  'lle_qzss.lle': utf8.encode('qzss'),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory outDir;
  late DownloadStorage storage;
  late ZeppSession session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    outDir = await Directory.systemTemp.createTemp('gps_orch_');
    final folderStore = OutputFolderStore(prefs: prefs);
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
    if (await outDir.exists()) await outDir.delete(recursive: true);
  });

  MockClient gpsMock({
    required bool includeAgpsZip,
    required bool includeLle,
    bool includeEpo = false,
  }) {
    return MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/fileTypes/AGPSZIP/files') && includeAgpsZip) {
        return http.Response(
          jsonEncode([
            {
              'fileUrl':
                  'https://cdn.example.test/files/cep_pack_cep_7days.zip',
            },
          ]),
          200,
        );
      }
      if (path.endsWith('/fileTypes/LLE/files') && includeLle) {
        return http.Response(
          jsonEncode([
            {
              'fileUrl':
                  'https://cdn.example.test/files/lle_pack_lle_1week.zip',
            },
          ]),
          200,
        );
      }
      if (path.endsWith('/fileTypes/EPO/files') && includeEpo) {
        return http.Response(
          jsonEncode([
            {'fileUrl': 'https://cdn.example.test/files/epo.bin'},
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
        return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
      }
      // Empty listing for unused types.
      if (path.contains('/fileTypes/')) {
        return http.Response('[]', 200);
      }
      return http.Response('missing', 404);
    });
  }

  group('ZeppClient.downloadGpsFiles orchestration', () {
    test('UIHH-only exports gps_uihh.bin, not AGPSZIP/LLE zips', () async {
      final client = ZeppClient(
        session,
        httpClient: gpsMock(includeAgpsZip: true, includeLle: true),
      );
      addTearDown(client.close);

      final result = await client.downloadGpsFiles(
        types: {},
        buildUihh: true,
        storage: storage,
      );

      final names = result.exports.map((e) => e.fileName).toList();
      expect(names, ['gps_uihh.bin']);
      expect(File('${outDir.path}/gps_uihh.bin').existsSync(), isTrue);
      expect(
        File('${outDir.path}/cep_pack_cep_7days.zip').existsSync(),
        isFalse,
      );
      expect(
        File('${outDir.path}/lle_pack_lle_1week.zip').existsSync(),
        isFalse,
      );
      expect(
        utf8.decode(
          File('${outDir.path}/gps_uihh.bin').readAsBytesSync().sublist(0, 4),
        ),
        'UIHH',
      );
    });

    test('explicit AGPSZIP+LLE with UIHH also exports the zips', () async {
      final client = ZeppClient(
        session,
        httpClient: gpsMock(includeAgpsZip: true, includeLle: true),
      );
      addTearDown(client.close);

      final result = await client.downloadGpsFiles(
        types: {GpsFileType.agpsZip, GpsFileType.lle},
        buildUihh: true,
        storage: storage,
      );

      final names = result.exports.map((e) => e.fileName).toSet();
      expect(names, {
        'cep_pack_cep_7days.zip',
        'lle_pack_lle_1week.zip',
        'gps_uihh.bin',
      });
    });

    test('selected EPO without UIHH exports only EPO', () async {
      final client = ZeppClient(
        session,
        httpClient: gpsMock(
          includeAgpsZip: false,
          includeLle: false,
          includeEpo: true,
        ),
      );
      addTearDown(client.close);

      final result = await client.downloadGpsFiles(
        types: {GpsFileType.epo},
        buildUihh: false,
        storage: storage,
      );

      expect(result.exports.map((e) => e.fileName), ['epo.bin']);
      expect(File('${outDir.path}/epo.bin').readAsBytesSync(), [1, 2, 3]);
    });

    test('rejects empty selection without UIHH before network', () async {
      final client = ZeppClient(
        session,
        httpClient: MockClient((_) async {
          fail('must not hit network for invalid plan');
        }),
      );
      addTearDown(client.close);

      await expectLater(
        () => client.downloadGpsFiles(
          types: {},
          buildUihh: false,
          storage: storage,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Select at least one GPS'),
          ),
        ),
      );
    });

    test('UIHH warns when prerequisite payloads missing', () async {
      final client = ZeppClient(
        session,
        httpClient: gpsMock(
          includeAgpsZip: false,
          includeLle: false,
          includeEpo: true,
        ),
      );
      addTearDown(client.close);

      final result = await client.downloadGpsFiles(
        types: {GpsFileType.epo},
        buildUihh: true,
        storage: storage,
      );

      expect(result.exports.map((e) => e.fileName), ['epo.bin']);
      expect(
        result.warnings.any(
          (w) => w.contains('UIHH') && w.contains('cep_7days'),
        ),
        isTrue,
      );
    });
  });
}
