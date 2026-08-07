import 'package:flutter/material.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/widgets/firmware/firmware_version_card.dart';

/// Source picker + check/history/clear actions for the selected watch.
class FirmwareWatchActions extends StatelessWidget {
  const FirmwareWatchActions({
    required this.deviceId,
    required this.watchName,
    required this.variants,
    required this.selectedVariant,
    required this.showSourcePicker,
    required this.checking,
    required this.history,
    required this.onSelectVariant,
    required this.onCheckFirmware,
    required this.onFetchFullHistory,
    required this.onClearHistory,
    super.key,
  });

  final String deviceId;
  final String watchName;
  final List<WatchVariant> variants;
  final WatchVariant selectedVariant;
  final bool showSourcePicker;
  final bool checking;
  final StoredFirmwareHistory? history;
  final ValueChanged<WatchVariant> onSelectVariant;
  final VoidCallback onCheckFirmware;
  final VoidCallback onFetchFullHistory;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 20),
        Text(watchName, style: theme.textTheme.titleSmall),
        if (showSourcePicker) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Recently used device sources appear first. '
            'Pick the source that matches your hardware.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          DropdownMenu<WatchVariant>(
            key: ValueKey<String>(
              '$deviceId:${selectedVariant.deviceSource}',
            ),
            enabled: !checking,
            initialSelection: selectedVariant,
            label: const Text('Device source'),
            expandedInsets: EdgeInsets.zero,
            onSelected: (WatchVariant? value) {
              if (value != null) onSelectVariant(value);
            },
            dropdownMenuEntries: variants
                .map(
                  (WatchVariant v) => DropdownMenuEntry<WatchVariant>(value: v, label: v.label),
                )
                .toList(),
          ),
        ],
        if (history?.latest != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Will check for versions newer than '
            '${history!.latestVersion}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: checking ? null : onCheckFirmware,
                icon: checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.system_update_alt),
                label: Text(
                  checking ? 'Checking…' : 'Check for updates',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Fetch full release history',
              onPressed: checking ? null : onFetchFullHistory,
              icon: const Icon(Icons.history),
            ),
            if (history != null && history!.versions.isNotEmpty) ...<Widget>[
              IconButton(
                tooltip: showSourcePicker
                    ? 'Clear stored versions for this device source'
                    : 'Clear stored versions for this watch',
                onPressed: checking ? null : onClearHistory,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Heading + [FirmwareVersionCard] list for stored firmware versions.
class FirmwareStoredVersionsList extends StatelessWidget {
  const FirmwareStoredVersionsList({
    required this.history,
    required this.versionsSubtitle,
    required this.downloadingFirmware,
    required this.existingByVersion,
    required this.onCopy,
    required this.onDownloadFirmware,
    required this.onShareExisting,
    super.key,
  });

  final StoredFirmwareHistory history;
  final String? versionsSubtitle;
  final bool downloadingFirmware;
  final Map<String, ExistingDownloadMatch> existingByVersion;
  final Future<void> Function(String value, String label) onCopy;
  final void Function(FirmwareInfo info) onDownloadFirmware;
  final Future<void> Function(ExistingDownloadMatch match) onShareExisting;

  @override
  Widget build(BuildContext context) {
    if (history.versions.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 20),
        Text(
          'Stored versions'
          '${versionsSubtitle == null ? '' : ' · $versionsSubtitle'}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...history.versions.reversed.map(
          (FirmwareInfo info) => FirmwareVersionCard(
            info: info,
            isLatest: info.firmwareVersion == history.latestVersion,
            downloading: downloadingFirmware,
            existing: existingByVersion[info.firmwareVersion],
            onCopy: onCopy,
            onDownloadFirmware: info.hasFirmware ? () => onDownloadFirmware(info) : null,
            onShareExisting: onShareExisting,
          ),
        ),
      ],
    );
  }
}

/// Session downloads list for firmware files.
class FirmwareDownloadedList extends StatelessWidget {
  const FirmwareDownloadedList({
    required this.exports,
    required this.outputFolderLabel,
    required this.onShare,
    super.key,
  });

  final List<SavedExport> exports;
  final String? outputFolderLabel;
  final void Function(SavedExport export) onShare;

  @override
  Widget build(BuildContext context) {
    if (exports.isEmpty) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 20),
        Text(
          'Downloaded firmware files',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Saved to ${outputFolderLabel ?? 'output folder'}. '
          'Share opens the system share sheet.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...exports.map(
          (SavedExport export) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.system_update_alt),
            title: Text(export.fileName),
            subtitle: Text(export.displayPath, maxLines: 2),
            trailing: IconButton(
              tooltip: 'Share',
              onPressed: () => onShare(export),
              icon: const Icon(Icons.share_outlined),
            ),
          ),
        ),
      ],
    );
  }
}
