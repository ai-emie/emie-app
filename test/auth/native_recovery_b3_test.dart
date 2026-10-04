import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emie/core/config/env.dart';
import 'package:emie/features/auth/navigation/recovery_link_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai.emie.app/recovery');
  const proof = 'synthetic_only_proof_1234567890';
  final local = 'http://10.0.2.2:${Env.localPort}/reset-password?token=$proof';

  test('local origin is accepted only by explicit local debug mode', () {
    final links = RecoveryLinkController(initialRoute: '/');
    addTearDown(links.dispose);
    expect(links.acceptRoute(local), isTrue);
    expect(links.token, Env.localDebug ? proof : null);
    for (final uri in [
      'https://untrusted.example/reset-password?token=$proof',
      'http://10.0.2.2:8001/reset-password?token=$proof',
      'http://user@10.0.2.2:8000/reset-password?token=$proof',
      '$local&baseUrl=https://untrusted.example',
      '$local#fragment',
      '$local&token=$proof',
    ]) {
      expect(links.acceptRoute(uri), isTrue);
      expect(links.token, isNull);
    }
  });

  test(
      'local port override is bounded to local debug and exact recovery origin',
      () {
    final before = Env.apiBaseUrl;
    if (Env.localDebug) {
      expect(before, 'http://10.0.2.2:${Env.localPort}');
      final other = Env.localPort == 8000 ? 8010 : 8000;
      expect(
          Env.allowsRecoveryOrigin(
              Uri.parse('http://10.0.2.2:$other/reset-password')),
          isFalse);
    } else {
      expect(before.contains(':${Env.localPort}'), isFalse);
    }
    expect(Env.apiBaseUrl, before);
  });

  test('native initial payload feeds the existing controller once', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'takeInitial');
      return local;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final links = RecoveryLinkController(initialRoute: '/');
    addTearDown(links.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(links.hasPending, isTrue);
    expect(links.token, Env.localDebug ? proof : null);
    links.dismiss();
    expect(links.token, isNull);
  });
}
