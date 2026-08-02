import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/services/file_share_service.dart';

/// Copies [text] and shows a short snackbar (`"$label copied"`).
Future<void> copyTextWithSnackbar(
  BuildContext context, {
  required String text,
  required String label,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
}

/// Shares [export] via [share], surfacing failures as a snackbar.
Future<void> shareExportWithSnackbar(
  BuildContext context, {
  required FileShareService share,
  required SavedExport export,
}) async {
  try {
    await share.shareExport(export);
  } on Exception catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
  }
}

/// Shares an on-disk [match], or explains why sharing is unavailable.
Future<void> shareExistingWithSnackbar(
  BuildContext context, {
  required FileShareService share,
  required ExistingDownloadMatch match,
  String missingMessage = 'Couldn’t find the file to share',
}) async {
  final String? local = match.file.localPath;
  if (local == null || local.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(missingMessage)));
    return;
  }
  await shareExportWithSnackbar(
    context,
    share: share,
    export: SavedExport(
      fileName: match.file.fileName,
      displayPath: match.file.displayPath,
      localPath: local,
    ),
  );
}
