import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/firmware_check_screen.dart';
import 'package:zelp/screens/gps_files_screen.dart';
import 'package:zelp/screens/main_shell.dart';
import 'package:zelp/screens/settings_screen.dart';
import 'package:zelp/services/app_setup_store.dart';
import 'package:zelp/services/credential_store.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/firmware_store.dart';
import 'package:zelp/services/zepp_version_client.dart';

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
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DeviceCatalog catalog = DeviceCatalog(
      seed: <WatchModel>[
        WatchModel(
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
        ),
      ],
      httpClient: MockClient((_) async {
        fail('device catalog must not hit the network');
      }),
    );
    final ZeppVersionClient versions = ZeppVersionClient(
      prefs: prefs,
      fallbackVersion: '10.0.0-play_1',
      httpClient: MockClient((_) async {
        fail('zepp version must not hit the network');
      }),
    );

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
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
      await usage.touchWatch('bip5', at: DateTime.utc(2026, 6));

      final DeviceCatalog catalog = DeviceCatalog(
        seed: <WatchModel>[
          WatchModel(
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
          ),
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
              WatchVariant(
                deviceSource: 852,
                productionId: 2,
                appName: 'com.huami.midong',
              ),
            ],
          ),
        ],
        httpClient: MockClient((_) async {
          fail('device catalog must not hit the network');
        }),
      );
      final ZeppVersionClient versions = ZeppVersionClient(
        prefs: prefs,
        fallbackVersion: '10.0.0-play_1',
        httpClient: MockClient((_) async {
          fail('zepp version must not hit the network');
        }),
      );

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
    },
  );

  testWidgets(
    'Firmware auto-selects most recently used device source',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
      await usage.touchWatch('bip5', at: DateTime.utc(2026, 6));
      await usage.touchSource('bip5', 852, at: DateTime.utc(2026, 6, 2));

      final DeviceCatalog catalog = DeviceCatalog(
        seed: <WatchModel>[
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
              WatchVariant(
                deviceSource: 852,
                productionId: 2,
                appName: 'com.huami.midong',
              ),
            ],
          ),
        ],
        httpClient: MockClient((_) async {
          fail('device catalog must not hit the network');
        }),
      );
      final ZeppVersionClient versions = ZeppVersionClient(
        prefs: prefs,
        fallbackVersion: '10.0.0-play_1',
        httpClient: MockClient((_) async {
          fail('zepp version must not hit the network');
        }),
      );

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
}
