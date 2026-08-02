import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences bootstrap for stores that inject prefs in tests.
abstract class PrefsStore {
  PrefsStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;

  Future<SharedPreferences> ensurePrefs() async => _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();
}
