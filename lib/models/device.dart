import 'dart:convert';

import '../domain/primitives/mac_address.dart';

class Device {
  Device({required String mac, required this.authKey, required this.active})
    : macAddress = MacAddress(mac);

  Device.fromParts({
    required this.macAddress,
    required this.authKey,
    required this.active,
  });

  final MacAddress macAddress;
  final String authKey;
  final bool active;

  String get mac => macAddress.value;

  String get displayKey => authKey.startsWith('0x') ? authKey : '0x$authKey';

  factory Device.fromZepp(Map<String, dynamic> data) {
    final mac = data['macAddress'] as String? ?? '??:??:??:??:??:??';
    final active = (data['activeStatus'] as num?)?.toInt() == 1;
    final additionalInfoStr = data['additionalInfo'] as String? ?? '{}';
    Map<String, dynamic> additionalInfo = {};
    try {
      additionalInfo =
          (jsonDecode(additionalInfoStr) as Map<String, dynamic>?) ?? {};
    } catch (_) {}
    final authKey = additionalInfo['auth_key'] as String? ?? '??';
    return Device(mac: mac, authKey: authKey, active: active);
  }
}
