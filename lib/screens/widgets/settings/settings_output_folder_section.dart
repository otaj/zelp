import 'package:flutter/material.dart';
import 'package:zelp/domain/output/output_folder.dart';

/// Download folder picker and related filename preference toggles.
class SettingsOutputFolderSection extends StatelessWidget {
  const SettingsOutputFolderSection({
    required this.outputFolder,
    required this.splitByType,
    required this.semanticNames,
    required this.enabled,
    required this.onPickFolder,
    required this.onResetFolder,
    required this.onClearFolder,
    required this.onSplitByTypeChanged,
    required this.onSemanticNamesChanged,
    super.key,
  });

  final OutputFolder outputFolder;
  final bool splitByType;
  final bool semanticNames;
  final bool enabled;
  final VoidCallback onPickFolder;
  final VoidCallback onResetFolder;
  final VoidCallback onClearFolder;
  final ValueChanged<bool?> onSplitByTypeChanged;
  final ValueChanged<bool?> onSemanticNamesChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Download folder', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_outlined),
          title: Text(outputFolder.label),
          subtitle: Text(
            outputFolder.kind == OutputFolderKind.defaults
                ? 'Default folder for downloads and exports'
                : 'Custom folder for downloads and exports',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Select output folder',
                onPressed: enabled ? onPickFolder : null,
                icon: const Icon(Icons.folder_open),
              ),
              IconButton(
                tooltip: 'Use default folder',
                onPressed: enabled && outputFolder.kind != OutputFolderKind.defaults ? onResetFolder : null,
                icon: const Icon(Icons.home_outlined),
              ),
              IconButton(
                tooltip: 'Clear output folder',
                onPressed: enabled ? onClearFolder : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: splitByType,
          onChanged: enabled ? onSplitByTypeChanged : null,
          title: const Text('Split downloads by type'),
          subtitle: const Text(
            'Save firmware, apps, watchfaces, and GPS into separate subfolders',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: semanticNames,
          onChanged: enabled ? onSemanticNamesChanged : null,
          title: const Text('Use semantic filenames'),
          subtitle: const Text(
            'Rename downloads to name and version (e.g. MyApp_1.2.0.zip)',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}
