import 'package:flutter/material.dart';

import '../../models/watch_model.dart';

/// Compact watch picker: one-line summary when collapsed; searchable list when
/// expanded. Collapses again after a selection.
class CompactWatchPicker extends StatefulWidget {
  const CompactWatchPicker({
    super.key,
    required this.watches,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.initiallyExpanded = false,
    this.subtitleBuilder,
  });

  final List<WatchModel> watches;
  final WatchModel? selected;
  final ValueChanged<WatchModel> onSelected;
  final bool enabled;
  final bool initiallyExpanded;
  final String? Function(WatchModel watch)? subtitleBuilder;

  @override
  State<CompactWatchPicker> createState() => _CompactWatchPickerState();
}

class _CompactWatchPickerState extends State<CompactWatchPicker> {
  late bool _expanded = widget.initiallyExpanded;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<WatchModel> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.watches;
    return widget.watches
        .where((w) => w.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(8),
          child: ListTile(
            enabled: widget.enabled,
            leading: const Icon(Icons.watch),
            title: Text(selected?.name ?? 'Choose a watch'),
            subtitle: selected == null
                ? const Text('Tap to pick a model')
                : (selected.osVersion.isEmpty
                      ? const Text('Tap to change')
                      : Text('Zepp OS ${selected.osVersion} · tap to change')),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: widget.enabled
                ? () => setState(() => _expanded = !_expanded)
                : null,
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            enabled: widget.enabled,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search watches',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: Material(
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final watch = _filtered[index];
                  final isSelected = selected?.deviceId == watch.deviceId;
                  final extra = widget.subtitleBuilder?.call(watch);
                  return ListTile(
                    selected: isSelected,
                    enabled: widget.enabled,
                    title: Text(watch.name),
                    subtitle: Text(
                      [
                        if (watch.osVersion.isNotEmpty)
                          'Zepp OS ${watch.osVersion}',
                        if (extra != null && extra.isNotEmpty) extra,
                      ].join(' · '),
                    ),
                    onTap: () {
                      widget.onSelected(watch);
                      setState(() {
                        _expanded = false;
                        _search.clear();
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
