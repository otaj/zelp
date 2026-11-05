import 'package:flutter_test/flutter_test.dart';
import 'package:sealed_countries/sealed_countries.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/domain/store/market_countries.dart';
import 'package:zelp/services/store_region_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('store regions default to every market country and round-trip', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final StoreRegionStore store = StoreRegionStore(prefs: await SharedPreferences.getInstance());
    expect(await store.load(), kDefaultMarketCountries);

    expect(await store.save(const <String>['us', 'CN']), <String>['US', 'CN']);
    expect(await store.load(), <String>['US', 'CN']);

    final StoreRegionStore reloaded = StoreRegionStore(prefs: await SharedPreferences.getInstance());
    expect(await reloaded.load(), <String>['US', 'CN']);
  });

  test('ISO countries outside the default four are kept', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final StoreRegionStore store = StoreRegionStore(prefs: await SharedPreferences.getInstance());
    expect(
      await store.save(const <String>['de', 'XX', 'us', 'DE']),
      <String>['DE', 'US'],
    );
    expect(labelForMarketCountry('DE'), 'Germany');
    expect(flagForMarketCountry('DE'), isNotEmpty);
    expect(flagForMarketCountry('xx'), isEmpty);
    expect(labelForMarketCountry('xx'), 'XX');
    expect(
      marketCountriesMatching('Germany').map((WorldCountry country) => country.codeShort),
      <String>['DE'],
    );
    expect(
      marketCountriesMatching('Germany', excluded: const <String>['DE']),
      isEmpty,
    );
  });

  test('empty or unknown region selections fall back to every default', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      StoreRegionStore.prefsKey: <String>['XX'],
    });
    final StoreRegionStore store = StoreRegionStore(prefs: await SharedPreferences.getInstance());
    expect(await store.load(), kDefaultMarketCountries);
    expect(await store.save(const <String>[]), kDefaultMarketCountries);
  });
}
