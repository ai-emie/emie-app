import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emie/core/config/local_debug_target.dart';
import 'package:emie/core/config/env.dart';

void main() {
  test('explicit iPhone private target; unchanged simulator and Android', () {
    expect(resolveLocalDebugHost(debug: true, ios: true, local: true, device: true, host: '172.20.10.11'), '172.20.10.11');
    expect(resolveLocalDebugHost(debug: true, ios: true, local: true, device: false, host: ''), '127.0.0.1');
    expect(resolveLocalDebugHost(debug: true, ios: false, local: true, device: true, host: '172.20.10.11'), '10.0.2.2');
    for (final mode in ['profile', 'release']) {
      const debug = false; // Both modes compile with kDebugMode == false.
      expect(resolveLocalDebugHost(debug: debug, ios: true, local: true, device: true, host: '172.20.10.11'), '127.0.0.1', reason: mode);
    }
  });
  test('missing activation and non-RFC1918 addresses fail closed', () {
    for (final pair in [(false, true), (true, false)]) {
      expect(() => resolveLocalDebugHost(debug: true, ios: true, local: pair.$1, device: pair.$2, host: '172.20.10.11'), throwsStateError);
    }
    for (final host in ['', '127.0.0.1', '0.0.0.0', '8.8.8.8', '169.254.1.1', '172.32.0.1', 'localhost', '192.168.001.1', '10.0.0.256', 'http://10.0.0.1', 'user@10.0.0.1', '10.0.0.1:8010', '10.0.0.1/24']) {
      expect(() => resolveLocalDebugHost(debug: true, ios: true, local: true, device: true, host: host), throwsStateError);
    }
  });
  test('actual Env API and recovery use the same exact compile-time target', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    if (!const bool.fromEnvironment('EMIE_LOCAL_DEVICE')) {
      expect(Env.localHost, '127.0.0.1');
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(Env.localHost, '10.0.2.2');
      return;
    }
    expect(Env.apiBaseUrl, 'http://172.20.10.11:8013');
    expect(Env.allowsRecoveryOrigin(Uri.parse('http://172.20.10.11:8013/reset-password')), isTrue);
    for (final uri in ['http://172.20.10.12:8013/reset-password', 'http://172.20.10.11:8010/reset-password', 'https://172.20.10.11:8013/reset-password', 'http://127.0.0.1:8013/reset-password']) {
      expect(Env.allowsRecoveryOrigin(Uri.parse(uri)), isFalse);
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(Env.apiBaseUrl, 'http://10.0.2.2:8013');
  });
}
