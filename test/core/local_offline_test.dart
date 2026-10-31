import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emie/core/config/env.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import '../api/p1_chat_test.dart' show PendingRepository;

void main() {
  test('P2 stays on explicit Android loopback without enabling Mac P1', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(Env.localDebug, isTrue);
    expect(Env.offline, isTrue);
    expect(Env.p1, isFalse);
    expect(Env.apiBaseUrl, 'http://10.0.2.2:8011');
  });
  test('P2 controller cannot dispatch a chat even when invoked directly', () async {
    final repository = PendingRepository();
    final controller = ChatController(repository: repository);
    await controller.send('synthetic offline input');
    expect(repository.calls, 0);
    expect(controller.messages, isEmpty);
    controller.dispose();
  });
}
