import 'package:flutter/material.dart';
import 'package:zelp/domain/store/store_catalog_query.dart';

/// Bottom-sheet body for store catalog filter & sort controls.
///
/// Pops with the draft [StoreCatalogQuery] when Apply is pressed.
class StoreCatalogFilterSheet extends StatefulWidget {
  const StoreCatalogFilterSheet({
    required this.initial,
    required this.categories,
    required this.publishers,
    super.key,
  });

  final StoreCatalogQuery initial;
  final List<String> categories;
  final List<String> publishers;

  @override
  State<StoreCatalogFilterSheet> createState() => _StoreCatalogFilterSheetState();
}

class _StoreCatalogFilterSheetState extends State<StoreCatalogFilterSheet> {
  late StoreCatalogQuery _draft = widget.initial;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      top: 8,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Filter & sort',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        DropdownMenu<StoreSortBy>(
          initialSelection: _draft.sortBy,
          label: const Text('Sort by'),
          expandedInsets: EdgeInsets.zero,
          onSelected: (StoreSortBy? v) {
            if (v == null) return;
            setState(() => _draft = _draft.copyWith(sortBy: v));
          },
          dropdownMenuEntries: StoreSortBy.values
              .map((StoreSortBy e) => DropdownMenuEntry<StoreSortBy>(value: e, label: e.label))
              .toList(),
        ),
        const SizedBox(height: 8),
        SegmentedButton<StoreSortDirection>(
          segments: const <ButtonSegment<StoreSortDirection>>[
            ButtonSegment<StoreSortDirection>(
              value: StoreSortDirection.ascending,
              label: Text('A → Z / Low'),
            ),
            ButtonSegment<StoreSortDirection>(
              value: StoreSortDirection.descending,
              label: Text('Z → A / High'),
            ),
          ],
          selected: <StoreSortDirection>{_draft.sortDirection},
          onSelectionChanged: (Set<StoreSortDirection> s) {
            setState(
              () => _draft = _draft.copyWith(sortDirection: s.first),
            );
          },
        ),
        const SizedBox(height: 12),
        DropdownMenu<String?>(
          initialSelection: _draft.categoryName,
          label: const Text('Category'),
          expandedInsets: EdgeInsets.zero,
          onSelected: (String? v) {
            setState(() {
              _draft = v == null || v.isEmpty ? _draft.copyWith(clearCategory: true) : _draft.copyWith(categoryName: v);
            });
          },
          dropdownMenuEntries: <DropdownMenuEntry<String?>>[
            const DropdownMenuEntry<String?>(value: null, label: 'Any'),
            ...widget.categories.map(
              (String c) => DropdownMenuEntry<String?>(value: c, label: c),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownMenu<String?>(
          initialSelection: _draft.publisherName,
          label: const Text('Author'),
          expandedInsets: EdgeInsets.zero,
          onSelected: (String? v) {
            setState(() {
              _draft = v == null || v.isEmpty
                  ? _draft.copyWith(clearPublisher: true)
                  : _draft.copyWith(publisherName: v);
            });
          },
          dropdownMenuEntries: <DropdownMenuEntry<String?>>[
            const DropdownMenuEntry<String?>(value: null, label: 'Any'),
            ...widget.publishers.map(
              (String p) => DropdownMenuEntry<String?>(value: p, label: p),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Price', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<StorePriceFilter>(
          segments: StorePriceFilter.values
              .map(
                (StorePriceFilter e) => ButtonSegment<StorePriceFilter>(value: e, label: Text(e.label)),
              )
              .toList(),
          selected: <StorePriceFilter>{_draft.price},
          onSelectionChanged: (Set<StorePriceFilter> s) {
            setState(() => _draft = _draft.copyWith(price: s.first));
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Starred only'),
          value: _draft.starredOnly,
          onChanged: (bool v) {
            setState(() => _draft = _draft.copyWith(starredOnly: v));
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: () {
                setState(() {
                  _draft = StoreCatalogQuery(
                    text: _draft.text,
                  );
                });
              },
              child: const Text('Clear filters'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.pop(context, _draft),
              child: const Text('Apply'),
            ),
          ],
        ),
      ],
    ),
  );
}
