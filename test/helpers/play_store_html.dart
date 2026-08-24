import 'dart:convert';

import 'package:zelp/services/zepp_version_parser.dart';

/// Compact Play Store details HTML with an `AF_initDataCallback` version blob.
String playStoreHtml({
  String version = '10.7.3-play',
  String packageId = ZeppVersionParser.packageId,
  int dsKey = 5,
  bool asKeyedFallback = false,
}) {
  final List<Object?> inner;
  if (asKeyedFallback) {
    inner = <Object?>[
      <Object?>['Zepp'],
      <String, Object?>{
        '141': <Object?>[
          <Object?>[
            <Object?>[version],
          ],
        ],
      },
    ];
  } else {
    inner = List<Object?>.filled(141, null)
      ..[0] = <Object?>['Zepp']
      ..[140] = <Object?>[
        <Object?>[
          <Object?>[version],
        ],
      ];
  }
  final String data = jsonEncode(<Object?>[
    <Object?>[<Object?>[]],
    <Object?>[null, null, inner],
  ]);
  return '''
<html><head><title>Zepp - Apps on Google Play</title></head>
<body>$packageId
<script>AF_initDataCallback({key: 'ds:$dsKey', hash: '13', data:$data, sideChannel: {}});</script>
</body></html>
''';
}
