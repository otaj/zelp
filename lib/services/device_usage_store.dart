import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:zelp/domain/devices/device_mru.dart';

/// Persists last-used timestamps for pairing devices and catalog watches.
class DeviceUsageStore {
  DeviceUsageStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const String _storageKey = 'device_usage_mru_v1';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;
  Map<String, DateTime>? _cache;

  /// Stable key for a Bluetooth pairing device (MAC).
  static String pairingKey(String mac) => 'pairing:${mac.trim().toUpperCase()}';

  /// Stable key for a firmware catalog watch.
  static String watchKey(String deviceId) => 'watch:${deviceId.trim()}';

  Future<SharedPreferences> _ensurePrefs() async => _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();

  Future<Map<String, DateTime>> _load() async {
    if (_cache != null) return _cache!;
    final SharedPreferences prefs = await _ensurePrefs();
    final String? raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _cache = <String, DateTime>{};
      return _cache!;
    }
    final dynamic decoded = jsonDecode(raw);
    final Map<String, DateTime> map = <String, DateTime>{};
    if (decoded is Map) {
      for (final MapEntry<dynamic, dynamic> entry in decoded.entries) {
        final String key = entry.key.toString();
        final dynamic value = entry.value;
        if (value is String) {
          final DateTime? parsed = DateTime.tryParse(value);
          if (parsed != null) map[key] = parsed;
        }
      }
    }
    _cache = map;
    return map;
  }

  Future<void> _save(Map<String, DateTime> all) async {
    _cache = all;
    final SharedPreferences prefs = await _ensurePrefs();
    await prefs.setString(
      _storageKey,
      jsonEncode(<String, String>{
        for (final MapEntry<String, DateTime> e in all.entries) e.key: e.value.toIso8601String(),
      }),
    );
  }

  Future<Map<String, DateTime>> snapshot() async => Map<String, DateTime>.unmodifiable(await _load());

  Future<void> touch(String key, {DateTime? at}) async {
    final Map<String, DateTime> all = Map<String, DateTime>.of(await _load());
    all[key] = at ?? DateTime.now();
    await _save(all);
  }

  Future<void> touchPairing(String mac, {DateTime? at}) => touch(pairingKey(mac), at: at);

  Future<void> touchWatch(String deviceId, {DateTime? at}) => touch(watchKey(deviceId), at: at);

  /// Member.
  Future<List<T>> sortPairingDevices<T>({
    required List<T> devices,
    required String Function(T device) macOf,
  }) async {
    final Map<String, DateTime> usage = await _load();
    return sortByMostRecentlyUsed(
      items: devices,
      idOf: (T d) => pairingKey(macOf(d)),
      lastUsedAt: usage,
    );
  }

  /// Member.
  Future<List<T>> sortWatches<T>({
    required List<T> watches,
    required String Function(T watch) deviceIdOf,
  }) async {
    final Map<String, DateTime> usage = await _load();
    return sortByMostRecentlyUsed(
      items: watches,
      idOf: (T w) => watchKey(deviceIdOf(w)),
      lastUsedAt: usage,
    );
  }

  /// Preferred default watch among [watches], or null if none were used yet.
  Future<T?> preferMostRecentWatch<T>({
    required List<T> watches,
    required String Function(T watch) deviceIdOf,
  }) async {
    final Map<String, DateTime> usage = await _load();
    return mostRecentlyUsedAmong(
      items: watches,
      idOf: (T w) => watchKey(deviceIdOf(w)),
      lastUsedAt: usage,
    );
  }

  /// Preferred default pairing device among [devices], or null if none used.
  Future<T?> preferMostRecentPairing<T>({
    required List<T> devices,
    required String Function(T device) macOf,
  }) async {
    final Map<String, DateTime> usage = await _load();
    return mostRecentlyUsedAmong(
      items: devices,
      idOf: (T d) => pairingKey(macOf(d)),
      lastUsedAt: usage,
    );
  }
}
