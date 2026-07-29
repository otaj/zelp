/// Pure most-recently-used ordering for device lists (no I/O).
///
/// Items with a [lastUsedAt] timestamp sort newest-first. Items never used
/// keep their relative `original` order as a stable fallback.
List<T> sortByMostRecentlyUsed<T>({
  required List<T> items,
  required String Function(T item) idOf,
  required Map<String, DateTime> lastUsedAt,
}) {
  if (items.length < 2) return List<T>.of(items);

  final List<({int index, T item, DateTime? usedAt})> indexed = <({T item, int index, DateTime? usedAt})>[];
  for (int i = 0; i < items.length; i++) {
    final T item = items[i];
    indexed.add((item: item, index: i, usedAt: lastUsedAt[idOf(item)]));
  }

  indexed.sort((({int index, T item, DateTime? usedAt}) a, ({int index, T item, DateTime? usedAt}) b) {
    final DateTime? aUsed = a.usedAt;
    final DateTime? bUsed = b.usedAt;
    if (aUsed != null && bUsed != null) {
      final int byTime = bUsed.compareTo(aUsed);
      if (byTime != 0) return byTime;
      return a.index.compareTo(b.index);
    }
    if (aUsed != null) return -1;
    if (bUsed != null) return 1;
    return a.index.compareTo(b.index);
  });

  return <T>[for (final ({int index, T item, DateTime? usedAt}) entry in indexed) entry.item];
}

/// Returns the item with the newest [lastUsedAt] timestamp among [items].
///
/// Returns null when none of the items have been used yet, or [items] is empty.
T? mostRecentlyUsedAmong<T>({
  required List<T> items,
  required String Function(T item) idOf,
  required Map<String, DateTime> lastUsedAt,
}) {
  T? best;
  DateTime? bestAt;
  for (final T item in items) {
    final DateTime? at = lastUsedAt[idOf(item)];
    if (at == null) continue;
    if (bestAt == null || at.isAfter(bestAt)) {
      best = item;
      bestAt = at;
    }
  }
  return best;
}
