import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../crypto/zepp_crypto.dart';
import '../domain/gps/gps_download_plan.dart';
import '../domain/gps/gps_payload_finder.dart';
import '../domain/output/saved_export.dart';
import '../models/device.dart';
import '../models/gps_file_type.dart';
import 'download_storage.dart';
import 'exceptions.dart';
import 'gps_uihh.dart';

const _zeppChannel = 'a100900101016';

const _tokensUrl = 'https://api-user-us2.zepp.com/v2/registrations/tokens';
const _loginUrl = 'https://api-mifit-us2.zepp.com/v2/client/login';
const _logoutUrl = 'https://api-mifit-us2.zepp.com/v1/client/logout';
const _devicesUrlTemplate =
    'https://api-mifit.zepp.com/users/{user_id}/devices';
const _gpsUrlTemplate =
    'https://api-mifit-us2.zepp.com/apps/com.xiaomi.hm.health/fileTypes/{file_type}/files';

class ZeppSession {
  ZeppSession({required this.username, required this.password});

  /// Already-authenticated session for tests / offline orchestration.
  ZeppSession.authenticated({
    required this.username,
    required this.password,
    required String appToken,
    required String userId,
    required String loginToken,
  }) : _appToken = appToken,
       _userId = userId,
       _loginToken = loginToken;

  final String username;
  final String password;

  String? _accessToken;
  String? _loginToken;
  String? _appToken;
  String? _userId;

  String get appToken {
    final token = _appToken;
    if (token == null) {
      throw AuthenticationException('Not logged in — no app_token available');
    }
    return token;
  }

  String get userId {
    final id = _userId;
    if (id == null) {
      throw AuthenticationException('Not logged in — no user_id available');
    }
    return id;
  }

  String get loginToken {
    final token = _loginToken;
    if (token == null) {
      throw AuthenticationException('Not logged in — no login_token available');
    }
    return token;
  }

  Future<void> login() async {
    await _getRefreshAndAccessTokens();
    await _login();
  }

  Future<void> _getRefreshAndAccessTokens() async {
    final payload = <String, dynamic>{
      'emailOrPhone': username,
      'state': 'REDIRECTION',
      'client_id': 'HuaMi',
      'password': password,
      'redirect_uri':
          'https://s3-us-west-2.amazonaws.com/hm-registration/successsignin.html',
      'region': 'us-west-2',
      'token': ['access', 'refresh'],
      'country_code': 'US',
    };

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(_tokensUrl))
        ..followRedirects = false
        ..headers.addAll({
          'app_name': 'com.huami.midong',
          'appname': 'com.huami.midong',
          'cv': '151689_9.12.5',
          'v': '2.0',
          'appplatform': 'android_phone',
          'vb': '202509151347',
          'vn': '9.12.5',
          'user-agent': 'Zepp/9.12.5 (Pixel 4; Android 12; Density/2.75)',
          'x-hm-ekv': '1',
          'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'accept-encoding': 'gzip',
        })
        ..bodyBytes = zeppEncryptForm(payload);

      final streamed = await client.send(request);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 303) {
        throw AuthenticationException(
          'Login failed (status ${response.statusCode}). '
          'Check your Amazfit/Zepp email and password.',
          code: 'no-redirect',
        );
      }

      final location = response.headers['location'];
      if (location == null || location.isEmpty) {
        throw AuthenticationException(
          'No redirect location found in the response headers',
          code: 'no-location',
        );
      }

      final query = Uri.parse(location).queryParameters;
      _accessToken = query['access'];
      if (_accessToken == null || _accessToken!.isEmpty) {
        throw AuthenticationException(
          'No access token found in the redirect URL',
          code: 'no-tokens',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<void> _login() async {
    final response = await http.post(
      Uri.parse(_loginUrl),
      headers: {
        'app_name': 'com.huami.webapp',
        'appname': 'com.huami.webapp',
        'origin': 'https://user.zepp.com',
        'referer': 'https://user.zepp.com/',
        'user-agent':
            'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
        'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'en-US,en;q=0.5',
      },
      body: {
        'code': _accessToken!,
        'device_id': _uuidV4(),
        'device_model': 'android_phone',
        'app_version': '9.12.5',
        'dn':
            'api-mifit.zepp.com,api-user.zepp.com,api-mifit.zepp.com,api-watch.zepp.com,app-analytics.zepp.com,auth.zepp.com,api-analytics.zepp.com',
        'third_name': 'huami',
        'source': 'com.huami.watch.hmwatchmanager:9.12.5:151689',
        'app_name': 'com.huami.midong',
        'country_code': 'US',
        'grant_type': 'access_token',
        'allow_registration': 'false',
        'lang': 'en',
        'countryState': 'US-NY',
      },
    );

    if (response.statusCode != 200) {
      throw AuthenticationException(
        'Login request failed with status code ${response.statusCode}',
        code: 'login-failed',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tokenInfo = data['token_info'] as Map<String, dynamic>? ?? {};
    _loginToken = tokenInfo['login_token'] as String?;
    _appToken = tokenInfo['app_token'] as String?;
    _userId = tokenInfo['user_id']?.toString();

    if (_loginToken == null || _appToken == null) {
      throw AuthenticationException(
        'No login_token or app_token found in the login response',
        code: 'no-login-tokens',
      );
    }
    if (_userId == null || _userId!.isEmpty) {
      throw AuthenticationException(
        'No user_id found in the login response',
        code: 'no-user-id',
      );
    }
  }

  Future<void> logout() async {
    final response = await http.post(
      Uri.parse(_logoutUrl),
      headers: {
        'app_name': 'com.huami.midong',
        'hm-privacy-ceip': 'false',
        'accept-language': 'en-US',
        'appname': 'com.huami.midong',
        'cv': '151689_9.12.5',
        'v': '2.0',
        'appplatform': 'android_phone',
        'vb': '202509151347',
        'vn': '9.12.5',
        'user-agent': 'Zepp/9.12.5 (Pixel 4; Android 12; Density/2.75)',
        'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
      },
      body: {'login_token': loginToken, 'os_verison': 'vnull'},
    );

    if (response.statusCode != 200) {
      throw AuthenticationException(
        'Logout request failed with status code ${response.statusCode}',
        code: 'logout-failed',
      );
    }
  }
}

class ZeppClient {
  ZeppClient(this.session, {http.Client? httpClient})
    : _http = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  final ZeppSession session;
  final http.Client _http;
  final bool _ownsClient;

  Map<String, String> get _apiHeaders => {
    'hm-privacy-diagnostics': 'false',
    'country': 'US',
    'appplatform': 'android_phone',
    'hm-privacy-ceip': 'true',
    'x-request-id': _uuidV4(),
    'timezone': 'Europe/London',
    'channel': _zeppChannel,
    'vb': '202509151347',
    'cv': '151689_9.12.5',
    'appname': 'com.huami.midong',
    'v': '2.0',
    'vn': '9.12.5',
    'apptoken': session.appToken,
    'lang': 'en_US',
    'user-agent': 'Zepp/9.12.5 (Pixel 4; Android 12; Density/2.75)',
    'accept-encoding': 'gzip',
  };

  Future<List<Device>> getDevices() async {
    final r = _uuidV4();
    final appId =
        '${Random.secure().nextInt(1 << 32)}${Random.secure().nextInt(1 << 32)}';

    final uri =
        Uri.parse(
          _devicesUrlTemplate.replaceAll('{user_id}', session.userId),
        ).replace(
          queryParameters: <String, dynamic>{
            'r': [r, r],
            'enableMultiDeviceOnMultiType': ['true', 'true'],
            'userid': session.userId,
            'appid': appId,
            'channel': _zeppChannel,
            'country': 'US',
            'cv': '151689_9.12.5',
            'device': 'android_32',
            'device_type': 'android_phone',
            'enableMultiDevice': 'true',
            'lang': 'en_US',
            'timezone': 'Europe/London',
            'v': '2.0',
          },
        );

    final response = await _http.get(uri, headers: _apiHeaders);

    if (response.statusCode != 200) {
      throw DeviceException(
        'Get devices request failed with status code ${response.statusCode}',
        code: 'get-devices-failed',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Device.fromZepp)
        .toList();
  }

  void close() {
    if (_ownsClient) _http.close();
  }

  /// Downloads selected GPS assistance files into the configured output folder.
  ///
  /// [types] are Zepp API file types (AGPS_ALM, AGPSZIP, LLE, AGPS, EPO, LTO).
  /// When [buildUihh] is true, AGPSZIP and LLE are fetched in memory if needed
  /// to build `gps_uihh.bin` (those zips are only saved if also listed in
  /// [types]).
  Future<GpsDownloadResult> downloadGpsFiles({
    required Set<GpsFileType> types,
    bool buildUihh = false,
    DownloadStorage? storage,
  }) async {
    final GpsDownloadPlan plan;
    try {
      plan = GpsDownloadPlan(selected: types, buildUihh: buildUihh);
    } on ArgumentError catch (e) {
      throw DeviceException(
        e.message?.toString() ?? 'Select at least one GPS file type',
        code: 'no-gps-selection',
      );
    }

    final downloadStorage = storage ?? DownloadStorage();
    final fetchTypes = plan.fetchTypes;

    final headers = _apiHeaders;
    final r = _uuidV4();
    final appId =
        '${Random.secure().nextInt(1 << 32)}${Random.secure().nextInt(1 << 32)}';
    final query = <String, dynamic>{
      'r': [r, r],
      'userid': session.userId,
      'appid': appId,
      'channel': _zeppChannel,
      'country': 'US',
      'cv': '151689_9.12.5',
      'device': 'android_32',
      'device_type': 'android_phone',
      'lang': 'en_US',
      'timezone': 'Europe/Berlin',
      'v': '2.0',
    };

    final byType = <GpsFileType, List<({String fileName, Uint8List bytes})>>{};
    final saved = <SavedExport>[];
    final warnings = <String>[];

    for (final type in GpsFileType.apiOrder) {
      if (!fetchTypes.contains(type)) continue;

      try {
        final uri = Uri.parse(
          _gpsUrlTemplate.replaceAll('{file_type}', type.apiName),
        ).replace(queryParameters: query);

        final response = await _http.get(uri, headers: headers);
        if (response.statusCode != 200) {
          warnings.add(
            '${type.label}: listing failed (${response.statusCode})',
          );
          continue;
        }

        final listing = jsonDecode(response.body);
        if (listing is! List || listing.isEmpty) {
          warnings.add('${type.label}: no files available');
          continue;
        }

        final files = <({String fileName, Uint8List bytes})>[];
        for (final entry in listing) {
          if (entry is! Map<String, dynamic>) continue;
          final fileUrl = entry['fileUrl'] as String?;
          if (fileUrl == null || fileUrl.isEmpty) continue;

          final fileName = Uri.parse(fileUrl).pathSegments.last;
          final fileResponse = await _http.get(
            Uri.parse(fileUrl),
            headers: headers,
          );
          if (fileResponse.statusCode != 200) {
            warnings.add(
              '$fileName: download failed (${fileResponse.statusCode})',
            );
            continue;
          }
          final bytes = fileResponse.bodyBytes;
          files.add((fileName: fileName, bytes: bytes));

          if (plan.shouldExport(type)) {
            saved.add(
              await downloadStorage.saveFile(fileName: fileName, bytes: bytes),
            );
          }
        }

        if (files.isEmpty) {
          warnings.add('${type.label}: no file URLs in response');
        } else {
          byType[type] = files;
        }
      } catch (e) {
        warnings.add('${type.label}: $e');
      }
    }

    if (plan.exportsUihh) {
      try {
        final cepBytes = findNamedGpsPayload(
          byType[GpsFileType.agpsZip],
          'cep_7days',
        );
        final lleBytes = findNamedGpsPayload(
          byType[GpsFileType.lle],
          'lle_1week',
        );
        if (cepBytes == null || lleBytes == null) {
          warnings.add(
            'UIHH: need *cep_7days.zip (AGPSZIP) and *lle_1week.zip (LLE)',
          );
        } else {
          final uihh = buildGpsUihh(
            cep7daysZipBytes: cepBytes,
            lle1weekZipBytes: lleBytes,
          );
          saved.add(
            await downloadStorage.saveFile(
              fileName: 'gps_uihh.bin',
              bytes: uihh,
            ),
          );
        }
      } catch (e) {
        warnings.add('UIHH: $e');
      }
    }

    if (saved.isEmpty) {
      throw DeviceException(
        warnings.isEmpty ? 'No GPS files were downloaded' : warnings.join('\n'),
        code: 'gps-download-failed',
      );
    }

    return GpsDownloadResult(exports: saved, warnings: warnings);
  }
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
