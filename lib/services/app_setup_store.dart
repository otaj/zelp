import 'package:shared_preferences/shared_preferences.dart';

import 'package:zelp/services/prefs_store.dart';

/// Persists whether first-time setup (login or continue without login) is done.
class AppSetupStore extends PrefsStore {
  AppSetupStore({super.prefs});

  static const String prefsComplete = 'app_setup_complete';

  Future<bool> isComplete() async {
    final SharedPreferences prefs = await ensurePrefs();
    return prefs.getBool(prefsComplete) ?? false;
  }

  Future<void> markComplete() async {
    final SharedPreferences prefs = await ensurePrefs();
    await prefs.setBool(prefsComplete, true);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await ensurePrefs();
    await prefs.remove(prefsComplete);
  }
}
