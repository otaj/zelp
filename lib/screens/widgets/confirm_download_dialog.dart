import 'package:flutter/material.dart';

/// Cancel / Download|Replace confirmation used by store and firmware downloads.
Future<bool> showConfirmDownloadDialog(
  BuildContext context, {
  required String title,
  required String content,
  required bool isRedownload,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(isRedownload ? 'Replace' : 'Download'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
