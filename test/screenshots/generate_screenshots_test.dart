import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/firmware_check_screen.dart';
import 'package:zelp/screens/gps_files_screen.dart';
import 'package:zelp/screens/settings_screen.dart';
import 'package:zelp/services/credential_store.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/firmware_store.dart';
import 'package:zelp/services/output_folder_store.dart';
import 'package:zelp/services/zepp_version_client.dart';

/// Phone-ish logical size (≈ Pixel 7 @ 2.625 DPR → 1080×2400).
const Size _phoneLogical = Size(411, 914);
const double _dpr = 2.625;

/// Enable with `--dart-define=GENERATE_SCREENSHOTS=true --update-goldens`.
const bool _generate = bool.fromEnvironment('GENERATE_SCREENSHOTS');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadMaterialFonts();
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('01 setup', (WidgetTester tester) async {
    await _prepare(tester);
    await _capture(
      tester,
      '01_setup',
      const SettingsScreen(isFirstTimeSetup: true),
    );
  }, skip: !_generate);

  testWidgets('02 firmware', (WidgetTester tester) async {
    await _prepare(tester);
    final StoredFirmwareHistory history = StoredFirmwareHistory(
      deviceId: 'gtr4',
      watchName: 'GTR 4',
      deviceSource: 229,
      checkedAt: DateTime.utc(2026, 8, 1, 12),
      versions: <FirmwareInfo>[
        FirmwareInfo(
          firmwareVersion: '3.22.0.1',
          firmwareUrl: 'https://cdn.example/fw-3.22.bin',
          firmwareSize: 42 * 1024 * 1024,
          changeLog: 'Stability improvements.',
        ),
        FirmwareInfo(
          firmwareVersion: '3.23.4.1',
          firmwareUrl: 'https://cdn.example/fw-3.23.bin',
          firmwareSize: 45 * 1024 * 1024,
          changeLog: 'Improved GPS accuracy and battery life.',
        ),
      ],
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'firmware_history_v2': jsonEncode(<String, dynamic>{
        StoredFirmwareHistory.storageKey('gtr4', 229): history.toJson(),
      }),
      'zepp_play_version': '9.12.0-play_1',
      'zepp_play_version_checked_at': '2026-08-01T12:00:00.000Z',
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
    await usage.touchWatch('gtr4', at: DateTime.utc(2026, 8));
    final DownloadStorage downloads = await _filesystemDownloads(tester, prefs);

    await _capture(
      tester,
      '02_firmware',
      FirmwareCheckScreen(
        catalog: _seedCatalog(),
        versionClient: _seedVersions(prefs),
        firmwareStore: FirmwareStore(prefs: prefs),
        deviceUsageStore: usage,
        downloadStorage: downloads,
      ),
      settleMs: 250,
    );
  }, skip: !_generate);

  testWidgets('03 gps', (WidgetTester tester) async {
    await _prepare(tester);
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'amazfit_email': 'demo@example.com',
      'amazfit_password': 'secret',
      'amazfit_remember': 'true',
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DownloadStorage downloads = await _filesystemDownloads(tester, prefs);
    await _capture(
      tester,
      '03_gps',
      GpsFilesScreen(
        credentialStore: CredentialStore(),
        downloadStorage: downloads,
      ),
      settleMs: 100,
    );
  }, skip: !_generate);
}

Future<void> _prepare(WidgetTester tester) async {
  final TestFlutterView view = tester.view
    ..physicalSize = Size(
      _phoneLogical.width * _dpr,
      _phoneLogical.height * _dpr,
    )
    ..devicePixelRatio = _dpr;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
}

/// Uses an on-disk folder so DownloadStorage never calls path_provider.
Future<DownloadStorage> _filesystemDownloads(
  WidgetTester tester,
  SharedPreferences prefs,
) async {
  late final Directory dir;
  await tester.runAsync(() async {
    dir = await Directory.systemTemp.createTemp('zelp_shot_out_');
  });
  addTearDown(() async {
    await tester.runAsync(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
  });

  final OutputFolderStore folderStore = OutputFolderStore(prefs: prefs);
  await folderStore.save(
    OutputFolder(
      kind: OutputFolderKind.filesystem,
      filesystemPath: dir.path,
      displayName: 'Downloads/Zelp',
    ),
  );
  final DownloadStorage storage = DownloadStorage(folderStore: folderStore);
  await storage.loadSettings();
  return storage;
}

WatchModel get _demoWatch => WatchModel(
  deviceId: 'gtr4',
  name: 'GTR 4',
  osVersion: '3.0',
  variants: <WatchVariant>[
    WatchVariant(
      deviceSource: 229,
      productionId: 1,
      appName: 'com.huami.midong',
    ),
  ],
);

DeviceCatalog _seedCatalog() => DeviceCatalog(
  seed: <WatchModel>[
    _demoWatch,
    WatchModel(
      deviceId: 'bip5',
      name: 'Bip 5',
      osVersion: '3.0',
      variants: <WatchVariant>[
        WatchVariant(
          deviceSource: 851,
          productionId: 1,
          appName: 'com.huami.midong',
        ),
      ],
    ),
  ],
  httpClient: MockClient((_) async {
    fail('screenshots must not hit the network');
  }),
);

ZeppVersionClient _seedVersions(SharedPreferences prefs) => ZeppVersionClient(
  prefs: prefs,
  fallbackVersion: '9.12.0-play_1',
  httpClient: MockClient((_) async {
    fail('screenshots must not hit the network');
  }),
);

Future<void> _capture(
  WidgetTester tester,
  String name,
  Widget home, {
  int settleMs = 50,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6B4A)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(filled: true),
      ),
      themeMode: ThemeMode.light,
      home: RepaintBoundary(
        child: SizedBox(
          width: _phoneLogical.width,
          height: _phoneLogical.height,
          child: home,
        ),
      ),
    ),
  );
  await tester.pump();
  // Flush real async (prefs) then rebuild UI.
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration(milliseconds: settleMs));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();

  // Avoid dart:io awaits here — real IO never completes in the widget-test
  // fake-async zone. The generator script ensures docs/screenshots/ exists.
  await expectLater(
    find.byType(RepaintBoundary).first,
    matchesGoldenFile('../../docs/screenshots/$name.png'),
  );
}

Future<void> _loadMaterialFonts() async {
  final String? fontsRoot = _materialFontsDir();
  if (fontsRoot == null) {
    // Screenshot text will render as tofu boxes without system fonts.
    // ignore: avoid_print
    print('WARNING: material fonts not found; screenshots may lack text');
    return;
  }

  Future<void> loadFamily(String family, List<String> files) async {
    final FontLoader loader = FontLoader(family);
    for (final String file in files) {
      final File fontFile = File(p.join(fontsRoot, file));
      if (!fontFile.existsSync()) continue;
      loader.addFont(
        Future<ByteData>.value(
          ByteData.view((await fontFile.readAsBytes()).buffer),
        ),
      );
    }
    await loader.load();
  }

  await loadFamily('Roboto', <String>[
    'Roboto-Thin.ttf',
    'Roboto-Light.ttf',
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]);
  await loadFamily('MaterialIcons', <String>['MaterialIcons-Regular.otf']);
}

String? _materialFontsDir() {
  final List<String> candidates = <String>[
    p.join(
      Platform.environment['FLUTTER_ROOT'] ?? '',
      'bin/cache/artifacts/material_fonts',
    ),
    p.join(
      Directory.current.path,
      '.flutter-sdk/bin/cache/artifacts/material_fonts',
    ),
    '/home/otaj/fvm/versions/3.44.8/bin/cache/artifacts/material_fonts',
  ];
  for (final String dir in candidates) {
    if (dir.isEmpty) continue;
    if (Directory(dir).existsSync()) return dir;
  }
  final String? which = _which('flutter');
  if (which != null) {
    final String resolved = File(which).resolveSymbolicLinksSync();
    final String candidate = p.normalize(
      p.join(p.dirname(resolved), '../cache/artifacts/material_fonts'),
    );
    if (Directory(candidate).existsSync()) return candidate;
  }
  return null;
}

String? _which(String cmd) {
  try {
    final ProcessResult r = Process.runSync('which', <String>[cmd]);
    if (r.exitCode != 0) return null;
    final String out = (r.stdout as String).trim();
    return out.isEmpty ? null : out;
  } on Exception {
    return null;
  }
}
