import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zelp/main.dart' as app;
import 'package:zelp/screens/store_catalog_screen.dart';
import 'package:zelp/screens/widgets/compact_watch_picker.dart';
import 'package:zelp/screens/widgets/error_banner.dart';
import 'package:zelp/services/credential_store.dart';

/// On-device walkthrough that captures every major Zelp screen.
///
/// Credentials and options come from `--dart-define` / `--dart-define-from-file`
/// (see `scripts/capture_screenshots.sh` and `.env.example`).
///
/// Screenshots are taken on the host via `adb screencap` when this test writes a
/// request file under the app documents directory (`screenshot_ipc/`).
///
/// Before frames that would show a real login, the test overwrites the visible
/// fields / stored account email with fixed placeholders (app code unchanged).
const String _email = String.fromEnvironment('ZEPP_EMAIL');
const String _password = String.fromEnvironment('ZEPP_PASSWORD');
const String _watchName = String.fromEnvironment('ZELP_WATCH_NAME');
const bool _fetchKeys = bool.fromEnvironment('ZELP_FETCH_KEYS');
const bool _refreshCatalog = bool.fromEnvironment('ZELP_REFRESH_CATALOG', defaultValue: true);
const bool _checkFirmware = bool.fromEnvironment('ZELP_CHECK_FIRMWARE', defaultValue: true);

const String _redactedEmail = '****@****.***';
const String _redactedPassword = '••••••••••••';

Directory? _ipcDir;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'capture app screenshots',
    (WidgetTester tester) async {
      expect(_email, isNotEmpty, reason: 'Pass ZEPP_EMAIL via dart-define / .env');
      expect(_password, isNotEmpty, reason: 'Pass ZEPP_PASSWORD via dart-define / .env');

      app.main();
      await tester.pump();
      // First launch can spend several seconds migrating flutter_secure_storage.
      await _pumpUntil(
        tester,
        () => find.text('Set up Zelp').evaluate().isNotEmpty || find.text('Welcome to Zelp').evaluate().isNotEmpty,
        timeout: const Duration(minutes: 2),
        what: 'first-time setup sheet',
      );

      await _shot(tester, '01_setup');

      await _signIn(tester);
      await _pumpUntil(
        tester,
        () =>
            find.byType(ErrorBanner).evaluate().isNotEmpty ||
            find.text('Get started').evaluate().isNotEmpty ||
            find.text('Done').evaluate().isNotEmpty,
        timeout: const Duration(minutes: 2),
        what: 'post sign-in ready-to-leave controls',
      );
      if (find.byType(ErrorBanner).evaluate().isNotEmpty) {
        final ErrorBanner banner = tester.widget<ErrorBanner>(find.byType(ErrorBanner));
        fail('Sign-in failed: ${banner.message}');
      }
      await _redactVisibleCredentialFields(tester);
      await _shot(tester, '02_settings_signed_in');

      // GPS Account tile reads the stored email — swap display-only email, keep
      // the real password until we restore both before market API calls.
      await _writeStoredCredentials(email: _redactedEmail, password: _password);

      final Finder getStarted = find.text('Get started');
      if (getStarted.evaluate().isNotEmpty) {
        await tester.tap(getStarted);
      } else {
        await tester.tap(find.text('Done'));
      }
      // First-time setup opens over Firmware; signing in does not switch tabs, so
      // the shell is still on Firmware when setup closes.
      await _pumpUntil(
        tester,
        () => find.text('Set up Zelp').evaluate().isEmpty && find.byType(NavigationBar).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
        what: 'main shell after leaving setup',
      );

      await _openTab(tester, 'GPS');
      await _pumpUntil(
        tester,
        () => find.text('GPS files').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
        what: 'GPS tab',
      );
      await _pumpUntil(
        tester,
        () => find.text(_redactedEmail).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 15),
        what: 'redacted GPS account email',
      );
      await _shot(tester, '03_gps');

      // Restore real credentials before Watchfaces / Apps market calls.
      await _writeStoredCredentials(email: _email, password: _password);

      await _openTab(tester, 'Firmware');
      await _pumpUntil(
        tester,
        () => find.text('Firmware check').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 60),
        what: 'Firmware tab',
      );
      await _selectWatch(tester);
      await _shot(tester, '04_firmware');

      if (_checkFirmware) {
        final Finder checkBtn = find.text('Check for updates');
        if (checkBtn.evaluate().isNotEmpty) {
          await tester.tap(checkBtn);
          await _pumpUntil(
            tester,
            () =>
                find.textContaining('Stored versions').evaluate().isNotEmpty ||
                find.byType(ErrorBanner).evaluate().isNotEmpty ||
                (find.text('Check for updates').evaluate().isNotEmpty &&
                    find.byType(CircularProgressIndicator).evaluate().isEmpty),
            timeout: const Duration(minutes: 3),
            what: 'firmware check result',
          );
          await _shot(tester, '05_firmware_history');
        }
      }

      await _captureStoreTab(
        tester,
        tabLabel: 'Watchfaces',
        listShot: '06_watchfaces',
        filterShot: '07_watchfaces_filter',
        detailShot: '08_watchface_detail',
        qrShot: '09_watchface_qr',
      );

      await _captureStoreTab(
        tester,
        tabLabel: 'Apps',
        listShot: '10_apps',
        detailShot: '11_app_detail',
        qrShot: '12_app_qr',
      );
    },
    timeout: const Timeout(Duration(minutes: 25)),
  );
}

Future<void> _redactVisibleCredentialFields(WidgetTester tester) async {
  final Finder fields = find.byType(TextFormField);
  expect(fields, findsAtLeastNWidgets(2));
  await tester.enterText(fields.at(0), _redactedEmail);
  await tester.enterText(fields.at(1), _redactedPassword);
  await _unfocus(tester);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _writeStoredCredentials({
  required String email,
  required String password,
}) async {
  await CredentialStore().save(Credentials(email: email, password: password));
}

Future<Directory> _ipc() async {
  if (_ipcDir != null) return _ipcDir!;
  final Directory docs = await getApplicationDocumentsDirectory();
  final Directory dir = Directory('${docs.path}/screenshot_ipc');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  _ipcDir = dir;
  return dir;
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _unfocus(tester);
  await tester.pump(const Duration(milliseconds: 500));
  final Directory dir = await _ipc();
  final File request = File('${dir.path}/request');
  final File done = File('${dir.path}/done');
  if (done.existsSync()) {
    done.deleteSync();
  }
  if (request.existsSync()) {
    request.deleteSync();
  }
  request.writeAsStringSync(name);
  await _pumpUntil(
    tester,
    done.existsSync,
    timeout: const Duration(seconds: 45),
    what: 'host adb screencap for $name',
  );
  if (done.existsSync()) {
    done.deleteSync();
  }
}

Future<void> _unfocus(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _signIn(WidgetTester tester) async {
  final Finder fields = find.byType(TextFormField);
  expect(fields, findsAtLeastNWidgets(2));
  await tester.enterText(fields.at(0), _email);
  await tester.enterText(fields.at(1), _password);
  await tester.pump();
  await _unfocus(tester);

  if (!_fetchKeys) {
    final Finder keysTile = find.widgetWithText(
      CheckboxListTile,
      'Also fetch Bluetooth pairing keys',
    );
    final CheckboxListTile tile = tester.widget<CheckboxListTile>(keysTile);
    if (tile.value ?? false) {
      await tester.tap(keysTile);
      await tester.pump();
    }
  }

  const String signInLabel = _fetchKeys ? 'Sign in & fetch keys' : 'Sign in & save';
  await tester.tap(find.text(signInLabel));
}

Finder _filterSortButton() {
  final Finder tip = find.byTooltip('Filter & sort');
  final Finder nested = find.descendant(of: tip, matching: find.byType(IconButton));
  if (nested.evaluate().isNotEmpty) {
    return nested;
  }
  return find.ancestor(of: tip, matching: find.byType(IconButton));
}

Finder _updateListButton() {
  final Finder tip = find.byTooltip('Update list');
  final Finder nested = find.descendant(of: tip, matching: find.byType(IconButton));
  if (nested.evaluate().isNotEmpty) {
    return nested;
  }
  return find.ancestor(of: tip, matching: find.byType(IconButton));
}

/// Store rows are `Card` → `ListTile`. Watch picker / collected-data tiles are not.
Finder _catalogItemCards() => find.descendant(
  of: find.byType(StoreCatalogScreen),
  matching: find.byType(Card),
);

Finder _freeItemAction() {
  final Finder again = find.byTooltip('Download again');
  if (again.evaluate().isNotEmpty) {
    return again;
  }
  return find.byTooltip('Download');
}

Future<void> _applyFreePriceFilter(
  WidgetTester tester, {
  String? filterShot,
}) async {
  final Finder filterBtn = _filterSortButton();
  expect(filterBtn, findsOneWidget);
  await _pumpUntil(
    tester,
    () => tester.widget<IconButton>(filterBtn).onPressed != null,
    timeout: const Duration(seconds: 30),
    what: 'Filter & sort enabled',
  );
  await tester.ensureVisible(filterBtn);
  await tester.tap(filterBtn, warnIfMissed: false);
  await _pumpUntil(
    tester,
    () => find.text('Filter & sort').evaluate().isNotEmpty && find.text('Apply').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 15),
    what: 'filter sheet',
  );

  final Finder free = find.text('Free');
  expect(free, findsWidgets, reason: 'Price → Free segment');
  await tester.tap(free.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));

  if (filterShot != null) {
    await _shot(tester, filterShot);
  }

  await tester.tap(find.text('Apply'), warnIfMissed: false);
  await _pumpUntil(
    tester,
    () => find.text('Apply').evaluate().isEmpty,
    timeout: const Duration(seconds: 10),
    what: 'filter sheet closed',
  );
  await _pumpUntil(
    tester,
    () =>
        _freeItemAction().evaluate().isNotEmpty ||
        find.textContaining('Nothing here yet').evaluate().isNotEmpty ||
        find.textContaining('Nothing saved').evaluate().isNotEmpty ||
        find.text('No matches.').evaluate().isNotEmpty ||
        find.byType(ErrorBanner).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
    what: 'free-filtered catalog',
  );
}

Future<void> _openTab(WidgetTester tester, String label) async {
  // Material NavigationDestination exposes the label as a tooltip.
  final Finder byTooltip = find.byTooltip(label);
  final Finder tab = byTooltip.evaluate().isNotEmpty
      ? byTooltip
      : find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        );
  expect(tab, findsWidgets, reason: 'bottom tab "$label"');
  await tester.ensureVisible(tab.first);
  await tester.tap(tab.first);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _selectWatch(WidgetTester tester) async {
  await _pumpUntil(
    tester,
    () => find.byType(CompactWatchPicker).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
    what: 'watch picker',
  );

  final Finder picker = find.byType(CompactWatchPicker);
  await tester.ensureVisible(picker);

  // Firmware / MRU may already have selected a watch; Update list is then enabled.
  // byTooltip finds RawTooltip, not IconButton — resolve the nested button.
  final Finder update = _updateListButton();
  final bool updateArmed = update.evaluate().isNotEmpty && tester.widget<IconButton>(update).onPressed != null;
  final String query = _watchName.trim();
  if (query.isEmpty && updateArmed) {
    return;
  }

  final Finder summaryTile = find.descendant(
    of: picker,
    matching: find.byType(ListTile),
  );
  expect(summaryTile, findsWidgets, reason: 'watch picker summary tile');
  await tester.ensureVisible(summaryTile.first);
  await tester.tap(summaryTile.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 500));

  final Finder search = find.descendant(
    of: picker,
    matching: find.byType(TextField),
  );
  await _pumpUntil(
    tester,
    () => search.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 15),
    what: 'watch search field',
  );

  if (query.isNotEmpty) {
    await tester.enterText(search, query);
    await tester.pump(const Duration(milliseconds: 400));
    await _unfocus(tester);
  }

  final Finder listTiles = find.descendant(
    of: picker,
    matching: find.byType(ListTile),
  );
  // First ListTile is the collapsed summary; options follow in the expanded list.
  expect(
    listTiles.evaluate().length,
    greaterThan(1),
    reason: query.isEmpty ? 'expected at least one watch in the catalog' : 'no watch matched ZELP_WATCH_NAME="$query"',
  );
  await tester.ensureVisible(listTiles.at(1));
  await tester.tap(listTiles.at(1), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _captureStoreTab(
  WidgetTester tester, {
  required String tabLabel,
  required String listShot,
  required String detailShot,
  required String qrShot,
  String? filterShot,
}) async {
  await _openTab(tester, tabLabel);
  await _pumpUntil(
    tester,
    () => find.text(tabLabel).evaluate().isNotEmpty && find.byType(CompactWatchPicker).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 60),
    what: '$tabLabel catalog',
  );
  await _selectWatch(tester);

  if (_refreshCatalog) {
    final Finder update = _updateListButton();
    expect(update, findsOneWidget);
    await _pumpUntil(
      tester,
      () => tester.widget<IconButton>(update).onPressed != null,
      timeout: const Duration(seconds: 30),
      what: '$tabLabel Update list enabled',
    );
    await tester.ensureVisible(update);
    await tester.tap(update, warnIfMissed: false);
    await _pumpUntil(
      tester,
      () {
        final bool spinning = find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(CircularProgressIndicator),
            )
            .evaluate()
            .isNotEmpty;
        if (spinning) return false;
        return _catalogItemCards().evaluate().isNotEmpty ||
            find.byTooltip('Download').evaluate().isNotEmpty ||
            find.byTooltip('Download again').evaluate().isNotEmpty ||
            find.textContaining('Nothing here yet').evaluate().isNotEmpty ||
            find.textContaining('Nothing saved').evaluate().isNotEmpty ||
            find.text('No matches.').evaluate().isNotEmpty ||
            find.byType(ErrorBanner).evaluate().isNotEmpty;
      },
      timeout: const Duration(minutes: 12),
      what: '$tabLabel catalog refresh',
    );
  }

  await _shot(tester, listShot);

  // Restrict to Free so the next open always hits a downloadable row.
  await _applyFreePriceFilter(tester, filterShot: filterShot);

  final Finder itemAction = _freeItemAction();
  expect(
    itemAction,
    findsWidgets,
    reason: '$tabLabel: expected at least one free item after Price → Free',
  );
  final Finder openTile = find.ancestor(
    of: itemAction.first,
    matching: find.byType(ListTile),
  );
  expect(openTile, findsWidgets);

  // Tap the title — ListTile center often hits trailing Download.
  final Finder title = find.descendant(of: openTile.first, matching: find.byType(Text)).first;
  await tester.ensureVisible(title);
  await tester.tap(title, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));
  if (find.text('Show QR code').evaluate().isEmpty && find.text('About').evaluate().isEmpty) {
    final Finder card = find.ancestor(of: itemAction.first, matching: find.byType(Card));
    await tester.ensureVisible(card.first);
    await tester.tapAt(tester.getCenter(card.first).translate(-80, 0));
  }
  await _pumpUntil(
    tester,
    () => find.text('Show QR code').evaluate().isNotEmpty || find.text('About').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    what: '$tabLabel detail',
  );
  await _shot(tester, detailShot);

  final Finder qr = find.text('Show QR code');
  if (qr.evaluate().isNotEmpty) {
    await tester.ensureVisible(qr);
    await tester.tap(qr, warnIfMissed: false);
    await _pumpUntil(
      tester,
      () => find.text('Install with Zepp').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 15),
      what: '$tabLabel QR dialog',
    );
    await _shot(tester, qrShot);
    await tester.tap(find.text('Close'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
  }

  await tester.pageBack();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
  required String what,
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (condition()) {
      return;
    }
  }
  fail('Timed out waiting for $what after $timeout');
}
