import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/navigation/auth_tab_gate.dart';

void main() {
  group('AuthTabGate', () {
    const AuthTabGate gate = AuthTabGate();

    test('firmware is open; GPS/store tabs require auth', () {
      expect(gate.requiresAuth(AuthTabGate.firmwareIndex), isFalse);
      expect(gate.requiresAuth(AuthTabGate.gpsIndex), isTrue);
      expect(gate.requiresAuth(AuthTabGate.watchfacesIndex), isTrue);
      expect(gate.requiresAuth(AuthTabGate.appsIndex), isTrue);
    });

    test('tab indices match MainShell order', () {
      expect(AuthTabGate.gpsIndex, 0);
      expect(AuthTabGate.watchfacesIndex, 1);
      expect(AuthTabGate.appsIndex, 2);
      expect(AuthTabGate.firmwareIndex, 3);
      expect(AuthTabGate.tabCount, 4);
    });

    test('initial index is GPS when signed in, Firmware when not', () {
      expect(gate.initialIndex(signedIn: true), AuthTabGate.gpsIndex);
      expect(gate.initialIndex(signedIn: false), AuthTabGate.firmwareIndex);
    });

    test('blocks gated tabs while signed out', () {
      expect(
        gate.resolveSelection(
          from: AuthTabGate.firmwareIndex,
          to: AuthTabGate.appsIndex,
          signedIn: false,
        ),
        isNull,
      );
      expect(
        gate.resolveSelection(
          from: AuthTabGate.firmwareIndex,
          to: AuthTabGate.appsIndex,
          signedIn: true,
        ),
        AuthTabGate.appsIndex,
      );
    });

    test('allows firmware while signed out', () {
      expect(
        gate.resolveSelection(
          from: AuthTabGate.gpsIndex,
          to: AuthTabGate.firmwareIndex,
          signedIn: false,
        ),
        AuthTabGate.firmwareIndex,
      );
    });

    test('bounces to firmware after logout', () {
      expect(
        gate.afterAuthChanged(
          current: AuthTabGate.watchfacesIndex,
          signedIn: false,
        ),
        AuthTabGate.firmwareIndex,
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

    test('sign-in required message points at Settings', () {
      expect(AuthTabGate.signInRequiredMessage, contains('Settings'));
    });
  });
}
