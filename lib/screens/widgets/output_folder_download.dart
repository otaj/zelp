import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/output_folder.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/screens/widgets/confirm_download_dialog.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/file_download_notifier.dart';
import 'package:zelp/services/firmware_file_downloader.dart';

/// Outcome of [confirmAndDownloadToOutputFolder].
enum OutputFolderDownloadStatus { cancelled, success, failed }

/// Result returned after confirm → download → snackbar orchestration.
class OutputFolderDownloadResult {
  const OutputFolderDownloadResult._({
    required this.status,
    required this.fileName,
    this.export,
    this.match,
    this.folder,
    this.errorMessage,
  });

  factory OutputFolderDownloadResult.cancelled({required String fileName}) => OutputFolderDownloadResult._(
    status: OutputFolderDownloadStatus.cancelled,
    fileName: fileName,
  );

  factory OutputFolderDownloadResult.success({
    required String fileName,
    required SavedExport export,
    required ExistingDownloadMatch match,
    required OutputFolder folder,
  }) => OutputFolderDownloadResult._(
    status: OutputFolderDownloadStatus.success,
    fileName: fileName,
    export: export,
    match: match,
    folder: folder,
  );

  factory OutputFolderDownloadResult.failed({
    required String fileName,
    required String errorMessage,
  }) => OutputFolderDownloadResult._(
    status: OutputFolderDownloadStatus.failed,
    fileName: fileName,
    errorMessage: errorMessage,
  );

  final OutputFolderDownloadStatus status;
  final String fileName;
  final SavedExport? export;
  final ExistingDownloadMatch? match;
  final OutputFolder? folder;
  final String? errorMessage;
}

/// Shared confirm → download-to-output-folder → share-snackbar pipeline.
///
/// Callers own domain-specific pre-steps (resolve URL, usage MRU) and apply
/// [OutputFolderDownloadResult] into screen state afterward.
Future<OutputFolderDownloadResult> confirmAndDownloadToOutputFolder({
  required BuildContext context,
  required DownloadStorage downloads,
  required FirmwareFileDownloader downloader,
  required FileDownloadNotifier notifier,
  required String url,
  required String fileName,
  required String version,
  required String Function({
    required bool isRedownload,
    required OutputFolder folder,
    required ExistingDownloadMatch? existing,
  })
  dialogTitle,
  required String Function({
    required bool isRedownload,
    required OutputFolder folder,
    required ExistingDownloadMatch? existing,
  })
  dialogContent,
  required String Function(String fileName) snackbarMessage,
  required Future<void> Function(SavedExport export) onShare,
  required bool matchedByChecksumOnSave,
  required AssetKind kind,
  FileChecksum? expectedChecksum,
  bool snackbarPersist = false,
  Future<void> Function(OutputFolder folder, String fileName)? onDownloadStarted,
}) async {
  final OutputFolder folder = await downloads.loadSettings(force: true);
  if (!context.mounted) {
    return OutputFolderDownloadResult.cancelled(fileName: fileName);
  }

  final ExistingDownloadMatch? existing = await downloads.findExistingDownload(
    expectedFileName: fileName,
    checksum: expectedChecksum,
    kind: kind,
  );
  if (!context.mounted) {
    return OutputFolderDownloadResult.cancelled(fileName: fileName);
  }

  final bool isRedownload = existing != null;
  final bool confirmed = await showConfirmDownloadDialog(
    context,
    title: dialogTitle(
      isRedownload: isRedownload,
      folder: folder,
      existing: existing,
    ),
    content: dialogContent(
      isRedownload: isRedownload,
      folder: folder,
      existing: existing,
    ),
    isRedownload: isRedownload,
  );
  if (!confirmed || !context.mounted) {
    return OutputFolderDownloadResult.cancelled(fileName: fileName);
  }

  await onDownloadStarted?.call(folder, fileName);

  try {
    await notifier.begin(fileName: fileName, version: version);
    final SavedExport export = await downloader.downloadToOutputFolder(
      url: Uri.parse(url),
      fileName: fileName,
      kind: kind,
      expectedChecksum: expectedChecksum,
      onProgress: (int received, int? total) {
        unawaited(
          notifier.reportProgress(
            fileName: fileName,
            version: version,
            received: received,
            total: total,
          ),
        );
      },
    );
    await notifier.complete(fileName: fileName, version: version);
    if (!context.mounted) {
      return OutputFolderDownloadResult.cancelled(fileName: fileName);
    }

    final ExistingDownloadMatch match = ExistingDownloadMatch(
      file: StoredOutputFile(
        fileName: export.fileName,
        displayPath: export.displayPath,
        localPath: export.localPath,
      ),
      matchedByChecksum: matchedByChecksumOnSave,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackbarMessage(fileName)),
        persist: snackbarPersist,
        action: SnackBarAction(
          label: 'Share',
          onPressed: () => unawaited(onShare(export)),
        ),
      ),
    );

    return OutputFolderDownloadResult.success(
      fileName: fileName,
      export: export,
      match: match,
      folder: folder,
    );
  } on ZelpException catch (e) {
    await notifier.fail(fileName: fileName, version: version);
    return OutputFolderDownloadResult.failed(
      fileName: fileName,
      errorMessage: e.message,
    );
  } on Exception catch (e) {
    await notifier.fail(fileName: fileName, version: version);
    return OutputFolderDownloadResult.failed(
      fileName: fileName,
      errorMessage: e.toString(),
    );
  }
}
