import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/services/app_setup_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSetupStore', () {
    test('is incomplete by default and can be marked complete', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppSetupStore store = AppSetupStore();

      expect(await store.isComplete(), isFalse);
      await store.markComplete();
      expect(await store.isComplete(), isTrue);
      await store.clear();
      expect(await store.isComplete(), isFalse);
    });
  });
}
