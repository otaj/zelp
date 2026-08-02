import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:zelp/domain/store/zepp_install_qr.dart';
import 'package:zelp/models/store_item.dart';

/// Shows a Zepp developer-mode install QR for [item] (original package URL).
Future<void> showZeppInstallQrDialog(
  BuildContext context, {
  required StoreItem item,
}) async {
  final String? payload = ZeppInstallQr.payloadFor(item);
  if (payload == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No install link yet. Update the list or download details first.',
        ),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return AlertDialog(
        title: const Text('Install with Zepp'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'In the Zepp app, open Developer mode and scan this code to '
                'install “${item.name}”.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: payload,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                payload,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: payload));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Install link copied')),
              );
            },
            child: const Text('Copy link'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
