import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/services/prefs_store.dart';

/// Whether manual firmware and Zepp version entry is available.
class ExpertModeStore extends PrefsStore {
  ExpertModeStore({super.prefs});

  static const String prefsKey = 'expert_mode';

  Future<bool> load() async {
    final SharedPreferences prefs = await ensurePrefs();
    return prefs.getBool(prefsKey) ?? false;
  }

  Future<bool> save({required bool enabled}) async {
    final SharedPreferences prefs = await ensurePrefs();
    await prefs.setBool(prefsKey, enabled);
    return enabled;
  }
}
