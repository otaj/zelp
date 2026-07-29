import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/services/credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CredentialStore', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test('save then load returns credentials', () async {
      final CredentialStore store = CredentialStore();
      await store.save(
        Credentials(email: 'user@amazfit.com', password: 'secret'),
      );
      final Credentials? loaded = await store.load();
      expect(loaded?.email, 'user@amazfit.com');
      expect(loaded?.password, 'secret');
    });

    test('load returns null when remember flag unset', () async {
      final CredentialStore store = CredentialStore();
      expect(await store.load(), isNull);
    });

    test('clear removes credentials', () async {
      final CredentialStore store = CredentialStore();
      await store.save(
        Credentials(email: 'user@amazfit.com', password: 'secret'),
      );
      await store.clear();
      expect(await store.load(), isNull);
    });

    test('Credentials validates email', () {
      expect(
        () => Credentials(email: 'bad', password: 'x'),
        throwsArgumentError,
      );
    });
  });
}
