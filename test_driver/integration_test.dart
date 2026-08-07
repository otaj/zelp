import 'package:integration_test/integration_test_driver.dart';

/// Host-side driver. PNG capture is handled by `capture_screenshots.sh` via adb.
Future<void> main() => integrationDriver();
