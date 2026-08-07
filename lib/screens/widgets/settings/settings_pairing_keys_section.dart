import 'package:flutter/material.dart';
import 'package:zelp/models/device.dart';
import 'package:zelp/screens/widgets/pairing_device_card.dart';

/// List of pairing-key cards fetched after sign-in.
class SettingsPairingKeysSection extends StatelessWidget {
  const SettingsPairingKeysSection({
    required this.devices,
    required this.onCopyKey,
    required this.onCopyMac,
    required this.onShare,
    super.key,
  });

  final List<Device> devices;
  final void Function(Device device) onCopyKey;
  final void Function(Device device) onCopyMac;
  final void Function(Device device) onShare;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 28),
        Text('Pairing keys', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...devices.map(
          (Device device) => PairingDeviceCard(
            device: device,
            onCopyKey: () => onCopyKey(device),
            onCopyMac: () => onCopyMac(device),
            onShare: () => onShare(device),
          ),
        ),
      ],
    );
  }
}
