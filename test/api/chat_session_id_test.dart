import 'package:emie/data/chat/chat_repository.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoRequests implements ChatRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Session creation must not access the backend');
}

void main() {
  final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  test('chat controller starts with a valid UUID v4 without a request', () {
    final controller = ChatController(repository: _NoRequests());
    addTearDown(controller.dispose);
    expect(controller.chatSessionId, matches(uuidV4));
    expect(controller.messages, isEmpty);
  });

  test('new local chat gets a distinct UUID v4 without a request', () {
    final controller = ChatController(repository: _NoRequests());
    addTearDown(controller.dispose);
    final previous = controller.chatSessionId;
    controller.newChat();
    expect(controller.chatSessionId, matches(uuidV4));
    expect(controller.chatSessionId, isNot(previous));
    expect(controller.messages, isEmpty);
  });
}
