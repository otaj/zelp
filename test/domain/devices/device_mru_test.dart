import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/devices/device_mru.dart';

void main() {
  group('sortByMostRecentlyUsed', () {
    test('puts most recent first and keeps unused original order', () {
      final items = ['a', 'b', 'c', 'd'];
      final sorted = sortByMostRecentlyUsed(
        items: items,
        idOf: (s) => s,
        lastUsedAt: {
          'c': DateTime.utc(2026, 1, 3),
          'a': DateTime.utc(2026, 1, 1),
        },
      );
      expect(sorted, ['c', 'a', 'b', 'd']);
    });

    test('ties break by original index', () {
      final t = DateTime.utc(2026, 1, 1);
      final sorted = sortByMostRecentlyUsed(
        items: ['x', 'y'],
        idOf: (s) => s,
        lastUsedAt: {'x': t, 'y': t},
      );
      expect(sorted, ['x', 'y']);
    });

    test('empty and single lists are copied', () {
      expect(
        sortByMostRecentlyUsed(
          items: <String>[],
          idOf: (s) => s,
          lastUsedAt: const {},
        ),
        isEmpty,
      );
      expect(
        sortByMostRecentlyUsed(
          items: ['only'],
          idOf: (s) => s,
          lastUsedAt: const {},
        ),
        ['only'],
      );
    });
  });
}
