import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/store/market_countries.dart';
import 'package:zelp/services/prefs_store.dart';

/// Amazfit regions queried when expert mode limits a store catalog refresh.
class StoreRegionStore extends PrefsStore {
  StoreRegionStore({super.prefs});

  static const String prefsKey = 'store_market_countries';

  /// Saved regions, or every [kDefaultMarketCountries] entry when unset.
  Future<List<String>> load() async {
    final SharedPreferences prefs = await ensurePrefs();
    final List<String>? saved = prefs.getStringList(prefsKey);
    if (saved == null) return List<String>.from(kDefaultMarketCountries);
    return normalizeMarketCountries(saved);
  }

  /// Persists [countries]. Unknown codes are dropped. An empty selection is
  /// stored as every default region.
  Future<List<String>> save(List<String> countries) async {
    final List<String> normalized = normalizeMarketCountries(countries);
    final SharedPreferences prefs = await ensurePrefs();
    await prefs.setStringList(prefsKey, normalized);
    return normalized;
  }
}
