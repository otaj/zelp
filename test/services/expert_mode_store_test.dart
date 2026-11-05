import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/services/expert_mode_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('expert mode defaults off and round-trips', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ExpertModeStore store = ExpertModeStore(prefs: await SharedPreferences.getInstance());
    expect(await store.load(), isFalse);

    expect(await store.save(enabled: true), isTrue);
    expect(await store.load(), isTrue);

    final ExpertModeStore reloaded = ExpertModeStore(prefs: await SharedPreferences.getInstance());
    expect(await reloaded.load(), isTrue);
    await reloaded.save(enabled: false);
    expect(await store.load(), isFalse);
  });
}
