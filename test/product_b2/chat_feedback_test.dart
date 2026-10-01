import 'dart:async';
import 'package:emie/data/chat/chat_models.dart';
import 'package:emie/data/chat/chat_repository.dart';
import 'package:emie/data/chat/chat_session_models.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FeedbackRepository extends ChatRepository {
  bool fail = false;
  int deletes = 0;
  Completer<List<ChatMessage>>? pending;
  String? sentId;
  @override
  Future<List<ChatSession>> listSessions() async {
    if (fail) throw StateError('private error');
    return [
      ChatSession(
          id: sentId ?? 'old',
          title: 'Stored',
          createdAt: null,
          updatedAt: null)
    ];
  }

  @override
  Future<List<ChatMessage>> getMessages(String id) async {
    if (pending != null) return pending!.future;
    if (fail) throw StateError('private error');
    return [
      ChatMessage(id: 'm', role: 'user', text: id, createdAt: DateTime(2026))
    ];
  }

  @override
  Future<void> deleteSession(String id) async {
    deletes++;
    if (fail) throw StateError('private error');
  }

  @override
  Future<ChatMessage> sendUserMessage(
      {required String text,
      required String chatSessionId,
      String provider = 'openai',
      int maxTokens = 400,
      double temperature = .3}) async {
    if (fail) throw StateError('private error');
    sentId = chatSessionId;
    return ChatMessage(
        id: 'reply',
        role: 'assistant',
        text: 'Confirmed reply',
        createdAt: DateTime(2026));
  }
}

void main() {
  test(
      'history failures remain distinct from empty history and expose no server details',
      () async {
    final repo = FeedbackRepository()..fail = true;
    final actual = ChatController(repository: repo);
    addTearDown(actual.dispose);
    await actual.loadSessions();
    expect(actual.error, 'history_load_failed');
    expect(actual.sessions, isEmpty);
    repo.fail = false;
    await actual.loadSessions();
    expect(actual.error, isNull);
    expect(actual.sessions.length, 1);
  });
  test(
      'failed open retains original conversation and failed deletion never claims success',
      () async {
    final repo = FeedbackRepository();
    final actual = ChatController(repository: repo);
    addTearDown(actual.dispose);
    await actual.openChat('old');
    repo.fail = true;
    await actual.openChat('missing');
    expect(actual.chatSessionId, 'old');
    expect(actual.messages.single.text, 'old');
    expect(actual.error, 'chat_open_failed');
    expect(await actual.deleteChat('old'), false);
    expect(actual.error, 'delete_unconfirmed');
    expect(actual.chatSessionId, 'old');
    expect(repo.deletes, 1);
    repo.fail = false;
    expect(await actual.deleteChat('old'), true);
    expect(actual.messages, isEmpty);
  });
  test(
      'send acknowledgement alone enables saved feedback and next failure clears it',
      () async {
    final repo = FeedbackRepository();
    final chat = ChatController(repository: repo);
    addTearDown(chat.dispose);
    expect(chat.lastSendConfirmed, false);
    await chat.send('hello');
    expect(chat.lastSendConfirmed, true);
    repo.fail = true;
    await chat.send('next');
    expect(chat.lastSendConfirmed, false);
    expect(chat.error, isNotNull);
  });
  test(
      'new chat invalidates a pending open without leaving loading permanently active',
      () async {
    final repo = FeedbackRepository()..pending = Completer<List<ChatMessage>>();
    final chat = ChatController(repository: repo);
    addTearDown(chat.dispose);
    final pending = chat.openChat('old');
    expect(chat.isLoadingHistory, true);
    chat.newChat();
    final id = chat.chatSessionId;
    expect(chat.isLoadingHistory, false);
    repo.pending!.complete([
      ChatMessage(
          id: 'old', role: 'user', text: 'old', createdAt: DateTime(2026))
    ]);
    await pending;
    expect(chat.chatSessionId, id);
    expect(chat.messages, isEmpty);
  });
  test('deleting a conversation invalidates its pending open', () async {
    final repo = FeedbackRepository()..pending = Completer<List<ChatMessage>>();
    final chat = ChatController(repository: repo);
    addTearDown(chat.dispose);
    final currentId = chat.chatSessionId;
    final pending = chat.openChat('deleted');
    expect(await chat.deleteChat('deleted'), true);
    repo.pending!.complete([
      ChatMessage(
          id: 'm', role: 'user', text: 'deleted', createdAt: DateTime(2026))
    ]);
    await pending;
    expect(chat.chatSessionId, currentId);
    expect(chat.messages, isEmpty);
    expect(chat.isLoadingHistory, false);
  });
}
