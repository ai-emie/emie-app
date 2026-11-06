import 'dart:async';
import 'package:dio/dio.dart';
import 'package:emie/api/api_error.dart';
import 'package:emie/data/chat/chat_models.dart';
import 'package:emie/data/chat/chat_repository.dart';
import 'package:emie/data/chat/chat_session_models.dart';
import 'package:emie/data/chat/pending_action.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryPending extends PendingActionStore {
  Map<String,String>? value;
  @override
  Future<Map<String,String>?> read(String? owner) async => value;
  @override
  Future<void> save(String? owner,String action,String session) async {
    value={'action':action,'session':session};
  }
  @override
  Future<void> clear(String? owner) async { value=null; }
}

class ActionRepository extends ChatRepository {
  int sends=0,checks=0;
  String? action,session;
  String state='uncertain';
  bool timeout=true;
  Completer<ChatMessage>? delayed;
  @override
  Future<ChatMessage> sendUserMessage({required String text,required String chatSessionId,
    String? actionId,String provider='openai',int maxTokens=400,double temperature=.3}) async {
    sends++;action=actionId;session=chatSessionId;
    if (delayed!=null) return delayed!.future;
    if (timeout) throw DioException(requestOptions:RequestOptions(),type:DioExceptionType.receiveTimeout);
    return answer();
  }
  ChatMessage answer()=>ChatMessage(id:'reply',role:'assistant',text:'Stored answer',createdAt:DateTime(2026));
  @override
  Future<Map<String,dynamic>> actionStatus(String id) async {
    checks++;expect(id,action);
    return {'state':state,'session_id':session,'error_code':'budget'};
  }
  @override
  Future<List<Map<String,dynamic>>> sessionActions(String id) async => [
    {'id':action,'state':state,'error_code':null}];
  @override
  Future<List<ChatMessage>> getMessages(String id) async => state=='completed' ? [answer()] : [];
  @override
  Future<List<ChatSession>> listSessions() async => [];
}

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('timeout keeps durable ID, removes fake assistant and checks without resending',() async {
    final repo=ActionRepository(),store=MemoryPending();
    final chat=ChatController(repository:repo,pendingStore:store);
    await chat.send('Synthetic action');
    expect(repo.sends,1);expect(repo.action,isNotEmpty);
    expect(chat.messages.where((m)=>m.role=='assistant'),isEmpty);
    expect(chat.hasPendingAction,true);expect(chat.lastSendConfirmed,false);
    await chat.send('Synthetic action');
    expect(repo.sends,1);expect(repo.checks,1);
    final original=store.value;
    chat.dispose();
    final resumed=ChatController(repository:repo,pendingStore:store);
    await resumed.loadSessions();
    expect(resumed.hasPendingAction,true);expect(store.value,original);
    repo.state='completed';
    await resumed.checkPendingAction();
    expect(repo.sends,1);expect(resumed.lastSendConfirmed,true);
    expect(resumed.messages.single.text,'Stored answer');expect(store.value,isNull);
    resumed.dispose();
  });
  test('a confirmed failure allows an explicitly new action with a new ID',() async {
    final repo=ActionRepository(),store=MemoryPending();
    final chat=ChatController(repository:repo,pendingStore:store);
    await chat.send('first');final first=repo.action;
    repo.state='failed';await chat.checkPendingAction();
    expect(chat.hasPendingAction,false);expect(chat.error,contains('Kostenlimit'));
    repo.timeout=false;await chat.send('new deliberate action');
    expect(repo.sends,2);expect(repo.action,isNot(first));
    expect(chat.lastSendConfirmed,true);chat.dispose();
  });
  test('double send and late account response cannot change another account',() async {
    final repo=ActionRepository()..delayed=Completer<ChatMessage>();
    final chat=ChatController(repository:repo,pendingStore:MemoryPending());
    final first=chat.send('synthetic');
    await Future<void>.delayed(Duration.zero);
    await chat.send('synthetic');expect(repo.sends,1);
    SessionStore.instance.beginSession();
    repo.delayed!.complete(repo.answer());await first;
    expect(chat.lastSendConfirmed,false);
    expect(chat.messages.where((m)=>m.text=='Stored answer'),isEmpty);
    chat.dispose();
  });
  test('public errors are fixed text, never provider details',(){
    for(final code in ['AI_BUDGET','AI_AI_DISABLED','AI_PROVIDER','AI_LIMIT','AI_UNCERTAIN','AI_IN_PROGRESS']){
      final options=RequestOptions();
      final error=ApiError.fromDio(DioException(requestOptions:options,response:Response(
        requestOptions:options,statusCode:503,data:{'detail':{'code':code,'message':'private-provider-body'}})));
      expect(error.message,isNot(contains('private-provider-body')));
      expect(error.message,isNotEmpty);
    }
  });
}
