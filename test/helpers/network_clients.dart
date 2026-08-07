import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zelp/services/zepp_version_client.dart';

/// HTTP client that fails the test if any request is attempted.
MockClient neverHttpClient([String label = 'must not hit the network']) => MockClient((_) async {
  fail(label);
});

/// Offline [ZeppVersionClient] that never contacts the network.
ZeppVersionClient offlineZeppVersionClient(
  SharedPreferences prefs, {
  String fallbackVersion = '10.0.0-play_1',
  String failLabel = 'zepp version must not hit the network',
}) => ZeppVersionClient(
  prefs: prefs,
  fallbackVersion: fallbackVersion,
  httpClient: neverHttpClient(failLabel),
);
