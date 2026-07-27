import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch_model.dart';

/// Persists discovered firmware versions and download links (no file downloads).
class FirmwareStore {
  FirmwareStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const _storageKey = 'firmware_history_v2';
  static const _legacyStorageKey = 'firmware_history_v1';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _prefs;
  Map<String, StoredFirmwareHistory>? _cache;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= _prefsOverride ?? await SharedPreferences.getInstance();
  }

  Future<Map<String, StoredFirmwareHistory>> _loadAll() async {
    if (_cache != null) return _cache!;
    final prefs = await _ensurePrefs();
    var raw = prefs.getString(_storageKey);
    // One-time migration from per-device (no source) history.
    if (raw == null || raw.isEmpty) {
      raw = prefs.getString(_legacyStorageKey);
    }
    if (raw == null || raw.isEmpty) {
      _cache = {};
      return _cache!;
    }
    final decoded = jsonDecode(raw);
    final map = <String, StoredFirmwareHistory>{};
    if (decoded is Map<String, dynamic>) {
      for (final entry in decoded.entries) {
        final value = entry.value;
        Map<String, dynamic>? asMap;
        if (value is Map<String, dynamic>) {
          asMap = value;
        } else if (value is Map) {
          asMap = Map<String, dynamic>.from(value);
        }
        if (asMap == null) continue;
        final history = StoredFirmwareHistory.fromJson(asMap);
        final key = history.deviceSource != null
            ? StoredFirmwareHistory.storageKey(
                history.deviceId,
                history.deviceSource!,
              )
            : entry.key;
        map[key] = history;
      }
    }
    _cache = map;
    return map;
  }

  Future<void> _saveAll(Map<String, StoredFirmwareHistory> all) async {
    _cache = all;
    final prefs = await _ensurePrefs();
    final encoded = jsonEncode({
      for (final e in all.entries) e.key: e.value.toJson(),
    });
    await prefs.setString(_storageKey, encoded);
  }

  Future<StoredFirmwareHistory?> get({
    required String deviceId,
    required int deviceSource,
  }) async {
    final all = await _loadAll();
    return all[StoredFirmwareHistory.storageKey(deviceId, deviceSource)];
  }

  Future<Map<String, StoredFirmwareHistory>> getAll() => _loadAll();

  /// Merges [discovered] into the history for [watch]/[variant].
  Future<StoredFirmwareHistory> merge({
    required WatchModel watch,
    required WatchVariant variant,
    required List<FirmwareInfo> discovered,
  }) async {
    final key = StoredFirmwareHistory.storageKey(
      watch.deviceId,
      variant.deviceSource,
    );
    final all = await _loadAll();
    final existing =
        all[key] ??
        StoredFirmwareHistory(
          deviceId: watch.deviceId,
          watchName: watch.name,
          deviceSource: variant.deviceSource,
          versions: const [],
        );
    final updated = existing.copyWithMerged(discovered);
    final stamped = StoredFirmwareHistory(
      deviceId: watch.deviceId,
      watchName: watch.name,
      deviceSource: variant.deviceSource,
      versions: updated.versions,
      checkedAt: DateTime.now(),
    );
    all[key] = stamped;
    await _saveAll(all);
    return stamped;
  }

  Future<void> clearVariant({
    required String deviceId,
    required int deviceSource,
  }) async {
    final all = await _loadAll();
    all.remove(StoredFirmwareHistory.storageKey(deviceId, deviceSource));
    await _saveAll(all);
  }
}
