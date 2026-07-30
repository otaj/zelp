import 'package:flutter/material.dart';

import 'package:zelp/models/device.dart';

class PairingDeviceCard extends StatelessWidget {
  const PairingDeviceCard({
    required this.device,
    required this.onCopyKey,
    required this.onCopyMac,
    required this.onShare,
    super.key,
  });

  final Device device;
  final VoidCallback onCopyKey;
  final VoidCallback onCopyMac;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(device.mac, style: theme.textTheme.titleSmall),
                ),
                Chip(
                  label: Text(device.active ? 'Active' : 'Inactive'),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Share key',
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Copy MAC',
                  onPressed: onCopyMac,
                  icon: const Icon(Icons.copy_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SelectableText(
              device.displayKey,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCopyKey,
                icon: const Icon(Icons.key, size: 18),
                label: const Text('Copy key'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
