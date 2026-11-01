import 'package:flutter_test/flutter_test.dart';
import 'package:emie/core/config/env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('public build defines select matching API and recovery targets', () {
    expect(Env.publicRequested, isTrue);
    const configured = bool.fromEnvironment('P6B_VALID_TARGET');
    if (!configured) {
      expect(() => Env.apiBaseUrl, throwsStateError);
      return;
    }
    expect(Env.apiBaseUrl, 'https://shared.example.test');
    expect(Env.allowsRecoveryOrigin(Uri.parse('https://shared.example.test/reset-password')), isTrue);
    expect(Env.allowsRecoveryOrigin(Uri.parse('https://other.example.test/reset-password')), isFalse);
  });
}
