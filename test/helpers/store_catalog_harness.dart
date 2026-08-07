import 'dart:io';

import 'package:zelp/services/store_catalog_db.dart';

import '../services/store_catalog_test_db.dart';

/// Owns a temp directory + Drift [StoreCatalogDb] for unit tests.
class StoreCatalogDbHarness {
  late Directory tempDir;
  late StoreCatalogDb db;

  Future<void> setUp({String prefix = 'store_'}) async {
    tempDir = await Directory.systemTemp.createTemp(prefix);
    db = openTestStoreCatalogDb(tempDir);
  }

  Future<void> tearDown() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}
