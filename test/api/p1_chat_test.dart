import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:emie/api/api_error.dart';
import 'package:emie/api/client.dart';
import 'package:emie/core/config/env.dart';
import 'package:emie/data/chat/chat_api.dart';
import 'package:emie/data/chat/chat_models.dart';
import 'package:emie/data/chat/chat_repository.dart';
import 'package:emie/data/chat/chat_session_models.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import 'package:emie/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingRepository extends ChatRepository {
  final pending = Completer<ChatMessage>();
  int calls = 0;
  @override
  Future<ChatMessage> sendUserMessage({required String text, required String chatSessionId,
      String provider = 'openai', int maxTokens = 400, double temperature = .3}) {
    calls++;
    return pending.future;
  }
  @override
  Future<List<ChatSession>> listSessions() async => [];
}

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(options);
    return ResponseBody.fromString('{"detail":{"code":"P1_AUTH","message":"UNTRUSTED_SECRET"}}',503,
      headers:{Headers.contentTypeHeader:['application/json']});
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  test('P1 is explicit debug-only local configuration', () {
    expect(Env.p1, isTrue);
    expect(Env.apiBaseUrl, anyOf('http://127.0.0.1:8011', 'http://10.0.2.2:8011')); // VM defaults to Android; web uses loopback.
  });
  test('parallel clicks send once, state completes only after confirmed response', () async {
    final repository = PendingRepository();
    final controller = ChatController(repository: repository);
    final first = controller.send('Hallo');
    expect(controller.isSending, isTrue);
    await controller.send('Hallo');
    expect(repository.calls, 1);
    repository.pending.complete(ChatMessage(id:'synthetic',role:'assistant',text:'Hallo!',createdAt:DateTime.now()));
    await first;
    expect(controller.isSending,isFalse);
    expect(controller.lastSendConfirmed,isTrue);
    expect(controller.messages.where((m)=>m.role=='assistant').single.text,'Hallo!');
    controller.dispose();
  });
  test('provider error leaves no fake assistant reply and no retry', () async {
    final repository = PendingRepository();
    final controller = ChatController(repository: repository);
    final sending = controller.send('Hallo');
    final request = RequestOptions(path:'/v1/chat/respond');
    repository.pending.completeError(DioException(requestOptions:request,type:DioExceptionType.badResponse,
      response:Response(requestOptions:request,statusCode:503,data:{'detail':{'code':'P1_BUDGET','message':'UNTRUSTED_SECRET'}})));
    await sending;
    expect(repository.calls,1);
    expect(controller.lastSendConfirmed,isFalse);
    expect(controller.isSending,isFalse);
    expect(controller.messages.where((m)=>m.role=='assistant'),isEmpty);
    expect(controller.error,contains('kontingent'));
    expect(controller.error,isNot(contains('UNTRUSTED_SECRET')));
    controller.dispose();
  });
  test('P1 send disables authentication replay and allows bounded completion time', () async {
    final adapter = RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl:'http://127.0.0.1:8011'))..httpClientAdapter=adapter;
    await expectLater(ChatApi(dio:dio).sendMessage(text:'synthetic',chatSessionId:'new'),throwsA(isA<DioException>()));
    expect(adapter.requests,hasLength(1));
    expect(adapter.requests.single.extra[ApiClient.noRefreshKey],isTrue);
    expect(adapter.requests.single.receiveTimeout,const Duration(seconds:70));
    dio.close();
  });
  test('all local error codes map to fixed safe messages', () {
    for (final code in ['BUDGET','AUTH','MODEL','UNCERTAIN','NETWORK','RESPONSE','PRICE','POLICY','PROTECTED','SCOPE','BUSY','UNAVAILABLE']) {
      final request=RequestOptions(path:'/v1/chat/respond');
      final error=ApiError.fromDio(DioException(requestOptions:request,response:Response(requestOptions:request,
        statusCode:503,data:{'detail':{'code':'P1_$code','message':'UNTRUSTED_SECRET'}})));
      expect(error.message,isNot(contains('UNTRUSTED_SECRET')));
      expect(error.message,isNotEmpty);
    }
  });
  testWidgets('disabled send input is visible and cannot trigger a duplicate', (tester) async {
    final text=TextEditingController();
    int sent=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:ChatInputBar(controller:text,enabled:false,
      onSend:()=>sent++,onSnack:(_){},surface:Colors.white,border:Colors.grey,textPrimary:Colors.black,
      textSecondary:Colors.grey,bg:Colors.white,hintText:'Nachricht'))));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled,isFalse);
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    expect(sent,0);
    await tester.pumpWidget(const SizedBox());
    text.dispose();
  });
}
