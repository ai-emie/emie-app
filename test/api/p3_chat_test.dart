import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:emie/api/client.dart';
import 'package:emie/api/api_error.dart';
import 'package:emie/core/config/env.dart';
import 'package:emie/data/chat/chat_api.dart';
import 'package:emie/data/chat/chat_models.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import 'package:emie/features/chat/presentation/widgets/windows_chat_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'p1_chat_test.dart' show PendingRepository;

class StatusAdapter implements HttpClientAdapter {
  Object data = {'mode': 'P3', 'remaining_calls': 40, 'remaining_micro_usd': 1000000,
    'acceptance_calls': 0, 'acceptance': false, 'blocked': null};
  bool disconnected = false;
  int status = 200;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async {
    requests.add(options);
    if (disconnected) throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    return ResponseBody.fromString(jsonEncode(data), status,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  test('P3 is exclusive local Android; Mac and P2 defines remain false', () {
    expect(Env.p3, isTrue);
    expect(Env.p1, isFalse);
    expect(Env.offline, isFalse);
    expect(Env.localAi, isTrue);
    expect(Env.apiBaseUrl, 'http://10.0.2.2:8011');
  });
  test('P3 refuses a non-Android target before HTTP client construction', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(() => Env.apiBaseUrl, throwsStateError);
  });

  test('send remains single, confirmation requires response; new chat has new id', () async {
    final repository = PendingRepository();
    final controller = ChatController(repository: repository);
    final previous = controller.chatSessionId;
    final pending = controller.send('synthetic one');
    await controller.send('synthetic duplicate');
    controller.newChat();
    expect(controller.chatSessionId, previous);
    expect(controller.lastSendConfirmed, isFalse);
    expect(repository.calls, 1);
    repository.pending.complete(ChatMessage(id: 'reply', role: 'assistant', text: 'Synthetic', createdAt: DateTime(2026)));
    await pending;
    expect(controller.lastSendConfirmed, isTrue);
    controller.newChat();
    expect(controller.chatSessionId, isNot(previous));
    expect(controller.messages, isEmpty);
    controller.dispose();
  });

  test('P3 errors never become assistant replies and never replay', () async {
    for (final code in ['AUTH', 'BUDGET', 'UNCERTAIN', 'MODEL', 'NETWORK', 'RESPONSE', 'POLICY']) {
      final repository = PendingRepository();
      final controller = ChatController(repository: repository);
      final pending = controller.send('synthetic');
      final request = RequestOptions(path: '/v1/chat/respond');
      repository.pending.completeError(DioException(requestOptions: request,
          response: Response(requestOptions: request, statusCode: 503,
              data: {'detail': {'code': 'P3_$code', 'message': 'PRIVATE_UNTRUSTED'}})));
      await pending;
      expect(repository.calls, 1);
      expect(controller.lastSendConfirmed, isFalse);
      expect(controller.messages.where((m) => m.role == 'assistant'), isEmpty);
      expect(controller.error, isNot(contains('PRIVATE_UNTRUSTED')));
      controller.dispose();
    }
  });

  test('P3 POST disables auth replay and keeps bounded timeout', () async {
    final adapter = StatusAdapter()..status = 401;
    final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8011'))..httpClientAdapter = adapter;
    await expectLater(ChatApi(dio: dio).sendMessage(text: 'synthetic', chatSessionId: 'new'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.extra[ApiClient.noRefreshKey], isTrue);
    expect(adapter.requests.single.receiveTimeout, const Duration(seconds: 70));
    dio.close();
  });
  test('unclear network outcome tells user not to resend and adds no answer', () async {
    final repository = PendingRepository();
    final controller = ChatController(repository: repository);
    final pending = controller.send('synthetic');
    repository.pending.completeError(DioException(requestOptions: RequestOptions(path: '/v1/chat/respond'),
        type: DioExceptionType.receiveTimeout));
    await pending;
    expect(repository.calls, 1);
    expect(controller.messages.where((m) => m.role == 'assistant'), isEmpty);
    expect(controller.error, contains('nicht erneut senden'));
    controller.dispose();
  });

  test('P2 response remains an explicit offline error', () {
    final request = RequestOptions(path: '/v1/chat/respond');
    final error = ApiError.fromDio(DioException(requestOptions: request,
        response: Response(requestOptions: request, statusCode: 403,
            data: {'detail': {'code': 'P2_OFFLINE', 'message': 'UNTRUSTED'}})));
    expect(error.message, contains('Offline-Modus'));
  });

  testWidgets('read-only status enables only valid KI and reflects disconnect/budget', (tester) async {
    final adapter = StatusAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8011'))..httpClientAdapter = adapter;
    final states = <bool>[];
    await tester.pumpWidget(MaterialApp(home: WindowsChatStatus(dio: dio, onReady: states.add)));
    await tester.pumpAndSettle();
    expect(states.last, isTrue);
    expect(find.textContaining('40/40'), findsOneWidget);
    adapter.disconnected = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(states.last, isFalse);
    expect(find.textContaining('nicht verbunden'), findsOneWidget);
    adapter.disconnected = false;
    adapter.data = {'mode': 'P3', 'remaining_calls': 32, 'remaining_micro_usd': 500000,
      'acceptance_calls': 8, 'acceptance': true, 'blocked': {'code': 'P3_BUDGET', 'message': 'UNTRUSTED'}};
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(states.last, isFalse);
    expect(find.textContaining('kontingent'), findsOneWidget);
    expect(find.textContaining('UNTRUSTED'), findsNothing);
    expect(adapter.requests.every((r) => r.method == 'GET' && r.path == '/v1/local/status'), isTrue);
    await tester.pumpWidget(const SizedBox());
    dio.close();
  });
}
