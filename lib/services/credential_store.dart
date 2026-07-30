import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:zelp/domain/primitives/email_address.dart';

class Credentials {
  Credentials({required String email, required this.password}) : emailAddress = EmailAddress(email);

  Credentials.fromValidated({
    required this.emailAddress,
    required this.password,
  });

  final EmailAddress emailAddress;
  final String password;

  String get email => emailAddress.value;

  bool get isEmpty => email.isEmpty || password.isEmpty;
}

class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const String _emailKey = 'amazfit_email';
  static const String _passwordKey = 'amazfit_password';
  static const String _rememberKey = 'amazfit_remember';

  final FlutterSecureStorage _storage;

  Future<Credentials?> load() async {
    final String? remember = await _storage.read(key: _rememberKey);
    if (remember != 'true') return null;

    final String email = await _storage.read(key: _emailKey) ?? '';
    final String password = await _storage.read(key: _passwordKey) ?? '';
    if (email.isEmpty || password.isEmpty || !EmailAddress.isValid(email)) return null;
    return Credentials(email: email, password: password);
  }

  Future<void> save(Credentials credentials) async {
    await _storage.write(key: _emailKey, value: credentials.email);
    await _storage.write(key: _passwordKey, value: credentials.password);
    await _storage.write(key: _rememberKey, value: 'true');
  }

  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _rememberKey);
  }
}
