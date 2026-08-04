import 'package:flutter_test/flutter_test.dart';
import 'package:zelp/domain/store/market_api_level.dart';
import 'package:zelp/models/watch_model.dart';

void main() {
  group('marketApiLevelFromVersion', () {
    test('encodes major.minor as major×100+minor', () {
      expect(marketApiLevelFromVersion('2.0'), 200);
      expect(marketApiLevelFromVersion('2.1.0'), 201);
      expect(marketApiLevelFromVersion('3.6.0'), 306);
      expect(marketApiLevelFromVersion('4.4'), 404);
      expect(marketApiLevelFromVersion('3'), 300);
    });

    test('falls back for empty or unparseable values', () {
      expect(marketApiLevelFromVersion(''), 500);
      expect(marketApiLevelFromVersion('legacy'), 500);
      expect(marketApiLevelFromVersion('  '), 500);
      expect(marketApiLevelFromVersion('x', fallback: 1), 1);
    });
  });

  group('WatchModel.marketApiLevel', () {
    test('prefers apiVersion over osVersion', () {
      final WatchModel watch = WatchModel(
        deviceId: 'active',
        name: 'Active',
        osVersion: '4.0',
        apiVersion: '3.6.0',
        variants: <WatchVariant>[
          WatchVariant(
            deviceSource: 1,
            productionId: 1,
            appName: 'com.huami.midong',
          ),
        ],
      );
      expect(watch.marketApiLevel, 306);
    });

    test('falls back to osVersion when apiVersion is empty', () {
      final WatchModel watch = WatchModel(
        deviceId: 'bip5',
        name: 'Bip 5',
        osVersion: '2.1.0',
        variants: <WatchVariant>[
          WatchVariant(
            deviceSource: 1,
            productionId: 1,
            appName: 'com.huami.midong',
          ),
        ],
      );
      expect(watch.marketApiLevel, 201);
    });
  });
}
