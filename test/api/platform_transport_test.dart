import 'package:emie/api/client.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const origin = String.fromEnvironment('M10_TRANSPORT_TEST_ORIGIN');
  setUp(() => SessionStore.instance.clear());
  for (final refresh in [false, true]) {
    test('${refresh ? 'refresh' : 'main'} default transport reaches loopback',
        () async {
      expect(origin, startsWith('http://127.0.0.1:'));
      final client = ApiClient();
      final dio = refresh ? client.refreshDio : client.dio;
      final response = await dio.get<Map<String, dynamic>>('$origin/health');
      expect(response.statusCode, 200);
      expect(response.data, {'m10': 'synthetic_transport_ok'});
    },
        skip: origin.isEmpty
            ? 'Requires a synthetic loopback test server'
            : false);
  }
}
