import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/firmware_check_screen.dart';
import 'package:zelp/screens/gps_files_screen.dart';
import 'package:zelp/screens/main_shell.dart';
import 'package:zelp/screens/settings_screen.dart';
import 'package:zelp/services/app_setup_store.dart';
import 'package:zelp/services/credential_store.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/firmware_client.dart';
import 'package:zelp/services/firmware_store.dart';
import 'package:zelp/services/zepp_version_client.dart';

import '../fixtures/watch_models.dart';
import '../helpers/network_clients.dart';
import '../helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    required bool setupComplete,
  }) async {
    SharedPreferences.setMockInitialValues(
      setupComplete ? <String, Object>{AppSetupStore.prefsComplete: true} : <String, Object>{},
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(
          credentialStore: CredentialStore(),
          setupStore: AppSetupStore(prefs: prefs),
          deviceUsageStore: DeviceUsageStore(prefs: prefs),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'MainShell has GPS, Firmware, Apps, Watchfaces tabs (no Credentials tab)',
    (WidgetTester tester) async {
      await pumpShell(tester, setupComplete: true);

      expect(find.text('Credentials'), findsNothing);
      expect(find.text('GPS'), findsOneWidget);
      expect(find.text('Firmware'), findsOneWidget);
      expect(find.text('Apps'), findsOneWidget);
      expect(find.text('Watchfaces'), findsOneWidget);
      expect(find.byType(FirmwareCheckScreen), findsOneWidget);
      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
    },
  );

  testWidgets('Settings shows icon-only folder actions', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();

    expect(find.text('Download folder'), findsOneWidget);
    expect(find.textContaining('Sign in'), findsWidgets);
    expect(find.text('Continue without signing in'), findsOneWidget);
    expect(find.text('Select output folder'), findsNothing);
    expect(find.text('Clear folder'), findsNothing);
    expect(find.byTooltip('Select output folder'), findsOneWidget);
    expect(find.byTooltip('Use default folder'), findsOneWidget);
    expect(find.byTooltip('Clear output folder'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.text('Build gps_uihh.bin'), findsNothing);
  });

  testWidgets('GPS screen is separate from settings form', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MaterialApp(home: GpsFilesScreen()));
    await tester.pump();

    expect(find.text('GPS assistance files'), findsOneWidget);
    expect(find.text('Build gps_uihh.bin'), findsOneWidget);
    expect(find.text('Download selected GPS files'), findsOneWidget);
    expect(find.text('Saving to'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Download folder'), findsNothing);
  });

  testWidgets('GPS screen has no manual refresh action', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MaterialApp(home: GpsFilesScreen()));
    await tester.pump();

    expect(find.byTooltip('Refresh folder & account'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byType(RefreshIndicator), findsNothing);
  });

  testWidgets('Switching to GPS tab while signed out stays on Firmware', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester, setupComplete: true);

    await tester.tap(find.text('GPS'));
    await tester.pump();

    expect(find.byType(FirmwareCheckScreen), findsOneWidget);
    expect(find.byType(GpsFilesScreen), findsNothing);
    expect(find.textContaining('Sign in in Settings'), findsOneWidget);
  });

  testWidgets('Settings gear opens Settings from Firmware', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester, setupComplete: true);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Account & downloads'), findsOneWidget);
  });

  testWidgets('First launch opens first-time setup', (WidgetTester tester) async {
    await pumpShell(tester, setupComplete: false);

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Welcome to Zelp'), findsOneWidget);
    expect(find.text('Continue without signing in'), findsOneWidget);
    expect(
      find.textContaining('for personal use only and is not affiliated'),
      findsOneWidget,
    );
  });

  testWidgets('Switching to Firmware tab while signed out opens Firmware', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester, setupComplete: true);

    // Already on Firmware by default when signed out; tapping again is fine.
    await tester.tap(find.text('Firmware'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(FirmwareCheckScreen), findsOneWidget);
    expect(find.textContaining('Sign in in Settings'), findsNothing);
  });

  testWidgets('Firmware screen renders with seeded catalog (no network)', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await mockEmptyPrefs();
    final DeviceCatalog catalog = DeviceCatalog(
      seed: <WatchModel>[gtr4Watch()],
      httpClient: neverHttpClient('device catalog must not hit the network'),
    );
    final ZeppVersionClient versions = offlineZeppVersionClient(prefs);

    await tester.pumpWidget(
      MaterialApp(
        home: FirmwareCheckScreen(
          catalog: catalog,
          versionClient: versions,
          firmwareStore: FirmwareStore(prefs: prefs),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Firmware check'), findsOneWidget);
    expect(find.text('Zepp app in use'), findsOneWidget);
    // Section title + compact picker both say “Choose a watch”.
    expect(find.text('Choose a watch'), findsWidgets);
  });

  testWidgets(
    'Firmware auto-selects shared MRU watch and shows device sources',
    (WidgetTester tester) async {
      final SharedPreferences prefs = await mockEmptyPrefs();
      final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
      await usage.touchWatch('bip5', at: DateTime.utc(2026, 6));

      final DeviceCatalog catalog = DeviceCatalog(
        seed: <WatchModel>[gtr4Watch(), bip5Watch()],
        httpClient: neverHttpClient('device catalog must not hit the network'),
      );
      final ZeppVersionClient versions = offlineZeppVersionClient(prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: FirmwareCheckScreen(
            catalog: catalog,
            versionClient: versions,
            firmwareStore: FirmwareStore(prefs: prefs),
            deviceUsageStore: usage,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Bip 5'), findsWidgets);
      expect(find.text('Device source'), findsOneWidget);
      expect(find.text('Device source 851'), findsOneWidget);
      expect(find.textContaining('Variant'), findsNothing);
      expect(find.byTooltip('Fetch full release history'), findsOneWidget);
      expect(find.text('Check for updates'), findsOneWidget);
    },
  );

  testWidgets(
    'Firmware auto-selects most recently used device source',
    (WidgetTester tester) async {
      final SharedPreferences prefs = await mockEmptyPrefs();
      final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
      await usage.touchWatch('bip5', at: DateTime.utc(2026, 6));
      await usage.touchSource('bip5', 852, at: DateTime.utc(2026, 6, 2));

      final DeviceCatalog catalog = DeviceCatalog(
        seed: <WatchModel>[bip5Watch()],
        httpClient: neverHttpClient('device catalog must not hit the network'),
      );
      final ZeppVersionClient versions = offlineZeppVersionClient(prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: FirmwareCheckScreen(
            catalog: catalog,
            versionClient: versions,
            firmwareStore: FirmwareStore(prefs: prefs),
            deviceUsageStore: usage,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Device source'), findsOneWidget);
      expect(find.text('Device source 852'), findsOneWidget);
      expect(
        find.textContaining('Recently used device sources appear first'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Firmware hides Already downloaded after settingsEpoch bump',
    (WidgetTester tester) async {
      final SharedPreferences prefs = await mockEmptyPrefs();

      final WatchModel watch = gtr4Watch();
      final WatchVariant variant = watch.variants.first;
      final FirmwareStore firmwareStore = FirmwareStore(prefs: prefs);
      await firmwareStore.merge(
        watch: watch,
        variant: variant,
        discovered: <FirmwareInfo>[
          FirmwareInfo(
            firmwareVersion: '1.2.3',
            firmwareUrl: 'https://cdn.example/fw.bin',
          ),
        ],
      );

      final _ControllableDownloadStorage downloads = _ControllableDownloadStorage(
        match: const ExistingDownloadMatch(
          file: StoredOutputFile(
            fileName: 'fw.bin',
            displayPath: '/tmp/fw.bin',
            localPath: '/tmp/fw.bin',
          ),
          matchedByChecksum: false,
        ),
      );

      final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
      await usage.touchWatch('gtr4', at: DateTime.utc(2026, 6));

      final DeviceCatalog catalog = DeviceCatalog(
        seed: <WatchModel>[watch],
        httpClient: neverHttpClient('device catalog must not hit the network'),
      );
      final ZeppVersionClient versions = offlineZeppVersionClient(prefs);

      Future<void> pumpWithEpoch(int epoch) async {
        await tester.pumpWidget(
          MaterialApp(
            home: FirmwareCheckScreen(
              catalog: catalog,
              versionClient: versions,
              firmwareStore: firmwareStore,
              downloadStorage: downloads,
              deviceUsageStore: usage,
              settingsEpoch: epoch,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      await pumpWithEpoch(0);
      expect(find.text('Already downloaded'), findsOneWidget);

      downloads.match = null;
      await pumpWithEpoch(1);
      expect(find.text('Already downloaded'), findsNothing);
    },
  );

  testWidgets('Firmware pull-to-refresh checks for updates', (WidgetTester tester) async {
    final SharedPreferences prefs = await mockEmptyPrefs();
    final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
    await usage.touchWatch('gtr4', at: DateTime.utc(2026, 6));

    final ZeppVersionClient versions = offlineZeppVersionClient(prefs);
    final _RecordingFirmwareClient client = _RecordingFirmwareClient(zeppVersionClient: versions);
    final DeviceCatalog catalog = DeviceCatalog(
      seed: <WatchModel>[gtr4Watch()],
      httpClient: neverHttpClient('device catalog must not hit the network'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FirmwareCheckScreen(
          catalog: catalog,
          versionClient: versions,
          firmwareClient: client,
          firmwareStore: FirmwareStore(prefs: prefs),
          deviceUsageStore: usage,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);

    await tester.fling(find.text('Choose a watch').first, const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(client.checks, 1);
  });
}

class _ControllableDownloadStorage extends DownloadStorage {
  _ControllableDownloadStorage({this.match});

  ExistingDownloadMatch? match;

  @override
  Future<OutputFolder> loadSettings({bool force = false}) async => OutputFolder.normalized(
    kind: OutputFolderKind.filesystem,
    filesystemPath: '/tmp/zelp-test-out',
    displayName: '/tmp/zelp-test-out',
  );

  @override
  Future<ExistingDownloadMatch?> findExistingDownload({
    required String expectedFileName,
    FileChecksum? checksum,
    AssetKind? kind,
  }) async => match;
}

class _RecordingFirmwareClient extends FirmwareClient {
  _RecordingFirmwareClient({required ZeppVersionClient zeppVersionClient})
    : super(
        zeppVersionClient: zeppVersionClient,
        httpClient: neverHttpClient('firmware must not hit the network'),
      );

  int checks = 0;

  @override
  Future<List<FirmwareInfo>> checkUpdates({
    required WatchVariant variant,
    String fromVersion = '0',
    String? timezone,
  }) async {
    checks++;
    return const <FirmwareInfo>[];
  }
}
