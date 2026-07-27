import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// AES-CBC key/IV used by Zepp credential exchange (from huami-token).
const _zeppKey = 'xeNtBVqzDc6tuNTh';
const _zeppIv = 'MAAAYAAAAAAAAABg';

Uint8List zeppEncryptPayload(Uint8List data) {
  final key = Key.fromUtf8(_zeppKey);
  final iv = IV.fromUtf8(_zeppIv);
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  return Uint8List.fromList(encrypter.encryptBytes(data, iv: iv).bytes);
}

Uint8List zeppEncryptForm(Map<String, dynamic> payload) {
  final encoded = _urlEncode(payload);
  return zeppEncryptPayload(Uint8List.fromList(utf8.encode(encoded)));
}

String _urlEncode(Map<String, dynamic> payload) {
  final parts = <String>[];
  for (final entry in payload.entries) {
    final key = Uri.encodeQueryComponent(entry.key);
    final value = entry.value;
    if (value is List) {
      for (final item in value) {
        parts.add('$key=${Uri.encodeQueryComponent(item.toString())}');
      }
    } else if (value != null) {
      parts.add('$key=${Uri.encodeQueryComponent(value.toString())}');
    }
  }
  return parts.join('&');
}
