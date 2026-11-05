import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zelp/domain/store/market_countries.dart';
import 'package:zelp/screens/widgets/store_catalog/store_region_picker_sheet.dart';

/// Selected store-query regions, plus a picker for any other ISO country.
///
/// At least one region stays selected so Update list always has a query.
class StoreMarketRegionSection extends StatelessWidget {
  const StoreMarketRegionSection({
    required this.selected,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final List<String> selected;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canRemove = enabled && selected.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Regions', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Update list queries only the countries you select. '
          'Add any other ISO country.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            for (final String country in selected)
              InputChip(
                key: Key('store-region-$country'),
                label: Text('${labelForMarketCountry(country)} ($country)'),
                deleteIcon: const Icon(Icons.clear),
                onDeleted: canRemove ? () => _remove(country) : null,
              ),
            ActionChip(
              key: const Key('store-region-add'),
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add region'),
              onPressed: enabled ? () => unawaited(_addRegion(context)) : null,
            ),
          ],
        ),
      ],
    );
  }

  void _remove(String country) {
    final List<String> next = <String>[
      for (final String code in selected)
        if (code != country) code,
    ];
    if (next.isEmpty) return;
    onChanged(next);
  }

  Future<void> _addRegion(BuildContext context) async {
    final String? code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => StoreRegionPickerSheet(excluded: selected),
    );
    if (code == null || selected.contains(code)) return;
    onChanged(<String>[...selected, code]);
  }
}
