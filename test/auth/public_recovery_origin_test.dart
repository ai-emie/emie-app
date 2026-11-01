import 'package:flutter_test/flutter_test.dart';
import 'package:emie/core/config/env.dart';
import 'package:emie/features/auth/navigation/recovery_link_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const proof = 'synthetic_public_proof_1234567890';
  // This test is invoked with a synthetic HTTPS origin; no domain association.
  test('public ingress has an exact HTTPS host, port and reset path', () {
    expect(Env.localDebug, isFalse);
    expect(Env.recoveryOrigin, 'https://links.example:8443');
    final links = RecoveryLinkController(initialRoute: '/');
    addTearDown(links.dispose);
    final base = Env.apiBaseUrl;
    expect(links.acceptRoute('${Env.recoveryOrigin}/reset-password?token=$proof'), isTrue);
    expect(links.token, proof);
    for (final route in [
      'http://links.example:8443/reset-password?token=$proof',
      'https://links.example/reset-password?token=$proof',
      'https://links.example:8444/reset-password?token=$proof',
      'https://sub.links.example:8443/reset-password?token=$proof',
      'https://links.example.evil:8443/reset-password?token=$proof',
      'https://user@links.example:8443/reset-password?token=$proof',
      '${Env.recoveryOrigin}/reset-password?token=$proof&baseUrl=https://evil.example',
      '${Env.recoveryOrigin}/reset-password?token=$proof#fragment',
      '${Env.recoveryOrigin}/reset-password?token=$proof&token=$proof',
    ]) {
      expect(links.acceptRoute(route), isTrue);
      expect(links.token, isNull, reason: route.split('?').first);
      expect(Env.apiBaseUrl, base);
    }
    links.dismiss();
    for (final path in ['/reset-password/','/other','/v1/auth/verify/']) {
      expect(links.acceptRoute('${Env.recoveryOrigin}$path?token=$proof'), isFalse);
      expect(links.hasPending, isFalse);
    }
  });

  test('existing verification ingress keeps its separate proof contract', () {
    final links = RecoveryLinkController(initialRoute: '/');
    addTearDown(links.dispose);
    const verifyProof = 'synthetic_verify_proof_123456789';
    expect(verifyProof.length, 32);
    expect(links.acceptRoute('${Env.recoveryOrigin}/v1/auth/verify?token=$verifyProof'), isTrue);
    expect(links.isVerification, isTrue);
    expect(links.token, verifyProof);
    for (final route in [
      '${Env.recoveryOrigin}/v1/auth/verify',
      '${Env.recoveryOrigin}/v1/auth/verify?token=$proof',
      '${Env.recoveryOrigin}/v1/auth/verify?token=$verifyProof&token=$verifyProof',
      'https://other.example:8443/v1/auth/verify?token=$verifyProof',
    ]) {
      expect(links.acceptRoute(route), isTrue);
      expect(links.isVerification, isTrue);
      expect(links.token, isNull);
    }
  });
}
