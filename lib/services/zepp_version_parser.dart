import 'dart:convert';

import 'package:zelp/domain/exceptions.dart';

/// Play Store HTML parsing for the Zepp Android version name (`10.7.3-play`).
class ZeppVersionParser {
  const ZeppVersionParser();

  static const String packageId = 'com.huami.watch.hmwatchmanager';
  static final RegExp _versionName = RegExp(r'^\d+\.\d+\.\d+(?:-[A-Za-z0-9]+)?$');

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
    if (value is String && _versionName.hasMatch(value)) return value;
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
