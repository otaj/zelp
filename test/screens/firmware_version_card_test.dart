import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/widgets/firmware/firmware_version_card.dart';
import 'package:zelp/screens/widgets/restorable_scroll_body.dart';

/// Regression for ExpansionTile under [RestorableScrollBody]: without its own
/// [PageStorageKey], Expansible reads the ListView scroll offset (`double`) as
/// `bool?` and throws in debug when full firmware history includes release notes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ScrollOffsetMemory.clear);

  const String storageId = 'firmware_gtr4';

  testWidgets('release-notes ExpansionTile builds when scroll offset is stored', (
    WidgetTester tester,
  ) async {
    final PageStorageBucket bucket = PageStorageBucket();

    await tester.pumpWidget(_scrollSeed(bucket: bucket, storageId: storageId));
    await tester.pumpAndSettle();

    final BuildContext scrollContext = tester.element(find.byType(Scrollable));
    PageStorage.of(scrollContext).writeState(scrollContext, 42.0);

    await tester.pumpWidget(
      MaterialApp(
        home: PageStorage(
          bucket: bucket,
          child: Scaffold(
            body: RestorableScrollBody.list(
              storageId: storageId,
              children: <Widget>[
                FirmwareVersionCard(
                  info: FirmwareInfo(
                    firmwareVersion: '1.2.3',
                    changeLog: 'Fixed GPS',
                  ),
                  isLatest: true,
                  downloading: false,
                  onCopy: (String value, String label) async {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(ExpansionTile, 'Release notes'), findsOneWidget);
  });
}

Widget _scrollSeed({
  required PageStorageBucket bucket,
  required String storageId,
}) => MaterialApp(
  home: PageStorage(
    bucket: bucket,
    child: Scaffold(
      body: RestorableScrollBody.list(
        storageId: storageId,
        children: const <Widget>[
          SizedBox(height: 48, child: Text('seed')),
        ],
      ),
    ),
  ),
);
