import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/firmware_check_screen.dart';
import 'package:zelp/screens/settings_screen.dart';
import 'package:zelp/services/device_catalog.dart';
import 'package:zelp/services/device_usage_store.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/expert_mode_store.dart';
import 'package:zelp/services/firmware_client.dart';
import 'package:zelp/services/firmware_store.dart';
import 'package:zelp/services/zepp_version_client.dart';

import '../fixtures/watch_models.dart';
import '../helpers/network_clients.dart';
import '../helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('manual version fields stay hidden until expert mode is on', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await mockEmptyPrefs();
    final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
    await usage.touchWatch('gtr4', at: DateTime.utc(2026, 6));
    final FirmwareStore store = FirmwareStore(prefs: prefs);
    await store.setBaseline(deviceId: 'gtr4', deviceSource: 229, version: '3.12.4.1');
    final ZeppVersionClient versions = offlineZeppVersionClient(prefs);
    final _RecordingFirmwareClient client = _RecordingFirmwareClient(zeppVersionClient: versions);

    await _pumpFirmware(
      tester,
      prefs: prefs,
      usage: usage,
      versions: versions,
      client: client,
      store: store,
    );

    expect(find.byKey(const Key('firmware-current-version')), findsNothing);
    expect(find.byKey(const Key('zepp-version-edit')), findsNothing);
    expect(find.textContaining('starts from scratch'), findsNothing);

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(client.fromVersions, <String>['0']);
  });

  testWidgets('expert mode sends the typed firmware version and remembers it', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await mockEmptyPrefs();
    await prefs.setBool(ExpertModeStore.prefsKey, true);
    final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
    await usage.touchWatch('gtr4', at: DateTime.utc(2026, 6));
    final ZeppVersionClient versions = offlineZeppVersionClient(prefs);
    final _RecordingFirmwareClient client = _RecordingFirmwareClient(zeppVersionClient: versions);
    final FirmwareStore store = FirmwareStore(prefs: prefs);

    Future<void> pumpScreen() => _pumpFirmware(
      tester,
      prefs: prefs,
      usage: usage,
      versions: versions,
      client: client,
      store: store,
    );

    await pumpScreen();
    expect(
      find.textContaining('starts from scratch and usually downloads a full package'),
      findsOneWidget,
    );

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(client.fromVersions, <String>['0']);

    await tester.enterText(find.byKey(const Key('firmware-current-version')), '3.12.4.1');
    await tester.pump();
    expect(find.textContaining('Will check for versions newer than 3.12.4.1'), findsOneWidget);

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(client.fromVersions, <String>['0', '3.12.4.1']);

    await tester.enterText(find.byKey(const Key('firmware-current-version')), '!!!');
    await tester.pump();
    await tester.tap(find.text('Check for updates'));
    await tester.pump();
    expect(find.text('Enter a firmware version such as 3.17.0.3'), findsOneWidget);
    expect(client.fromVersions, <String>['0', '3.12.4.1']);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await pumpScreen();
    expect(
      tester.widget<TextField>(find.byKey(const Key('firmware-current-version'))).controller?.text,
      '3.12.4.1',
    );
  });

  testWidgets('empty current firmware continues from the newest stored version', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await mockEmptyPrefs();
    await prefs.setBool(ExpertModeStore.prefsKey, true);
    final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
    await usage.touchWatch('gtr4', at: DateTime.utc(2026, 6));
    final WatchModel watch = gtr4Watch();
    final FirmwareStore store = FirmwareStore(prefs: prefs);
    await store.merge(
      watch: watch,
      variant: watch.variants.first,
      discovered: <FirmwareInfo>[
        FirmwareInfo(firmwareVersion: '1.2.3', firmwareUrl: 'https://cdn.example/fw.bin'),
      ],
    );
    final ZeppVersionClient versions = offlineZeppVersionClient(prefs);
    final _RecordingFirmwareClient client = _RecordingFirmwareClient(zeppVersionClient: versions);

    await _pumpFirmware(
      tester,
      prefs: prefs,
      usage: usage,
      versions: versions,
      client: client,
      store: store,
      watch: watch,
    );

    expect(find.textContaining('Will check for versions newer than 1.2.3'), findsOneWidget);
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(client.fromVersions, <String>['1.2.3']);

    await tester.enterText(find.byKey(const Key('firmware-current-version')), '1.0.0');
    await tester.pump();
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(client.fromVersions, <String>['1.2.3', '1.0.0']);
  });

  testWidgets('Zepp version name and code can be entered in expert mode', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await mockEmptyPrefs();
    await prefs.setBool(ExpertModeStore.prefsKey, true);
    final DeviceUsageStore usage = DeviceUsageStore(prefs: prefs);
    await usage.touchWatch('gtr4', at: DateTime.utc(2026, 6));
    final ZeppVersionClient versions = offlineZeppVersionClient(prefs);

    await _pumpFirmware(
      tester,
      prefs: prefs,
      usage: usage,
      versions: versions,
      client: _RecordingFirmwareClient(zeppVersionClient: versions),
      store: FirmwareStore(prefs: prefs),
    );

    expect(find.text('10.0.0-play_1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('zepp-version-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('zepp-version-name')), 'nope');
    await tester.enterText(find.byKey(const Key('zepp-version-code')), '12');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a Play version name such as 10.10.5-play'), findsOneWidget);
    expect(find.text('Zepp app version'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('zepp-version-name')), '10.10.5-play');
    await tester.enterText(find.byKey(const Key('zepp-version-code')), '151997');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('10.10.5-play_151997'), findsOneWidget);
    expect(find.textContaining('Entered manually'), findsOneWidget);
    expect(await versions.current(), '10.10.5-play_151997');
    expect(await versions.wasEnteredManually(), isTrue);
  });

  testWidgets('Settings expert mode switch is saved', (WidgetTester tester) async {
    final SharedPreferences prefs = await mockEmptyPrefs();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(expertModeStore: ExpertModeStore(prefs: prefs)),
      ),
    );
    await tester.pump();
    await tester.pump();

    final Finder expert = find.byKey(const Key('expert-mode'));
    await tester.ensureVisible(expert);
    await tester.tap(expert);
    await tester.pumpAndSettle();

    expect(await ExpertModeStore(prefs: prefs).load(), isTrue);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('expert-mode'))).value, isTrue);
  });
}

Future<void> _pumpFirmware(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required DeviceUsageStore usage,
  required ZeppVersionClient versions,
  required FirmwareClient client,
  required FirmwareStore store,
  WatchModel? watch,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FirmwareCheckScreen(
        catalog: DeviceCatalog(
          seed: <WatchModel>[watch ?? gtr4Watch()],
          httpClient: neverHttpClient('device catalog must not hit the network'),
        ),
        versionClient: versions,
        firmwareClient: client,
        firmwareStore: store,
        downloadStorage: _QuietDownloadStorage(),
        deviceUsageStore: usage,
        expertModeStore: ExpertModeStore(prefs: prefs),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _QuietDownloadStorage extends DownloadStorage {
  @override
  Future<Map<String, ExistingDownloadMatch>> scanExistingMatches(
    Iterable<ExistingDownloadProbe> items, {
    bool forceReloadSettings = true,
  }) async => <String, ExistingDownloadMatch>{};
}

class _RecordingFirmwareClient extends FirmwareClient {
  _RecordingFirmwareClient({required ZeppVersionClient zeppVersionClient})
    : super(
        zeppVersionClient: zeppVersionClient,
        httpClient: neverHttpClient('firmware must not hit the network'),
      );

  final List<String> fromVersions = <String>[];

  @override
  Future<List<FirmwareInfo>> checkUpdates({
    required WatchVariant variant,
    String fromVersion = '0',
    String? timezone,
  }) async {
    fromVersions.add(fromVersion);
    return const <FirmwareInfo>[];
  }
}
