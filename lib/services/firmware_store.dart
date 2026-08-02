import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:zelp/models/watch_model.dart';
import 'package:zelp/services/prefs_store.dart';

/// Persists discovered firmware versions and download links (no file downloads).
class FirmwareStore extends PrefsStore {
  FirmwareStore({super.prefs});

  static const String _storageKey = 'firmware_history_v2';
  static const String _legacyStorageKey = 'firmware_history_v1';

  Map<String, StoredFirmwareHistory>? _cache;

  Future<Map<String, StoredFirmwareHistory>> _loadAll() async {
    if (_cache != null) return _cache!;
    final SharedPreferences prefs = await ensurePrefs();
    String? raw = prefs.getString(_storageKey);
    // One-time migration from per-device (no source) history.
    if (raw == null || raw.isEmpty) {
      raw = prefs.getString(_legacyStorageKey);
    }
    if (raw == null || raw.isEmpty) {
      _cache = <String, StoredFirmwareHistory>{};
      return _cache!;
    }
    final dynamic decoded = jsonDecode(raw);
    final Map<String, StoredFirmwareHistory> map = <String, StoredFirmwareHistory>{};
    if (decoded is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in decoded.entries) {
        final dynamic value = entry.value;
        Map<String, dynamic>? asMap;
        if (value is Map<String, dynamic>) {
          asMap = value;
        } else if (value is Map) {
          asMap = Map<String, dynamic>.from(value);
        }
        if (asMap == null) continue;
        final StoredFirmwareHistory history = StoredFirmwareHistory.fromJson(asMap);
        final String key = history.deviceSource != null
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
    final SharedPreferences prefs = await ensurePrefs();
    final String encoded = jsonEncode(<String, Map<String, dynamic>>{
      for (final MapEntry<String, StoredFirmwareHistory> e in all.entries) e.key: e.value.toJson(),
    });
    await prefs.setString(_storageKey, encoded);
  }

  Future<StoredFirmwareHistory?> get({
    required String deviceId,
    required int deviceSource,
  }) async {
    final Map<String, StoredFirmwareHistory> all = await _loadAll();
    return all[StoredFirmwareHistory.storageKey(deviceId, deviceSource)];
  }

  Future<Map<String, StoredFirmwareHistory>> getAll() => _loadAll();

  /// Merges [discovered] into the history for [watch]/[variant].
  Future<StoredFirmwareHistory> merge({
    required WatchModel watch,
    required WatchVariant variant,
    required List<FirmwareInfo> discovered,
  }) async {
    final String key = StoredFirmwareHistory.storageKey(
      watch.deviceId,
      variant.deviceSource,
    );
    final Map<String, StoredFirmwareHistory> all = await _loadAll();
    final StoredFirmwareHistory existing =
        all[key] ??
        StoredFirmwareHistory(
          deviceId: watch.deviceId,
          watchName: watch.name,
          deviceSource: variant.deviceSource,
          versions: const <FirmwareInfo>[],
        );
    final StoredFirmwareHistory updated = existing.copyWithMerged(discovered);
    final StoredFirmwareHistory stamped = StoredFirmwareHistory(
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
    final Map<String, StoredFirmwareHistory> all = await _loadAll();
    all.remove(StoredFirmwareHistory.storageKey(deviceId, deviceSource));
    await _saveAll(all);
  }
}
