import 'dart:convert';

import 'package:zelp/services/zepp_version_parser.dart';

/// Play catalog JSON with `lastVersion` and a version history list.
String playCatalogJson({
  String version = '10.10.5-play',
  int versionCode = 151997,
  String packageId = ZeppVersionParser.packageId,
  bool includeLastVersion = true,
  bool includeHistory = true,
  List<({String version, int versionCode})> history = const <({String version, int versionCode})>[],
}) {
  final Map<String, Object> release = <String, Object>{
    'packageName': packageId,
    'versionString': version,
    'versionCode': versionCode,
  };
  final List<Map<String, Object>> rows = <Map<String, Object>>[
    if (includeHistory) release,
    for (final ({String version, int versionCode}) older in history)
      <String, Object>{
        'packageName': packageId,
        'versionString': older.version,
        'versionCode': older.versionCode,
      },
  ];
  return jsonEncode(<Object?>[
    <String, Object>{
      'packageName': packageId,
      'title': 'Zepp',
      if (includeLastVersion) 'lastVersion': release,
    },
    if (includeHistory || history.isNotEmpty) rows,
  ]);
}
