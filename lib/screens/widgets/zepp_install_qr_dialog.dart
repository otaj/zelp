import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:zelp/domain/store/zepp_install_qr.dart';
import 'package:zelp/models/store_item.dart';

/// Edge length of the QR glyph inside the dialog (exclusive of padding).
const double _kQrImageSize = 220;

/// Padding around the QR on the white plate.
const double _kQrPlatePadding = 12;

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
      // AlertDialog sizes with IntrinsicWidth. QrImageView uses LayoutBuilder,
      // which cannot report intrinsics in debug (hard crash). A tight SizedBox
      // answers those queries without asking the QR.
      const double plateSize = _kQrImageSize + _kQrPlatePadding * 2;
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
              SizedBox(
                width: plateSize,
                height: plateSize,
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(_kQrPlatePadding),
                    child: QrImageView(
                      data: payload,
                      size: _kQrImageSize,
                      backgroundColor: Colors.white,
                      errorStateBuilder: (BuildContext context, Object? error) => Center(
                        child: Text(
                          'Could not build QR code.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
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
