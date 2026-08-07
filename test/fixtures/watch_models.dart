import 'package:zelp/models/watch_model.dart';

/// Canonical GTR 4 fixture used across catalog / shell tests.
WatchModel gtr4Watch({List<WatchVariant>? variants}) => WatchModel(
  deviceId: 'gtr4',
  name: 'GTR 4',
  osVersion: '3.0',
  variants: variants ?? <WatchVariant>[gtr4Variant()],
);

WatchVariant gtr4Variant({
  int deviceSource = 229,
  int productionId = 1,
  String appName = 'com.huami.midong',
}) => WatchVariant(
  deviceSource: deviceSource,
  productionId: productionId,
  appName: appName,
);

/// Bip 5 with dual device sources (MRU / source-picker tests).
WatchModel bip5Watch({List<WatchVariant>? variants}) => WatchModel(
  deviceId: 'bip5',
  name: 'Bip 5',
  osVersion: '3.0',
  variants:
      variants ??
      <WatchVariant>[
        WatchVariant(
          deviceSource: 851,
          productionId: 1,
          appName: 'com.huami.midong',
        ),
        WatchVariant(
          deviceSource: 852,
          productionId: 2,
          appName: 'com.huami.midong',
        ),
      ],
);
