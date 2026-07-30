import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/devices/device_mru.dart';

void main() {
  group('sortByMostRecentlyUsed', () {
    test('puts most recent first and keeps unused original order', () {
      final List<String> items = <String>['a', 'b', 'c', 'd'];
      final List<String> sorted = sortByMostRecentlyUsed(
        items: items,
        idOf: (String s) => s,
        lastUsedAt: <String, DateTime>{
          'c': DateTime.utc(2026, 1, 3),
          'a': DateTime.utc(2026),
        },
      );
      expect(sorted, <String>['c', 'a', 'b', 'd']);
    });

    test('ties break by original index', () {
      final DateTime t = DateTime.utc(2026);
      final List<String> sorted = sortByMostRecentlyUsed(
        items: <String>['x', 'y'],
        idOf: (String s) => s,
        lastUsedAt: <String, DateTime>{'x': t, 'y': t},
      );
      expect(sorted, <String>['x', 'y']);
    });

    test('empty and single lists are copied', () {
      expect(
        sortByMostRecentlyUsed(
          items: <String>[],
          idOf: (String s) => s,
          lastUsedAt: const <String, DateTime>{},
        ),
        isEmpty,
      );
      expect(
        sortByMostRecentlyUsed(
          items: <String>['only'],
          idOf: (String s) => s,
          lastUsedAt: const <String, DateTime>{},
        ),
        <String>['only'],
      );
    });
  });

  group('mostRecentlyUsedAmong', () {
    test('returns null when nothing was used', () {
      expect(
        mostRecentlyUsedAmong(
          items: <String>['a', 'b'],
          idOf: (String s) => s,
          lastUsedAt: const <String, DateTime>{},
        ),
        isNull,
      );
    });

    test('picks the newest timestamp among available items', () {
      expect(
        mostRecentlyUsedAmong(
          items: <String>['a', 'b', 'c'],
          idOf: (String s) => s,
          lastUsedAt: <String, DateTime>{
            'a': DateTime.utc(2026),
            'c': DateTime.utc(2026, 1, 5),
            'gone': DateTime.utc(2026, 1, 9),
          },
        ),
        'c',
      );
    });
  });
}
