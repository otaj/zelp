import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether first-time setup (login or continue without login) is done.
class AppSetupStore {
  AppSetupStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const String prefsComplete = 'app_setup_complete';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async => _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();

  Future<bool> isComplete() async {
    final SharedPreferences prefs = await _ensurePrefs();
    return prefs.getBool(prefsComplete) ?? false;
  }

  Future<void> markComplete() async {
    final SharedPreferences prefs = await _ensurePrefs();
    await prefs.setBool(prefsComplete, true);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await _ensurePrefs();
    await prefs.remove(prefsComplete);
  }
}
