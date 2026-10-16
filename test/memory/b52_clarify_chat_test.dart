import 'dart:convert';
import 'dart:io';
import 'package:emie/data/chat/chat_api.dart';
import 'package:emie/data/chat/chat_repository.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import '../product_b2/product_contract_test.dart' show localDio, response;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final recorded = jsonDecode(File('test/fixtures/b52_clarify_response.json').readAsStringSync()) as Map<String, dynamic>;
  void expectUsable(String text) {
    expect(text, contains('Welche Variante passt?'));
    expect(text, contains('1. Gilt generell'));
    expect(text, contains('2. Bleib beim alten Wert'));
    expect(text, contains('Antworte einfach mit der Zahl'));
    expect(text, isNot(contains('ID: CLARIFY:')));
  }
  test('B52 real captured clarification keeps visible choices through ChatApi and controller', () async {
    var submits = 0;
    final dio = localDio((r) {
      if (r.method == 'POST') { submits++; expect(r.path, '/v1/chat/respond'); return response(recorded); }
      return response(<Object>[]);
    });
    final chat = ChatController(repository: ChatRepository(api: ChatApi(dio: dio)));
    addTearDown(chat.dispose); addTearDown(dio.close);
    await chat.send('Merke: Mein Hobby ist das Zeichnen von fiktiven Sternkarten.');
    expect(chat.lastSendConfirmed, isTrue); expect(submits, 1);
    expectUsable(chat.messages.last.text);
  });
  test('B52 reopened clarification keeps choices, hides internal marker, preserves user text', () async {
    const user = 'Fiktive Notiz ID: CLARIFY:user-text';
    final dio = localDio((r) => response({'id':'stored','messages':[
      {'id':'1','role':'user','content':user,'created_at':'2026-10-14T18:00:00Z'},
      {'id':'2','role':'assistant','content':recorded['reply'],'created_at':'2026-10-14T18:00:01Z'},
    ]}));
    final chat = ChatController(repository: ChatRepository(api: ChatApi(dio: dio)));
    addTearDown(chat.dispose); addTearDown(dio.close);
    await chat.openChat('stored');expect(chat.error,isNull);
    expect(chat.messages.first.text,user);expectUsable(chat.messages.last.text);
  });
  final followups = jsonDecode(File('test/fixtures/b52_clarify_followups.json').readAsStringSync()) as List<dynamic>;
  for (final raw in followups) {
    final fixture = raw as Map<String, dynamic>;
    test('B52 ${fixture['kind']} stays visible after send and reopen', () async {
      var submits = 0;
      final body = fixture['response'] as Map<String, dynamic>;
      final dio = localDio((r) {
        if (r.method == 'POST') { submits++; return response(body); }
        return response({'id':'stored','messages':[
          {'id':'1','role':'assistant','content':body['reply'],'created_at':'2026-10-14T21:00:00Z'},
        ]});
      });
      final chat = ChatController(repository: ChatRepository(api: ChatApi(dio: dio)));
      addTearDown(chat.dispose); addTearDown(dio.close);
      await chat.send('synthetische Dialogauswahl');
      expect(submits, 1); expect(chat.lastSendConfirmed, isTrue);
      expect(chat.messages.last.text, contains(fixture['expected'] as String));
      expect(chat.messages.last.text, isNot(contains('ID: CLARIFY:')));
      await chat.openChat('stored');
      expect(chat.error, isNull);
      expect(chat.messages.last.text, contains(fixture['expected'] as String));
      expect(chat.messages.last.text, isNot(contains('ID: CLARIFY:')));
      expect(submits, 1);
    });
  }
}
