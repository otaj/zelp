import 'dart:convert';

import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/primitives/app_version.dart';

/// Parses the official Zepp Play version name and versionCode.
///
/// The Play Store details page publishes the version name only. The numeric
/// versionCode comes from the public Play catalog, which lists the same name
/// as `lastVersion` and again in its history.
class ZeppVersionParser {
  const ZeppVersionParser();

  static const String packageId = 'com.huami.watch.hmwatchmanager';

  /// Parses a Play Store details page and returns the current version name.
  String parseVersionName(String html) {
    if (!html.contains(packageId)) {
      throw DeviceException(
        'Unexpected Play Store page (possible block)',
        code: 'zepp-version-play',
      );
    }
    for (final Object? data in _dsDataBlobs(html)) {
      final String? version = _versionFromDetails(data);
      if (version != null) return version;
    }
    throw DeviceException(
      'Could not parse Zepp version from Play Store',
      code: 'zepp-version-parse',
    );
  }

  /// Reads `versionString` and `versionCode` for [packageId].
  ///
  /// [body] is the Play catalog JSON: an app object with `lastVersion`, plus
  /// a history list. When both are present they must name the same build.
  /// History uses the highest versionCode, so row order does not matter.
  AppVersion parseCatalogRelease(String body) {
    final Object? decoded = _decodeCatalog(body);
    if (decoded is! List) {
      throw DeviceException(
        'Could not parse Zepp version catalog',
        code: 'zepp-version-parse',
      );
    }

    AppVersion? listed;
    AppVersion? newest;
    for (final Object? item in decoded) {
      if (item is Map) {
        final Object? last = item['lastVersion'];
        if (last is Map) listed = _catalogRelease(last);
        continue;
      }
      if (item is! List) continue;
      for (final Object? row in item) {
        if (row is! Map) continue;
        final AppVersion release = _catalogRelease(row);
        newest = _newerRelease(newest, release);
      }
    }

    if (listed != null && newest != null) {
      if (listed != newest) {
        throw DeviceException(
          'Zepp version catalog disagreed (${listed.value} vs ${newest.value})',
          code: 'zepp-version-parse',
        );
      }
      return listed;
    }
    final AppVersion? only = listed ?? newest;
    if (only == null) {
      throw DeviceException(
        'Could not parse Zepp version catalog',
        code: 'zepp-version-parse',
      );
    }
    return only;
  }

  Object? _decodeCatalog(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw DeviceException(
        'Could not parse Zepp version catalog',
        code: 'zepp-version-parse',
      );
    }
  }

  AppVersion _newerRelease(AppVersion? current, AppVersion release) {
    if (current == null) return release;
    if (release.buildCode != null && release.buildCode == current.buildCode && release != current) {
      throw DeviceException(
        'Zepp version catalog disagreed (${current.value} vs ${release.value})',
        code: 'zepp-version-parse',
      );
    }
    return release.isNewerThan(current) ? release : current;
  }

  AppVersion _catalogRelease(Map<dynamic, dynamic> row) {
    final Object? package = row['packageName'];
    if (package != packageId) {
      throw DeviceException(
        'Unexpected Zepp version catalog package',
        code: 'zepp-version-parse',
      );
    }
    final Object? name = row['versionString'];
    final Object? code = row['versionCode'];
    if (name is! String || !AppVersion.versionNamePattern.hasMatch(name)) {
      throw DeviceException(
        'Could not parse Zepp version name from catalog',
        code: 'zepp-version-parse',
      );
    }
    if (code is! int || code <= 0) {
      throw DeviceException(
        'Could not parse Zepp version code from catalog',
        code: 'zepp-version-parse',
      );
    }
    return AppVersion.play(name: name, code: code);
  }

  Iterable<Object?> _dsDataBlobs(String html) sync* {
    const String marker = 'AF_initDataCallback(';
    int from = 0;
    while (true) {
      final int start = html.indexOf(marker, from);
      if (start < 0) return;
      final int bodyStart = start + marker.length;
      from = bodyStart;
      final int nextCallback = html.indexOf(marker, bodyStart);
      final int dataIdx = html.indexOf('data:', bodyStart);
      if (dataIdx < 0) return;
      if (nextCallback >= 0 && dataIdx > nextCallback) continue;
      final int arrayStart = html.indexOf('[', dataIdx);
      if (arrayStart < 0 || (nextCallback >= 0 && arrayStart > nextCallback)) {
        continue;
      }
      final String? json = _extractJsonArray(html, arrayStart);
      if (json == null) continue;
      try {
        yield jsonDecode(json);
      } on FormatException {
        continue;
      }
    }
  }

  String? _extractJsonArray(String source, int start) {
    if (start >= source.length || source[start] != '[') return null;
    int depth = 0;
    bool inString = false;
    bool escape = false;
    for (int i = start; i < source.length; i++) {
      final String ch = source[i];
      if (inString) {
        if (escape) {
          escape = false;
          continue;
        }
        if (ch == r'\') {
          escape = true;
          continue;
        }
        if (ch == '"') inString = false;
        continue;
      }
      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '[') depth++;
      if (ch == ']') {
        depth--;
        if (depth == 0) return source.substring(start, i + 1);
      }
    }
    return null;
  }

  String? _versionFromDetails(Object? data) {
    final Object? inner = _at(data, const <int>[1, 2]);
    if (inner is! List) return null;
    final String? fromIndex = _versionAt(inner, 140);
    if (fromIndex != null) return fromIndex;
    if (inner.isEmpty) return null;
    final Object? last = inner.last;
    if (last is Map) {
      final Object? keyed = last['141'] ?? last['140'];
      return _versionString(keyed);
    }
    return null;
  }

  String? _versionAt(List<dynamic> inner, int index) {
    if (index < 0 || index >= inner.length) return null;
    return _versionString(inner[index]);
  }

  String? _versionString(Object? node) {
    final Object? value = _at(node, const <int>[0, 0, 0]);
    if (value is String && AppVersion.versionNamePattern.hasMatch(value)) return value;
    return null;
  }

  Object? _at(Object? node, List<int> path) {
    Object? current = node;
    for (final int index in path) {
      if (current is! List) return null;
      if (index < 0 || index >= current.length) return null;
      current = current[index];
    }
    return current;
  }
}
