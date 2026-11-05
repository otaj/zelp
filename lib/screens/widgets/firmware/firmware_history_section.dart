import 'package:flutter/material.dart';
import 'package:zelp/domain/output/existing_download.dart';
import 'package:zelp/domain/output/saved_export.dart';
import 'package:zelp/domain/primitives/firmware_version.dart';
import 'package:zelp/models/watch_model.dart';
import 'package:zelp/screens/widgets/firmware/firmware_version_card.dart';

/// Source picker + check/clear actions for the selected watch.
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
    required this.onClearHistory,
    required this.expertMode,
    required this.currentFirmware,
    required this.onCurrentFirmwareChanged,
    this.currentFirmwareError,
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
  final VoidCallback onClearHistory;

  /// When true, the current firmware version can be typed.
  final bool expertMode;

  /// Firmware version currently on the watch. Sent as the OTA starting point.
  final TextEditingController currentFirmware;
  final ValueChanged<String> onCurrentFirmwareChanged;
  final String? currentFirmwareError;

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
        if (expertMode) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            key: const Key('firmware-current-version'),
            controller: currentFirmware,
            enabled: !checking,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Current firmware version',
              hintText: '3.17.0.3',
              helperText: 'Optional. Amazfit serves a smaller diff when this matches the firmware on your watch.',
              helperMaxLines: 3,
              errorText: currentFirmwareError,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onCurrentFirmwareChanged,
          ),
          _FirmwareCheckFromLine(
            currentFirmware: currentFirmware,
            history: history,
          ),
        ] else if (history?.latest != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Will check for versions newer than ${history!.latestVersion}',
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
            if (history != null && history!.versions.isNotEmpty) ...<Widget>[
              const SizedBox(width: 8),
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

class _FirmwareCheckFromLine extends StatelessWidget {
  const _FirmwareCheckFromLine({
    required this.currentFirmware,
    required this.history,
  });

  final TextEditingController currentFirmware;
  final StoredFirmwareHistory? history;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: currentFirmware,
    builder: (BuildContext context, Widget? _) {
      final ThemeData theme = Theme.of(context);
      final TextStyle? style = theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      final String typed = currentFirmware.text.trim();
      final String? stored = history?.latest?.firmwareVersion;
      final String? from = typed.isNotEmpty ? typed : stored;
      final String message = from == null || from == FirmwareVersion.zero.value
          ? 'No version entered. The check starts from scratch and usually downloads a full package.'
          : 'Will check for versions newer than $from';
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message, style: style),
      );
    },
  );
}

/// Heading + [FirmwareVersionCard] list for stored firmware versions.
class FirmwareStoredVersionsList extends StatelessWidget {
  const FirmwareStoredVersionsList({
    required this.history,
    required this.versionsSubtitle,
    required this.downloadingVersion,
    required this.existingByVersion,
    required this.onCopy,
    required this.onDownloadFirmware,
    required this.onShareExisting,
    this.downloadProgress,
    this.downloadProgressLabel,
    super.key,
  });

  final StoredFirmwareHistory history;
  final String? versionsSubtitle;

  /// Firmware version whose file is downloading, or null when idle.
  final String? downloadingVersion;

  /// Fraction `0..1` for [downloadingVersion]. Null draws an indeterminate bar.
  final double? downloadProgress;

  /// Caption under the bar for [downloadingVersion] (`4.2 MB / 80.0 MB · 5%`).
  final String? downloadProgressLabel;
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
        ...history.versions.reversed.map((FirmwareInfo info) {
          final bool downloading = downloadingVersion == info.firmwareVersion;
          return FirmwareVersionCard(
            info: info,
            isLatest: info.firmwareVersion == history.latestVersion,
            downloading: downloading,
            downloadEnabled: downloadingVersion == null,
            downloadProgress: downloading ? downloadProgress : null,
            downloadProgressLabel: downloading ? downloadProgressLabel : null,
            existing: existingByVersion[info.firmwareVersion],
            onCopy: onCopy,
            onDownloadFirmware: info.hasFirmware ? () => onDownloadFirmware(info) : null,
            onShareExisting: onShareExisting,
          );
        }),
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
