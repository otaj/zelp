/// Pure navigation rules for bottom tabs that need a signed-in Amazfit account.
///
/// Tab indices (MainShell order):
/// 0 Credentials, 1 GPS, 2 Watchfaces, 3 Apps, 4 Firmware
class AuthTabGate {
  const AuthTabGate();

  static const int credentialsIndex = 0;
  static const int gpsIndex = 1;
  static const int watchfacesIndex = 2;
  static const int appsIndex = 3;
  static const int firmwareIndex = 4;

  static const int tabCount = 5;

  /// Tabs that need remembered credentials before they can be opened.
  /// Firmware is unauthenticated (`FirmwareClient`); Credentials is always open.
  static const Set<int> authRequiredIndices = <int>{gpsIndex, watchfacesIndex, appsIndex};

  bool requiresAuth(int index) => authRequiredIndices.contains(index);

  /// Returns the tab to open, or `null` if [to] is blocked while signed out.
  int? resolveSelection({
    required int from,
    required int to,
    required bool signedIn,
  }) {
    if (to < 0 || to >= tabCount) return from;
    if (!requiresAuth(to) || signedIn) return to;
    return null;
  }

  /// If the user signs out while on a locked tab, bounce to Credentials.
  int afterAuthChanged({required int current, required bool signedIn}) {
    if (!signedIn && requiresAuth(current)) return credentialsIndex;
    return current;
  }

  static String get signInRequiredMessage =>
      'Sign in on Credentials first (with “Remember credentials” on) to open this tab.';
}
