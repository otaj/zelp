import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/services/prefs_store.dart';

/// Whether expert controls are available.
///
/// Expert mode unlocks a typed firmware baseline and Zepp app version on
/// Firmware, and a region picker for store catalog refreshes.
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
