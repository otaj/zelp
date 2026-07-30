/// Pure navigation rules for bottom tabs that need a signed-in Amazfit account.
///
/// Tab indices (MainShell order):
/// 0 GPS, 1 Watchfaces, 2 Apps, 3 Firmware
///
/// Account / download-folder configuration lives on the Settings screen
/// (not a tab), opened via the settings button.
class AuthTabGate {
  const AuthTabGate();

  static const int gpsIndex = 0;
  static const int watchfacesIndex = 1;
  static const int appsIndex = 2;
  static const int firmwareIndex = 3;

  static const int tabCount = 4;

  /// Tabs that need remembered credentials before they can be opened.
  /// Firmware is unauthenticated (`FirmwareClient`).
  static const Set<int> authRequiredIndices = <int>{gpsIndex, watchfacesIndex, appsIndex};

  bool requiresAuth(int index) => authRequiredIndices.contains(index);

  /// Default tab after bootstrap: GPS when signed in, otherwise Firmware.
  int initialIndex({required bool signedIn}) => signedIn ? gpsIndex : firmwareIndex;

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

  /// If the user signs out while on a locked tab, bounce to Firmware.
  int afterAuthChanged({required int current, required bool signedIn}) {
    if (!signedIn && requiresAuth(current)) return firmwareIndex;
    return current;
  }

  static String get signInRequiredMessage => 'Sign in in Settings first to open this tab.';
}
