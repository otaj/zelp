import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:zelp/services/store_catalog/store_catalog_database.dart';
import 'package:zelp/services/store_catalog_db.dart';

/// Opens a Drift-backed [StoreCatalogDb] under [tempDir] for unit tests.
StoreCatalogDb openTestStoreCatalogDb(Directory tempDir) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return StoreCatalogDb(
    database: StoreCatalogDatabase(
      NativeDatabase.createInBackground(File(p.join(tempDir.path, 'catalog.db'))),
    ),
  );
}
