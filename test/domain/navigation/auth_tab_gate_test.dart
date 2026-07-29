import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/navigation/auth_tab_gate.dart';

void main() {
  group('AuthTabGate', () {
    const AuthTabGate gate = AuthTabGate();

    test('credentials and firmware are open; GPS/store tabs require auth', () {
      expect(gate.requiresAuth(AuthTabGate.credentialsIndex), isFalse);
      expect(gate.requiresAuth(AuthTabGate.firmwareIndex), isFalse);
      expect(gate.requiresAuth(AuthTabGate.gpsIndex), isTrue);
      expect(gate.requiresAuth(AuthTabGate.watchfacesIndex), isTrue);
      expect(gate.requiresAuth(AuthTabGate.appsIndex), isTrue);
    });

    test('tab indices match MainShell order', () {
      expect(AuthTabGate.credentialsIndex, 0);
      expect(AuthTabGate.gpsIndex, 1);
      expect(AuthTabGate.watchfacesIndex, 2);
      expect(AuthTabGate.appsIndex, 3);
      expect(AuthTabGate.firmwareIndex, 4);
      expect(AuthTabGate.tabCount, 5);
    });

    test('blocks gated tabs while signed out', () {
      expect(
        gate.resolveSelection(
          from: 0,
          to: AuthTabGate.appsIndex,
          signedIn: false,
        ),
        isNull,
      );
      expect(
        gate.resolveSelection(
          from: 0,
          to: AuthTabGate.appsIndex,
          signedIn: true,
        ),
        AuthTabGate.appsIndex,
      );
    });

    test('allows firmware while signed out', () {
      expect(
        gate.resolveSelection(
          from: 0,
          to: AuthTabGate.firmwareIndex,
          signedIn: false,
        ),
        AuthTabGate.firmwareIndex,
      );
    });

    test('bounces to credentials after logout', () {
      expect(
        gate.afterAuthChanged(
          current: AuthTabGate.watchfacesIndex,
          signedIn: false,
        ),
        AuthTabGate.credentialsIndex,
      );
      expect(
        gate.afterAuthChanged(
          current: AuthTabGate.watchfacesIndex,
          signedIn: true,
        ),
        AuthTabGate.watchfacesIndex,
      );
      expect(
        gate.afterAuthChanged(
          current: AuthTabGate.firmwareIndex,
          signedIn: false,
        ),
        AuthTabGate.firmwareIndex,
      );
    });
  });
}
