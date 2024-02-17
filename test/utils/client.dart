import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'test_client.dart';

late TestMeiliSearchClient client;
final random = Random();

class TestingHttpOverrides extends HttpOverrides {}

const bool _kIsWeb = bool.fromEnvironment('dart.library.js_util');
String get testServer {
  const defaultUrl = 'http://localhost:7700';
  if (_kIsWeb) {
    return defaultUrl;
  } else {
    return Platform.environment['MEILISEARCH_URL'] ?? defaultUrl;
  }
}

String get testApiKey {
  return 'masterKey';
}

void setUpClient() {
  setUp(() {
  HttpOverrides.global = TestingHttpOverrides();

    client = TestMeiliSearchClient(testServer, testApiKey);
  });
  tearDown(() => client.disposeUsedResources());
}

String randomUid([String prefix = 'index']) {
  return '${prefix}_${random.nextInt(9999)}';
}
