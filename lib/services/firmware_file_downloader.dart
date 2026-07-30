import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:zelp/domain/exceptions.dart';
import 'package:zelp/domain/output/asset_kind.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/services/download_storage.dart';
import 'package:zelp/services/file_checksum_hash.dart';

typedef DownloadProgressCallback = void Function(int received, int? total);

/// Downloads a remote firmware (or related) binary into [DownloadStorage].
///
/// HTTP is injectable for unit tests — never call real networks from tests.
class FirmwareFileDownloader {
  FirmwareFileDownloader({http.Client? httpClient, DownloadStorage? storage})
    : _http = httpClient ?? http.Client(),
      _ownsClient = httpClient == null,
      _storage = storage ?? DownloadStorage();

  final http.Client _http;
  final bool _ownsClient;
  final DownloadStorage _storage;

  /// Fetches [url] and saves it under the configured output folder.
  ///
  /// When [expectedChecksum] is provided, downloaded bytes are verified before
  /// saving. Progress is reported via [onProgress] when the server sends
  /// Content-Length (otherwise indeterminate updates may still fire).
  ///
  /// [kind] selects the asset subfolder (defaults to [AssetKind.firmware]).
  Future<SavedExport> downloadToOutputFolder({
    required Uri url,
    String? fileName,
    FileChecksum? expectedChecksum,
    DownloadProgressCallback? onProgress,
    AssetKind kind = AssetKind.firmware,
  }) async {
    final http.Request request = http.Request('GET', url);
    final http.StreamedResponse streamed = await _http.send(request);
    if (streamed.statusCode != 200) {
      throw DeviceException(
        'Firmware download failed (status ${streamed.statusCode})',
        code: 'firmware-download-failed',
      );
    }

    final int? total = streamed.contentLength;
    final BytesBuilder builder = BytesBuilder(copy: false);
    int received = 0;
    await for (final List<int> chunk in streamed.stream) {
      builder.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    final Uint8List bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      throw DeviceException(
        'Firmware download returned an empty file',
        code: 'firmware-download-empty',
      );
    }
    if (expectedChecksum != null && !expectedChecksum.matchesBytes(bytes)) {
      throw DeviceException(
        'Firmware download checksum mismatch',
        code: 'firmware-checksum-mismatch',
      );
    }
    final String name = fileName ?? _fileNameFromUrl(url);
    return _storage.saveFile(
      fileName: name,
      bytes: Uint8List.fromList(bytes),
      kind: kind,
    );
  }

  static String _fileNameFromUrl(Uri url) {
    final String last = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
    if (last.isNotEmpty) return last;
    return 'firmware.bin';
  }

  /// Suggested local file name for a firmware version URL.
  static String suggestedFileName({
    required String firmwareVersion,
    required String? firmwareUrl,
  }) {
    if (firmwareUrl != null && firmwareUrl.isNotEmpty) {
      final String fromUrl = p.basename(Uri.parse(firmwareUrl).path);
      if (fromUrl.isNotEmpty && fromUrl.contains('.')) return fromUrl;
    }
    final String safe = firmwareVersion.replaceAll(RegExp('[^A-Za-z0-9._-]+'), '_');
    return 'firmware_$safe.bin';
  }

  void close() {
    if (_ownsClient) _http.close();
  }
}
