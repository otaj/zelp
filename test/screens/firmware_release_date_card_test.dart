import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/primitives/local_datetime.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/widgets/firmware/firmware_version_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a release date when the firmware URL has a build stamp', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirmwareVersionCard(
            info: FirmwareInfo(
              firmwareVersion: '3.12.4.1',
              firmwareUrl: 'https://cdn.example/fw_3.12.4.1_202607201712_deadbeef.zip',
            ),
            isLatest: false,
            downloading: false,
            onCopy: (String value, String label) async {},
          ),
        ),
      ),
    );

    expect(
      find.text('Released ${formatLocalDate(DateTime.utc(2026, 7, 20, 17, 12))}'),
      findsOneWidget,
    );
  });

  testWidgets('hides explorer-only first-seen times from the list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirmwareVersionCard(
            info: FirmwareInfo(
              firmwareVersion: '3.12.4.1',
              firmwareUrl: 'https://cdn.example/fw.bin',
              releasedAt: DateTime.utc(2026, 7, 24, 2, 42),
            ),
            isLatest: false,
            downloading: false,
            onCopy: (String value, String label) async {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Released'), findsNothing);
  });
}
