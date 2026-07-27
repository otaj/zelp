/// Pure most-recently-used ordering for device lists (no I/O).
///
/// Items with a [lastUsedAt] timestamp sort newest-first. Items never used
/// keep their relative [original] order as a stable fallback.
List<T> sortByMostRecentlyUsed<T>({
  required List<T> items,
  required String Function(T item) idOf,
  required Map<String, DateTime> lastUsedAt,
}) {
  if (items.length < 2) return List<T>.of(items);

  final indexed = <({T item, int index, DateTime? usedAt})>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    indexed.add((item: item, index: i, usedAt: lastUsedAt[idOf(item)]));
  }

  indexed.sort((a, b) {
    final aUsed = a.usedAt;
    final bUsed = b.usedAt;
    if (aUsed != null && bUsed != null) {
      final byTime = bUsed.compareTo(aUsed);
      if (byTime != 0) return byTime;
      return a.index.compareTo(b.index);
    }
    if (aUsed != null) return -1;
    if (bUsed != null) return 1;
    return a.index.compareTo(b.index);
  });

  return [for (final entry in indexed) entry.item];
}
