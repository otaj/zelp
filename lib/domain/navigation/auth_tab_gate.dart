/// Pure navigation rules for bottom tabs that need a signed-in Amazfit account.
///
/// Tab indices (MainShell order):
/// 0 Credentials
class AuthTabGate {
  const AuthTabGate();

  static const credentialsIndex = 0;

  static const tabCount = 1;

  /// Tabs that need remembered credentials before they can be opened.
  static const authRequiredIndices = <int>{};

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
