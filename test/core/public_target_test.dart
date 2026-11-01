import 'package:flutter_test/flutter_test.dart';
import 'package:emie/core/config/public_target.dart';

void main() {
  const origin = 'https://shared.example.test';
  test('public API and recovery share one explicit canonical origin', () {
    final target = resolvePublicTarget(apiOrigin: '$origin:443/', recoveryOrigin: origin);
    expect(target.apiOrigin, origin);
    expect(target.recoveryOrigin, origin);
  });
  test('missing, local, credentialed or ambiguous public targets fail closed', () {
    for (final bad in ['', 'http://shared.example.test', 'https://user@shared.example.test',
      '$origin/path', '$origin?', '$origin#fragment', '$origin:8443', '$origin ',
      'https://10.0.2.2', 'https://127.0.0.1', 'https://localhost',
      'https://service.internal', 'https://*.example.test', 'https://SHARED.example.test']) {
      expect(() => resolvePublicTarget(apiOrigin: bad, recoveryOrigin: origin), throwsStateError);
      expect(() => resolvePublicTarget(apiOrigin: origin, recoveryOrigin: bad), throwsStateError);
    }
  });
  test('mismatched destinations and combined local modes are rejected', () {
    expect(() => resolvePublicTarget(apiOrigin: origin, recoveryOrigin: 'https://other.example.test'), throwsStateError);
    expect(() => resolvePublicTarget(apiOrigin: origin, recoveryOrigin: origin, localMode: true), throwsStateError);
    expect(() => resolvePublicTarget(apiOrigin: origin, recoveryOrigin: origin, environment: 'dev'), throwsStateError);
  });
}
