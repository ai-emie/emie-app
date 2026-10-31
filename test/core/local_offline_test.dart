import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emie/core/config/env.dart';

void main() {
  test('P2 stays on explicit Android loopback without enabling Mac P1', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(Env.localDebug, isTrue);
    expect(Env.offline, isTrue);
    expect(Env.p1, isFalse);
    expect(Env.apiBaseUrl, 'http://10.0.2.2:8011');
  });
}
