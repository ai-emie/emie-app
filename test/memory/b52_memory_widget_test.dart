import 'dart:async';
import 'package:dio/dio.dart';
import 'package:emie/core/storage/secure_storage.dart';
import 'package:emie/data/memory/api/memory_api.dart';
import 'package:emie/data/memory/models/memory_item.dart';
import 'package:emie/features/memory/presentation/screens/memory_editor.dart';
import 'package:emie/features/memory/presentation/screens/memory_screen.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import '../product_b2/product_contract_test.dart' show localDio, response, login;
import '../product_b2/product_widgets_test.dart' show host;

// Local widget countercases, distinct from real PostgreSQL/native acceptance.
Map<String, dynamic> row(String id, String content) => {
      'id': id, 'content': content, 'value': content,
      'category': 'facts', 'importance': 5, 'created_at': '2026-10-14T00:00:00Z'
    };
Map<String, dynamic> page(List<Map<String, dynamic>> rows) => {
      'items': rows, 'total_items': rows.length, 'offset': 0, 'limit': 20
    };

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SecureStorageService.useStorageForTesting(const FlutterSecureStorage());
    login('b52-widget-a');
    await SessionStore.instance.setLanguage('de');
  });
  Future<void> tap(WidgetTester t, Finder f) async {
    await t.pump(); await t.ensureVisible(f); await t.tap(f); await t.pumpAndSettle();
  }
  testWidgets('B52 edit response loss blocks replay and reloads committed content', (t) async {
    var stored = row('own', 'Vorher'); var writes = 0;
    final dio = localDio((r) {
      if (r.method == 'PATCH') {
        writes++; stored = row('own', r.data['value']);
        throw DioException(requestOptions: r, type: DioExceptionType.receiveTimeout);
      }
      return response(page([stored]));
    });
    addTearDown(dio.close);
    await t.pumpWidget(host(MemoryEditor(item: MemoryItem.fromJson(stored), api: MemoryApi(dio: dio))));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('memory-content')), 'Nach Commit');
    await tap(t, find.text('Speichern'));
    expect(find.textContaining('Änderung nicht bestätigt.'), findsOneWidget);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Speichern')).onPressed, isNull);
    expect(writes, 1);
    await tap(t, find.byTooltip('Neu laden'));
    await tap(t, find.text('Bestätigen'));
    expect(find.text('Nach Commit'), findsOneWidget);
    expect(find.textContaining('Änderung nicht bestätigt.'), findsNothing);
    expect(writes, 1);
  });
  testWidgets('B52 late A memory page cannot replace nonempty B memory list', (t) async {
    final pending = Completer<ResponseBody>();
    final dio = localDio((r) {
      if (SessionStore.instance.user!.id == 'b52-widget-a') return pending.future;
      return response(page([row('b', 'Nur B sichtbar')]));
    });
    addTearDown(dio.close);
    await t.pumpWidget(host(MemoryScreen(api: MemoryApi(dio: dio))));
    await t.pump();
    login('b52-widget-b');
    await t.pumpAndSettle();
    expect(find.text('Nur B sichtbar'), findsOneWidget);
    pending.complete(response(page([row('a', 'Verspätetes A Geheimnis')])));
    await t.pumpAndSettle();
    expect(find.text('Nur B sichtbar'), findsOneWidget);
    expect(find.text('Verspätetes A Geheimnis'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('B52 late A editor response cannot announce success in B', (t) async {
    final pending = Completer<ResponseBody>();
    final dio = localDio((r) => pending.future); addTearDown(dio.close);
    await t.pumpWidget(host(MemoryEditor(item: MemoryItem.fromJson(row('a', 'A vorher')), api: MemoryApi(dio: dio))));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('memory-content')), 'A später');
    await t.ensureVisible(find.text('Speichern')); await t.tap(find.text('Speichern')); await t.pump();
    login('b52-widget-b');
    await t.pumpWidget(host(const Scaffold(body: Text('B Bereich mit eigenem Inhalt'))));
    pending.complete(response(row('a', 'A später'))); await t.pumpAndSettle();
    expect(find.text('B Bereich mit eigenem Inhalt'), findsOneWidget);
    expect(find.text('A später'), findsNothing);
    expect(find.text('Erinnerung gespeichert.'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('B52 failed memory load is not presented as an empty collection', (t) async {
    final dio = localDio((r) => throw DioException(requestOptions: r, type: DioExceptionType.receiveTimeout));
    addTearDown(dio.close);
    await t.pumpWidget(host(MemoryScreen(api: MemoryApi(dio: dio))));
    await t.pumpAndSettle();
    expect(find.text('Laden fehlgeschlagen. Angezeigte Daten können veraltet sein.'), findsOneWidget);
    expect(find.text('Keine passenden Erinnerungen vorhanden.'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
