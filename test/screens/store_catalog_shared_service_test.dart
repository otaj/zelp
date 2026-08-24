import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/main_shell.dart';
import 'package:zelp/screens/store_catalog_screen.dart';
import 'package:zelp/services/app_setup_store.dart';
import 'package:zelp/services/credential_store.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/store_browse_prefs.dart';
import 'package:zelp/services/store_catalog_service.dart';

import '../services/store_catalog_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StoreCatalogService catalogService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppSetupStore.prefsComplete: true,
    });
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    tempDir = await Directory.systemTemp.createTemp('store_share_');
    catalogService = StoreCatalogService(db: openTestStoreCatalogDb(tempDir));
  });

  tearDown(() async {
    await catalogService.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  final WatchModel seedWatch = WatchModel(
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

  DeviceCatalog seededCatalog() => DeviceCatalog(
    seed: <WatchModel>[seedWatch],
    httpClient: MockClient((_) async {
      fail('device catalog must not hit the network');
    }),
  );

  Finder storeScreens() => find.byType(StoreCatalogScreen, skipOffstage: false);

  testWidgets(
    'Apps and Watchfaces screens with shared service use one Drift database',
    (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
      final StoreBrowsePrefs browsePrefs = StoreBrowsePrefs(prefs: prefs);
      final DeviceCatalog devices = seededCatalog();

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: <Widget>[
              Expanded(
                child: StoreCatalogScreen(
                  entryType: StoreEntryType.watch,
                  catalog: devices,
                  catalogService: catalogService,
                  deviceUsageStore: usage,
                  browsePrefs: browsePrefs,
                  loadIcons: false,
                ),
              ),
              Expanded(
                child: StoreCatalogScreen(
                  entryType: StoreEntryType.lightapp,
                  catalog: devices,
                  catalogService: catalogService,
                  deviceUsageStore: usage,
                  browsePrefs: browsePrefs,
                  loadIcons: false,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final List<StoreCatalogScreen> screens = tester.widgetList<StoreCatalogScreen>(storeScreens()).toList();
      expect(screens, hasLength(2));
      expect(screens[0].catalogService, same(catalogService));
      expect(screens[1].catalogService, same(catalogService));
      expect(
        identical(
          screens[0].catalogService!.db.database,
          screens[1].catalogService!.db.database,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'MainShell injects one StoreCatalogService into Apps and Watchfaces',
    (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final CredentialStore credentials = CredentialStore();
      await credentials.save(
        Credentials(email: 'user@example.com', password: 'secret'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            credentialStore: credentials,
            setupStore: AppSetupStore(prefs: prefs),
            deviceUsageStore: DeviceUsageStore(prefs: prefs),
            catalogService: catalogService,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Watchfaces'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Apps'));
      await tester.pump();
      await tester.pump();

      final List<StoreCatalogScreen> screens = tester.widgetList<StoreCatalogScreen>(storeScreens()).toList();
      expect(screens, hasLength(2));
      expect(
        screens.map((StoreCatalogScreen s) => s.catalogService).toSet(),
        <StoreCatalogService?>{catalogService},
      );
    },
  );

  testWidgets(
    'pulling Apps catalog updates the list',
    (WidgetTester tester) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
      await usage.touchWatch('gtr4', at: DateTime.utc(2026, 6));
      final StoreBrowsePrefs browsePrefs = StoreBrowsePrefs(prefs: prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: StoreCatalogScreen(
            entryType: StoreEntryType.lightapp,
            catalog: seededCatalog(),
            catalogService: catalogService,
            deviceUsageStore: usage,
            browsePrefs: browsePrefs,
            loadIcons: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Sign in in Settings'), findsOneWidget);
    },
  );

  test('accessing catalog service db twice returns the same Drift instance', () {
    expect(
      identical(catalogService.db.database, catalogService.db.database),
      isTrue,
    );
  });
}
