import 'package:flutter/material.dart';
import 'package:sealed_countries/sealed_countries.dart';
import 'package:zelp/domain/store/market_countries.dart';

/// Searchable list of ISO 3166 countries that can be added to a store query.
///
/// Pops with the chosen alpha-2 code.
class StoreRegionPickerSheet extends StatefulWidget {
  const StoreRegionPickerSheet({
    required this.excluded,
    super.key,
  });

  /// Alpha-2 codes already selected, omitted from the list.
  final List<String> excluded;

  @override
  State<StoreRegionPickerSheet> createState() => _StoreRegionPickerSheetState();
}

class _StoreRegionPickerSheetState extends State<StoreRegionPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final double height = (media.size.height - media.viewInsets.bottom) * 0.85;
    final List<WorldCountry> matches = marketCountriesMatching(
      _query,
      excluded: widget.excluded,
    );

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text('Add region', style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              key: const Key('store-region-search'),
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Country or ISO code',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (String value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Text(
                      'No matching country.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (BuildContext context, int index) {
                      final WorldCountry country = matches[index];
                      return ListTile(
                        key: Key('store-region-option-${country.codeShort}'),
                        leading: Text(country.emoji, style: const TextStyle(fontSize: 24)),
                        title: Text(country.internationalName),
                        subtitle: Text('${country.codeShort} · ${country.code}'),
                        onTap: () => Navigator.pop(context, country.codeShort),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
