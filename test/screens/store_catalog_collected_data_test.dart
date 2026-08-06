import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/screens/widgets/restorable_scroll_body.dart';

/// Regression for ExpansionTile under [RestorableScrollBody]: without its own
/// [PageStorageKey], Expansible reads the ListView scroll offset (`double`) as
/// `bool?` and throws in debug.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ScrollOffsetMemory.clear);

  const String storageId = 'store_lightapp_none';
  const PageStorageKey<String> collectedKey = PageStorageKey<String>('store_collected_lightapp');

  testWidgets('ExpansionTile without PageStorageKey throws when scroll offset is stored', (
    WidgetTester tester,
  ) async {
    final PageStorageBucket bucket = PageStorageBucket();

    await tester.pumpWidget(_scrollSeed(bucket: bucket, storageId: storageId));
    await tester.pumpAndSettle();

    // Same identifier chain Expansible uses when the tile has no PageStorageKey:
    // ancestor RestorableScrollBody ListView key only → scroll offset (double).
    final BuildContext scrollContext = tester.element(find.byType(Scrollable));
    PageStorage.of(scrollContext).writeState(scrollContext, 42.0);

    await tester.pumpWidget(_catalogTree(bucket: bucket, storageId: storageId));
    await tester.pump();

    expect(tester.takeException(), isA<TypeError>());
  });

  testWidgets('ExpansionTile with PageStorageKey builds when scroll offset is stored', (
    WidgetTester tester,
  ) async {
    final PageStorageBucket bucket = PageStorageBucket();

    await tester.pumpWidget(_scrollSeed(bucket: bucket, storageId: storageId));
    await tester.pumpAndSettle();

    final BuildContext scrollContext = tester.element(find.byType(Scrollable));
    PageStorage.of(scrollContext).writeState(scrollContext, 42.0);

    await tester.pumpWidget(
      _catalogTree(
        bucket: bucket,
        storageId: storageId,
        expansionKey: collectedKey,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(ExpansionTile, 'Collected data'), findsOneWidget);
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

Widget _catalogTree({
  required PageStorageBucket bucket,
  required String storageId,
  Key? expansionKey,
}) => MaterialApp(
  home: PageStorage(
    bucket: bucket,
    child: Scaffold(
      body: RestorableScrollBody.list(
        storageId: storageId,
        children: <Widget>[
          ExpansionTile(
            key: expansionKey,
            title: const Text('Collected data'),
            children: const <Widget>[
              ListTile(title: Text('Watch A')),
            ],
          ),
          for (int i = 0; i < 8; i++) SizedBox(height: 48, child: Text('Row $i')),
        ],
      ),
    ),
  ),
);
