import 'dart:convert';

import 'package:zelp/domain/primitives/mac_address.dart';

class Device {
  Device({required String mac, required this.authKey, required this.active}) : macAddress = MacAddress(mac);

  factory Device.fromZepp(Map<String, dynamic> data) {
    final String mac = data['macAddress'] as String? ?? '??:??:??:??:??:??';
    final bool active = (data['activeStatus'] as num?)?.toInt() == 1;
    final String additionalInfoStr = data['additionalInfo'] as String? ?? '{}';
    Map<String, dynamic> additionalInfo = <String, dynamic>{};
    try {
      additionalInfo = (jsonDecode(additionalInfoStr) as Map<String, dynamic>?) ?? <String, dynamic>{};
    } on Object catch (_) {}
    final String authKey = additionalInfo['auth_key'] as String? ?? '??';
    return Device(mac: mac, authKey: authKey, active: active);
  }

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
}
