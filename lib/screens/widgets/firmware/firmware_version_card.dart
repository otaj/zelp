import 'package:flutter/material.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/models/watch_model.dart';

/// Card for one firmware history entry (notes, URLs, download/share).
class FirmwareVersionCard extends StatelessWidget {
  const FirmwareVersionCard({
    required this.info,
    required this.isLatest,
    required this.onCopy,
    required this.downloading,
    this.existing,
    this.onDownloadFirmware,
    this.onShareExisting,
    super.key,
  });

  final FirmwareInfo info;
  final bool isLatest;
  final bool downloading;
  final ExistingDownloadMatch? existing;
  final Future<void> Function(String value, String label) onCopy;
  final VoidCallback? onDownloadFirmware;
  final Future<void> Function(ExistingDownloadMatch match)? onShareExisting;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? readme = info.readmeOrChangelog;
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
                  child: Text(
                    info.firmwareVersion,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (isLatest)
                  Chip(
                    label: const Text('Latest'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
              ],
            ),
            if (readme != null) ...<Widget>[
              const SizedBox(height: 4),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  // Distinct from RestorableScrollBody's ListView PageStorageKey so
                  // expansion state is not confused with the scroll offset (double).
                  key: PageStorageKey<String>('firmware_notes_${info.firmwareVersion}'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    'Release notes',
                    style: theme.textTheme.labelLarge,
                  ),
                  children: <Widget>[
                    Align(alignment: Alignment.centerLeft, child: Text(readme)),
                  ],
                ),
              ),
            ],
            if (existing != null) ...<Widget>[
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Already downloaded'),
                subtitle: Text(
                  '${existing!.file.fileName}'
                  '${existing!.matchedByChecksum ? ' · verified' : ''}',
                  maxLines: 2,
                ),
                trailing: onShareExisting == null
                    ? null
                    : IconButton(
                        tooltip: 'Share existing file',
                        onPressed: () => onShareExisting!(existing!),
                        icon: const Icon(Icons.share_outlined),
                      ),
              ),
            ],
            if (info.firmwareUrl != null && info.firmwareUrl!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Firmware file'),
                subtitle: Text(info.firmwareUrl!, maxLines: 2),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Copy URL',
                      onPressed: () => onCopy(info.firmwareUrl!, 'Firmware URL'),
                      icon: const Icon(Icons.copy),
                    ),
                    IconButton(
                      tooltip: existing == null ? 'Download to output folder' : 'Redownload (replace existing)',
                      onPressed: downloading ? null : onDownloadFirmware,
                      icon: downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              existing == null ? Icons.download_outlined : Icons.refresh,
                            ),
                    ),
                  ],
                ),
              ),
            if (info.gpsVersion != null && info.gpsUrl != null && info.gpsUrl!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('GPS ${info.gpsVersion}'),
                subtitle: Text(info.gpsUrl!, maxLines: 2),
                trailing: IconButton(
                  onPressed: () => onCopy(info.gpsUrl!, 'GPS URL'),
                  icon: const Icon(Icons.copy),
                ),
              ),
            if (info.resourceVersion != null && info.resourceUrl != null && info.resourceUrl!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Resources ${info.resourceVersion}'),
                subtitle: Text(info.resourceUrl!, maxLines: 2),
                trailing: IconButton(
                  onPressed: () => onCopy(info.resourceUrl!, 'Resource URL'),
                  icon: const Icon(Icons.copy),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
