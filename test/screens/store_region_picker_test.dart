import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/store/market_countries.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/store_catalog_screen.dart';
import 'package:zelp/screens/widgets/store_catalog/store_market_region_section.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/expert_mode_store.dart';
import 'package:zelp/services/store_browse_prefs.dart';
import 'package:zelp/services/store_catalog_service.dart';
import 'package:zelp/services/store_region_store.dart';
import 'package:zelp/services/zepp_client.dart';

import '../fixtures/watch_models.dart';
import '../helpers/network_clients.dart';
import '../helpers/prefs.dart';
import '../services/store_catalog_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _RecordingCatalog catalog;
  late SharedPreferences prefs;

  setUp(() async {
    prefs = await mockEmptyPrefs();
    tempDir = await Directory.systemTemp.createTemp('store_regions_');
    catalog = _RecordingCatalog(db: openTestStoreCatalogDb(tempDir));
  });

  tearDown(() async {
    await catalog.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  testWidgets('region chips stay hidden until expert mode is on', (WidgetTester tester) async {
    final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
    await usage.touchWatch('gtr4', at: DateTime.utc(2026, 6));

    await _pumpStore(tester, prefs: prefs, usage: usage, catalog: catalog);
    expect(find.byKey(const Key('store-region-US')), findsNothing);

    await tester.tap(find.byTooltip('Update list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(catalog.refreshes, 1);
    expect(catalog.lastCountries, isNull);

    await prefs.setBool(ExpertModeStore.prefsKey, true);
    await _pumpStore(
      tester,
      prefs: prefs,
      usage: usage,
      catalog: catalog,
      settingsEpoch: 1,
    );
    expect(find.byKey(const Key('store-region-US')), findsOneWidget);
    expect(find.text('${flagForMarketCountry('CN')} China (CN)'), findsOneWidget);
    expect(find.textContaining('Add any other ISO country.'), findsOneWidget);
  });

  testWidgets('expert mode refresh queries only the selected regions', (WidgetTester tester) async {
    await prefs.setBool(ExpertModeStore.prefsKey, true);
    final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
    await usage.touchWatch('gtr4', at: DateTime.utc(2026, 6));

    await _pumpStore(tester, prefs: prefs, usage: usage, catalog: catalog);
    expect(find.byKey(const Key('store-region-CN')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('store-region-CN')));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('store-region-CN')),
        matching: find.byIcon(Icons.clear),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('store-region-CN')), findsNothing);
    expect(await StoreRegionStore(prefs: prefs).load(), <String>['RU', 'PL', 'US']);

    await tester.ensureVisible(find.byKey(const Key('store-region-add')));
    await tester.tap(find.byKey(const Key('store-region-add')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byKey(const Key('store-region-search')), 'Germany');
    await tester.pump();
    expect(find.text(flagForMarketCountry('DE')), findsOneWidget);
    await tester.tap(find.byKey(const Key('store-region-option-DE')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('store-region-DE')), findsOneWidget);
    expect(await StoreRegionStore(prefs: prefs).load(), <String>['RU', 'PL', 'US', 'DE']);

    await tester.tap(find.byTooltip('Update list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(catalog.lastCountries, <String>['RU', 'PL', 'US', 'DE']);
    expect(find.textContaining('from RU, PL, US, DE'), findsOneWidget);
  });

  testWidgets('a saved region subset is ignored while expert mode is off', (WidgetTester tester) async {
    await StoreRegionStore(prefs: prefs).save(const <String>['CN']);
    final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
    await usage.touchWatch('gtr4', at: DateTime.utc(2026, 6));

    await _pumpStore(tester, prefs: prefs, usage: usage, catalog: catalog);
    await tester.tap(find.byTooltip('Update list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(catalog.lastCountries, isNull);
  });

  testWidgets('the last selected region stays on', (WidgetTester tester) async {
    List<String> selected = const <String>['US'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => StoreMarketRegionSection(
              selected: selected,
              enabled: true,
              onChanged: (List<String> next) => setState(() => selected = next),
            ),
          ),
        ),
      ),
    );

    expect(selected, <String>['US']);
    expect(
      find.descendant(
        of: find.byKey(const Key('store-region-US')),
        matching: find.byIcon(Icons.clear),
      ),
      findsNothing,
    );
    expect(find.byType(InputChip), findsOneWidget);
  });
}

Future<void> _pumpStore(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required DeviceUsageStore usage,
  required StoreCatalogService catalog,
  int settingsEpoch = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StoreCatalogScreen(
        entryType: StoreEntryType.lightapp,
        catalog: DeviceCatalog(
          seed: <WatchModel>[gtr4Watch()],
          httpClient: neverHttpClient('device catalog must not hit the network'),
        ),
        catalogService: catalog,
        deviceUsageStore: usage,
        downloadStorage: _QuietDownloadStorage(),
        browsePrefs: StoreBrowsePrefs(prefs: prefs),
        expertModeStore: ExpertModeStore(prefs: prefs),
        storeRegionStore: StoreRegionStore(prefs: prefs),
        loadIcons: false,
        settingsEpoch: settingsEpoch,
      ),
    ),
  );
  await tester.pump();
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    final Object? error = tester.takeException();
    if (error != null) {
      fail('$error');
    }
    if (find.text('GTR 4').evaluate().isNotEmpty) return;
  }
  final String texts = find
      .byType(Text)
      .evaluate()
      .map((Element element) => (element.widget as Text).data ?? '')
      .join(' | ');
  fail('store screen did not finish loading: $texts');
}

class _QuietDownloadStorage extends DownloadStorage {
  @override
  Future<OutputFolder> loadSettings({bool force = false}) async => OutputFolder.defaults;

  @override
  Future<Map<String, ExistingDownloadMatch>> scanExistingMatches(
    Iterable<ExistingDownloadProbe> items, {
    bool forceReloadSettings = true,
  }) async => <String, ExistingDownloadMatch>{};
}

class _RecordingCatalog extends StoreCatalogService {
  _RecordingCatalog({required super.db});

  List<String>? lastCountries;
  int refreshes = 0;

  @override
  Future<StoreRefreshResult> refreshForWatch({
    required WatchModel watch,
    required StoreEntryType entryType,
    int pageLimit = 80,
    StoreRefreshProgress? onProgress,
    Future<void> Function(ZeppSession session)? login,
    List<String>? marketCountries,
  }) async {
    refreshes++;
    lastCountries = marketCountries;
    return const StoreRefreshResult(
      itemCount: 0,
      detailedCount: 0,
      skippedDetailCount: 0,
    );
  }
}
