import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zelp/models/store_item.dart';
import 'package:zelp/screens/widgets/zepp_install_qr_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'watchface install QR dialog lays out under AlertDialog intrinsinsics',
    (WidgetTester tester) async {
      const StoreItem item = StoreItem(
        appId: 99,
        entryType: StoreEntryType.watch,
        deviceSource: 229,
        version: '2.0',
        name: 'Face',
        downloadUrl: 'https://cdn.example.com/watchfaces/long-name-package-file.zpk',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () {
                  unawaited(showZeppInstallQrDialog(context, item: item));
                },
                child: const Text('Open QR'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open QR'));
      // First pump builds the dialog; a second settles layout. Must not throw
      // LayoutBuilder intrinsic-dimension assertion in debug.
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Install with Zepp'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        find.text(
          'watchface://cdn.example.com/watchfaces/long-name-package-file.zpk',
        ),
        findsOneWidget,
      );
    },
  );
}
