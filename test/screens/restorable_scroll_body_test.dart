import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/screens/widgets/restorable_scroll_body.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ScrollOffsetMemory.clear);

  Widget wrap(Widget body) => MaterialApp(
    home: Scaffold(body: body),
  );

  List<Widget> tallChildren({int count = 40}) => <Widget>[
    for (int i = 0; i < count; i++)
      SizedBox(
        height: 48,
        child: Text('Row $i', key: ValueKey<String>('row_$i')),
      ),
  ];

  testWidgets('hides jump controls when content fits on screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const RestorableScrollBody.list(
          storageId: 'short',
          showJumpControls: true,
          children: <Widget>[
            SizedBox(height: 40, child: Text('Only row')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Scroll to top'), findsNothing);
    expect(find.byTooltip('Scroll to bottom'), findsNothing);
  });

  testWidgets('shows bottom jump near top and top jump near bottom', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        RestorableScrollBody.list(
          storageId: 'tall',
          showJumpControls: true,
          children: tallChildren(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Scroll to bottom'), findsOneWidget);
    expect(find.byTooltip('Scroll to top'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Scroll to top'), findsOneWidget);
    expect(find.byTooltip('Scroll to bottom'), findsNothing);
  });

  testWidgets('jump buttons scroll to edges', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        RestorableScrollBody.list(
          storageId: 'jump',
          showJumpControls: true,
          children: tallChildren(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Scroll to bottom'));
    await tester.pumpAndSettle();

    final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    expect(find.byTooltip('Scroll to top'), findsOneWidget);

    await tester.tap(find.byTooltip('Scroll to top'));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, 0);
    expect(find.byTooltip('Scroll to bottom'), findsOneWidget);
  });

  testWidgets('slivers body jump reaches end with many lazy children', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        RestorableScrollBody.slivers(
          storageId: 'sliver_jump',
          showJumpControls: true,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) => SizedBox(
                    height: 48,
                    child: Text('Row $index', key: ValueKey<String>('srow_$index')),
                  ),
                  childCount: 80,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Scroll to bottom'), findsOneWidget);
    await tester.tap(find.byTooltip('Scroll to bottom'));
    // One 280ms jump animation, then jumpTo corrections for lazy extent growth.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (int i = 0; i < 16; i++) {
      await tester.pump();
    }

    final ScrollableState scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
    expect(find.byTooltip('Scroll to top'), findsOneWidget);
  });

  testWidgets('restores offset after dispose and recreate', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        RestorableScrollBody.list(
          storageId: 'restore_me',
          children: tallChildren(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -640));
    await tester.pumpAndSettle();
    final double mid = tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    expect(mid, greaterThan(100));

    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      wrap(
        RestorableScrollBody.list(
          storageId: 'restore_me',
          children: tallChildren(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      closeTo(mid, 1),
    );
  });

  testWidgets('omits RefreshIndicator when onRefresh is null', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        RestorableScrollBody.list(
          storageId: 'no_refresh',
          children: tallChildren(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsNothing);
  });

  testWidgets('pull-to-refresh invokes onRefresh', (WidgetTester tester) async {
    final Completer<void> done = Completer<void>();
    int refreshes = 0;

    await tester.pumpWidget(
      wrap(
        RestorableScrollBody.list(
          storageId: 'refresh_list',
          onRefresh: () {
            refreshes++;
            return done.future;
          },
          children: tallChildren(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.fling(find.byType(Scrollable), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshes, 1);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    done.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('pull-to-refresh works when content is shorter than the viewport', (
    WidgetTester tester,
  ) async {
    int refreshes = 0;

    await tester.pumpWidget(
      wrap(
        RestorableScrollBody.list(
          storageId: 'refresh_short',
          onRefresh: () async {
            refreshes++;
          },
          children: const <Widget>[
            SizedBox(height: 40, child: Text('Only row')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(find.text('Only row'), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(refreshes, 1);
  });

  testWidgets('pull-to-refresh works with jump controls and slivers', (WidgetTester tester) async {
    int refreshes = 0;

    await tester.pumpWidget(
      wrap(
        RestorableScrollBody.slivers(
          storageId: 'refresh_slivers',
          showJumpControls: true,
          onRefresh: () async {
            refreshes++;
          },
          slivers: <Widget>[
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => SizedBox(
                  height: 48,
                  child: Text('Row $index', key: ValueKey<String>('srow_$index')),
                ),
                childCount: 40,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(find.byType(Scrollable), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(refreshes, 1);
  });
}
