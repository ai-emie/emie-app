import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emie/core/config/env.dart';
import 'package:emie/features/auth/controller/auth_controller.dart';
import 'package:emie/features/auth/navigation/recovery_link_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai.emie.app/recovery');
  const proof = 'synthetic_only_proof_1234567890';
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('unconfigured iOS Google is visibly unavailable without invoking provider', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const config = MethodChannel('ai.emie.app/config');
    messenger.setMockMethodCallHandler(config, (call) async {
      expect(call.method, 'googleAvailable');
      return false;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(config, null));
    final auth = AuthController();
    addTearDown(auth.dispose);
    expect(await auth.loginWithGoogle(), isFalse);
    expect(auth.errorMessage, contains('noch nicht konfiguriert'));
  });
  test('iOS local host is exact loopback and Android remains unchanged', () {
    expect(Env.localHost, '127.0.0.1');
    if (Env.localDebug) {
      expect(Env.apiBaseUrl, 'http://127.0.0.1:${Env.localPort}');
      expect(Env.allowsRecoveryOrigin(Uri.parse('http://10.0.2.2:${Env.localPort}/reset-password')), isFalse);
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(Env.localHost, '10.0.2.2');
  });
  test('iOS channel consumes initial link and preserves exact validation', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async =>
      'http://127.0.0.1:${Env.localPort}/reset-password?token=$proof');
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final controller = RecoveryLinkController(initialRoute: '/');
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(controller.hasPending, isTrue);
    expect(controller.token, Env.localDebug ? proof : null);
    for (final route in [
      'http://127.0.0.1:8000/reset-password?token=$proof',
      'http://user@127.0.0.1:${Env.localPort}/reset-password?token=$proof',
      'http://127.0.0.1:${Env.localPort}/reset-password?token=$proof#x',
      'http://127.0.0.1:${Env.localPort}/reset-password?token=$proof&token=$proof',
      'http://127.0.0.1:${Env.localPort}/reset-password?token=$proof&backend=http://bad',
      'http://127.0.0.1:${Env.localPort}/reset-password?token=short',
    ]) { controller.acceptRoute(route); expect(controller.token, isNull); }
    controller.dismiss();
    expect(controller.hasPending, isFalse);
  });
}
