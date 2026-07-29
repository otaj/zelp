import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// AES-CBC key/IV used by Zepp credential exchange (from huami-token).
const String _zeppKey = 'xeNtBVqzDc6tuNTh';
const String _zeppIv = 'MAAAYAAAAAAAAABg';

Uint8List zeppEncryptPayload(Uint8List data) {
  final Key key = Key.fromUtf8(_zeppKey);
  final IV iv = IV.fromUtf8(_zeppIv);
  final Encrypter encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  return Uint8List.fromList(encrypter.encryptBytes(data, iv: iv).bytes);
}

Uint8List zeppEncryptForm(Map<String, dynamic> payload) {
  final String encoded = _urlEncode(payload);
  return zeppEncryptPayload(Uint8List.fromList(utf8.encode(encoded)));
}

String _urlEncode(Map<String, dynamic> payload) {
  final List<String> parts = <String>[];
  for (final MapEntry<String, dynamic> entry in payload.entries) {
    final String key = Uri.encodeQueryComponent(entry.key);
    final dynamic value = entry.value;
    if (value is List) {
      for (final dynamic item in value) {
        parts.add('$key=${Uri.encodeQueryComponent(item.toString())}');
      }
    } else if (value != null) {
      parts.add('$key=${Uri.encodeQueryComponent(value.toString())}');
    }
  }
  return parts.join('&');
}
