import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../domain/output/saved_export.dart';

/// Shares exported files via the platform share sheet.
class FileShareService {
  const FileShareService();

  Future<void> shareExport(SavedExport export, {String? subject}) async {
    final file = File(export.localPath);
    if (!await file.exists()) {
      throw StateError('Share file missing: ${export.localPath}');
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(export.localPath, name: export.fileName)],
        subject: subject ?? export.fileName,
        text: export.fileName,
      ),
    );
  }

  Future<void> shareFilePath(
    String localPath, {
    String? fileName,
    String? subject,
  }) async {
    final name = fileName ?? p.basename(localPath);
    await shareExport(
      SavedExport(fileName: name, displayPath: localPath, localPath: localPath),
      subject: subject,
    );
  }

  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}
