import 'package:zelp/services/zepp_client.dart';

/// Login → [body] → logout (logout errors swallowed).
///
/// Shared by Settings and GPS so both follow the same session lifecycle.
Future<void> runZeppSession({
  required String username,
  required String password,
  required Future<void> Function(ZeppSession session) body,
  ZeppSession Function(String username, String password)? sessionFactory,
}) async {
  final ZeppSession session =
      sessionFactory?.call(username, password) ?? ZeppSession(username: username, password: password);
  await session.login();
  await body(session);
  try {
    await session.logout();
  } on Exception catch (_) {}
}
