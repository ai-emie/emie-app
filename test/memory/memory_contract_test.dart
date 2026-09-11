import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:emie/data/memory/api/memory_api.dart';
import 'package:emie/data/memory/models/memory_item.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixture copied byte-for-byte from the successful real main.app HTTP test:
// app.tests.test_memory_http_contract.MemoryHTTPContractTests.
// test_patch_flutter_value_roundtrip_and_response_fixture
// Run: memory-contract-20260911T132521Z-e9680f24, phase memory-green.
// Source: phases/memory-green/evidence/memory-contract-responses.json.
// Fixture SHA-256: 94c550b0ad3b65cc38e0afd88612fef74098dd9ca129e18b10203641a4508db4.
// All records are synthetic. No live backend, provider, or device is used.
const _original = '  Grüße aus Wien 🙂\n第二行  ';
const _edited = 'Überarbeitet 🌱\nzweite Zeile';

void main() {
  late Map<String, dynamic> responses;

  setUp(() {
    responses = jsonDecode(
      File('test/fixtures/memory_contract_responses.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('real LIST fixture parses Unicode, newlines and surrounding spaces', () {
    final row = (responses['list']['items'] as List<dynamic>).first
        as Map<String, dynamic>;
    final item = MemoryItem.fromJson(row);

    expect(row['value'], _original);
    expect(row['content'], row['value']);
    expect(item.id, 'own');
    expect(item.content, _original);
    expect(item.category, 'facts');
    expect(item.importance, 5);
    expect(item.createdAt, DateTime.parse(row['created_at'] as String));
  });

  test('real LIST fixture preserves a valid empty memory', () {
    final row = (responses['list']['items'] as List<dynamic>).last
        as Map<String, dynamic>;
    final item = MemoryItem.fromJson(row);

    expect(row['id'], 'empty');
    expect(row['value'], '');
    expect(row['content'], '');
    expect(item.content, '');
  });

  test('real PATCH and reloaded LIST fixtures parse the same edited content', () {
    final patch = responses['patch'] as Map<String, dynamic>;
    final reloaded = (responses['reloaded']['items'] as List<dynamic>).first
        as Map<String, dynamic>;

    expect(MemoryItem.fromJson(patch).content, _edited);
    expect(MemoryItem.fromJson(reloaded).content, _edited);
    expect(patch['content'], patch['value']);
    expect(reloaded['content'], reloaded['value']);
    expect(patch['meta'], reloaded['meta']);
  });

  test('MemoryApi reads the actual LIST envelope through its existing seam',
      () async {
    final api = _api((request) {
      expect(request.method, 'GET');
      expect(request.path, '/v1/memory/list');
      return responses['list'];
    });

    final items = await api.fetchMemories();

    expect(items.map((item) => item.id), ['own', 'empty']);
    expect(items.map((item) => item.content), [_original, '']);
  });

  test('MemoryApi sends value and parses the actual PATCH response', () async {
    final api = _api((request) {
      expect(request.method, 'PATCH');
      expect(request.path, '/v1/memory/own');
      expect(request.data, {'value': _edited});
      return responses['patch'];
    });

    final item = await api.updateMemory(id: 'own', content: _edited);

    expect(item.id, 'own');
    expect(item.content, _edited);
    expect(item.importance, 5);
  });

  test('MemoryApi list edit reload consumes the recorded backend sequence',
      () async {
    final requests = <String>[];
    final bodies = [responses['list'], responses['patch'], responses['reloaded']];
    final api = _api((request) {
      requests.add('${request.method} ${request.path}');
      expect(requests.length, lessThanOrEqualTo(bodies.length));
      if (request.method == 'PATCH') {
        expect(request.data, {'value': _edited});
      }
      return bodies[requests.length - 1];
    });

    final before = await api.fetchMemories();
    final edited = await api.updateMemory(id: 'own', content: _edited);
    final after = await api.fetchMemories();

    expect(before.first.content, _original);
    expect(edited.content, _edited);
    expect(after.first.content, edited.content);
    expect(after.last.content, '');
    expect(requests, [
      'GET /v1/memory/list',
      'PATCH /v1/memory/own',
      'GET /v1/memory/list',
    ]);
  });
}

MemoryApi _api(Object Function(RequestOptions) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://memory.example.invalid'));
  dio.httpClientAdapter = _FixtureAdapter(respond);
  addTearDown(() => dio.close(force: true));
  return MemoryApi(dio: dio);
}

// This adapter always returns the recorded body locally; it has no socket path.
class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(this.respond);

  final Object Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(respond(options)),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
