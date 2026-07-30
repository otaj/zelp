import 'package:flutter/material.dart';

import 'package:zelp/models/watch_model.dart';

/// Compact watch picker: one-line summary when collapsed; searchable list when
/// expanded. Collapses again after a selection.
class CompactWatchPicker extends StatefulWidget {
  const CompactWatchPicker({
    required this.watches,
    required this.selected,
    required this.onSelected,
    super.key,
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
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<WatchModel> get _filtered {
    final String query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.watches;
    return widget.watches.where((WatchModel w) => w.name.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final WatchModel? selected = widget.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
            onTap: widget.enabled ? () => setState(() => _expanded = !_expanded) : null,
          ),
        ),
        if (_expanded) ...<Widget>[
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
                itemBuilder: (BuildContext context, int index) {
                  final WatchModel watch = _filtered[index];
                  final bool isSelected = selected?.deviceId == watch.deviceId;
                  final String? extra = widget.subtitleBuilder?.call(watch);
                  return ListTile(
                    selected: isSelected,
                    enabled: widget.enabled,
                    title: Text(watch.name),
                    subtitle: Text(
                      <String>[
                        if (watch.osVersion.isNotEmpty) 'Zepp OS ${watch.osVersion}',
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
