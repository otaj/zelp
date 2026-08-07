import 'package:shared_preferences/shared_preferences.dart';

/// Resets prefs mocks and returns a fresh empty [SharedPreferences] instance.
Future<SharedPreferences> mockEmptyPrefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}
