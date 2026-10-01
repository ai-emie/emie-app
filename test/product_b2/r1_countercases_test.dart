import 'dart:async';
import 'dart:convert';
import 'package:emie/app.dart';
import 'package:emie/core/storage/secure_storage.dart';
import 'package:emie/core/localization/app_localizations.dart';
import 'package:emie/data/chat/chat_api.dart';
import 'package:emie/data/chat/chat_repository.dart';
import 'package:emie/data/chat/chat_session_models.dart';
import 'package:emie/data/home/api/home_api.dart';
import 'package:emie/data/memory/api/memory_api.dart';
import 'package:emie/data/projects/project_api.dart';
import 'package:emie/features/auth/controller/auth_controller.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import 'package:emie/features/chat/presentation/screens/chat_screen.dart';
import 'package:emie/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:emie/features/home/presentation/screens/home_overview.dart';
import 'package:emie/features/memory/presentation/screens/memory_screen.dart';
import 'package:emie/features/projects/presentation/screens/project_editor.dart';
import 'package:emie/state/paged_list.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../auth/account_deletion_session_test.dart' show Kl5Harness;
import 'product_contract_test.dart' show fixture, localDio, response;
import 'product_widgets_test.dart' show host, ProjectFake;
import 'chat_feedback_test.dart' show FeedbackRepository;

class HistoryFailureAfterReply extends FeedbackRepository {
  @override
  Future<List<ChatSession>> listSessions() async =>
      throw StateError('synthetic history unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Kl5Harness h;
  setUp(() async {
    h = Kl5Harness();
    await h.session.loadPreferences();
  });
  tearDown(() => h.dispose());

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EmieApp());
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    final auth =
        tester.element(find.byType(MaterialApp)).read<AuthController>();
    expect(
        await tester.runAsync(() =>
            auth.loginWithEmail('a@example.invalid', 'synthetic-password')),
        true);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.pump();
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'R1 home refreshes after creating a project through the real main navigation',
      (tester) async {
    final project = Map<String, dynamic>.from(fixture()['project_created']);
    var created = false;
    var summaries = 0;
    h.onMain = (request) async {
      if (request.path == '/v1/home/summary') {
        summaries++;
        return response({
          'user_stats': {
            'total_projects': created ? 1 : 0,
            'total_memories': 0,
            'memories_today': 0
          },
          'recent_project': created ? project : null,
          'recent_memory': null,
          'generated_at': DateTime.now().toUtc().toIso8601String()
        });
      }
      if (request.path == '/v1/projects') {
        if (request.method == 'POST') {
          project.addAll(Map<String, dynamic>.from(request.data));
          created = true;
          return response(project, 201);
        }
        return response({
          'items': created ? [project] : [],
          'total_items': created ? 1 : 0,
          'offset': 0,
          'limit': 20
        });
      }
      return h.defaultResponse(request);
    };
    await mount(tester);
    expect(summaries, 1);
    await tap(tester, find.byIcon(Icons.folder_outlined).last);
    await tap(tester, find.byKey(const ValueKey('create-project')));
    await tester.enterText(
        find.byKey(const ValueKey('project-name')), 'R1 from projects tab');
    await tap(tester, find.byKey(const ValueKey('save-project')));
    expect(created, true);
    await tap(tester, find.byType(BackButton));
    await tap(tester, find.byIcon(Icons.grid_view_rounded));
    expect(summaries, 2,
        reason:
            'Returning Home must not present the pre-save summary as current');
    expect(
        find.descendant(
            of: find.byType(HomeOverview),
            matching: find.text('R1 from projects tab')),
        findsOneWidget);
    expect(find.text('1 Projekte · 0 Erinnerungen'), findsOneWidget);
  });

  test(
      'R1 malformed chat detail cannot erase the current conversation as a successful empty open',
      () async {
    var broken = false;
    final dio = localDio((r) => response(broken
        ? <String, dynamic>{}
        : {
            'id': 'stored',
            'title': 'Stored',
            'messages': [
              {
                'id': 'm',
                'role': 'user',
                'content': 'Kept',
                'created_at': '2026-10-01T00:00:00Z'
              }
            ]
          }));
    addTearDown(dio.close);
    final chat =
        ChatController(repository: ChatRepository(api: ChatApi(dio: dio)));
    addTearDown(chat.dispose);
    await chat.openChat('stored');
    expect(chat.messages.single.text, 'Kept');
    broken = true;
    await chat.openChat('broken');
    expect(chat.error, 'chat_open_failed');
    expect(chat.chatSessionId, 'stored');
    expect(chat.messages.single.text, 'Kept');
  });

  for (final kind in ['project', 'memory']) {
    testWidgets(
        'R1 $kind list refreshes a Home edit when its main tab becomes active',
        (tester) async {
      final f = fixture();
      final project = Map<String, dynamic>.from(f['project_created']);
      final memory = Map<String, dynamic>.from(f['home']['recent_memory']);
      var lists = 0;
      h.onMain = (request) async {
        if (request.path == '/v1/home/summary') {
          return response({
            ...f['home'],
            'recent_project': project,
            'recent_memory': memory,
            'generated_at': DateTime.now().toUtc().toIso8601String()
          });
        }
        if (request.path == '/v1/projects/${project['id']}') {
          if (request.method == 'PUT') {
            project.addAll(Map<String, dynamic>.from(request.data));
          }
          return response(project);
        }
        if (request.path == '/v1/memory/${memory['id']}') {
          memory['value'] = memory['content'] = request.data['value'];
          return response(memory);
        }
        if (request.path == '/v1/projects') {
          if (kind == 'project') lists++;
          return response({
            'items': [project],
            'total_items': 1,
            'offset': 0,
            'limit': 20
          });
        }
        if (request.path == '/v1/memory/list') {
          if (kind == 'memory') lists++;
          return response({
            'items': [memory],
            'total_items': 1,
            'offset': 0,
            'limit': 20
          });
        }
        return h.defaultResponse(request);
      };
      await mount(tester);
      expect(lists, 1);
      await tap(
          tester,
          find.descendant(
              of: find.byType(HomeOverview),
              matching: find.byIcon(kind == 'project'
                  ? Icons.folder_outlined
                  : Icons.psychology_outlined)));
      await tester.enterText(
          find.byKey(
              ValueKey(kind == 'project' ? 'project-name' : 'memory-content')),
          'R1 home edit');
      await tap(tester, find.widgetWithText(FilledButton, 'Speichern'));
      await tap(tester, find.byType(BackButton));
      await tap(
          tester,
          find
              .byIcon(kind == 'project'
                  ? Icons.folder_outlined
                  : Icons.psychology_alt_outlined)
              .last);
      expect(lists, 2,
          reason:
              'The previously mounted list must reconcile edits from another area');
      expect(find.text('R1 home edit'), findsOneWidget);
    });
  }

  for (final body in [
    <String, dynamic>{},
    {
      'items': ['invalid']
    }
  ]) {
    test('R1 malformed chat history $body is an error, not empty history',
        () async {
      final dio = localDio((r) => response(body));
      addTearDown(dio.close);
      await expectLater(
          ChatApi(dio: dio).listSessions(), throwsFormatException);
    });
  }

  test(
      'R1 memory reconciliation must reject an incomplete page instead of asserting deletion',
      () async {
    await h.login('A');
    final dio = localDio((r) =>
        response({'items': [], 'total_items': 45, 'offset': 0, 'limit': 20}));
    addTearDown(dio.close);
    await expectLater(
        MemoryApi(dio: dio).getById('unconfirmed-write', h.session.generation),
        throwsFormatException);
  });

  test('R1 deduplication advances by server rows and retries exact offset',
      () async {
    await h.login('A');
    final offsets = <int>[];
    var fail = true;
    final list = PagedList<int>(
        id: (v) => '$v',
        fetch: (offset, generation) async {
          offsets.add(offset);
          if (offset == 0) return const ListPage([1, 2, 2], 7, 0, 3);
          if (offset == 3 && fail) throw StateError('synthetic');
          if (offset == 3) return const ListPage([2, 3, 4], 7, 3, 3);
          return const ListPage([5], 7, 6, 3);
        });
    addTearDown(list.dispose);
    await list.refresh(through: 3);
    expect(list.items, [1, 2]);
    await list.more();
    expect(list.failed, true);
    fail = false;
    await list.retry();
    await list.more();
    expect(list.items, [1, 2, 3, 4, 5]);
    expect(offsets, [0, 3, 3, 6]);
    expect(list.hasMore, false);
  });

  test(
      'R1 actual backend chat list, empty list and detail share the Flutter contract',
      () async {
    final f = fixture();
    var empty = false;
    final dio = localDio((r) => response(r.path == '/v1/chat/sessions'
        ? (empty ? f['chat_empty_list'] : f['chat_list'])
        : f['chat_detail']));
    addTearDown(dio.close);
    final api = ChatApi(dio: dio);
    final sessions = await api.listSessions();
    expect(sessions.single.id, f['chat_detail']['id']);
    final messages = await api.getSessionMessages(sessions.single.id);
    expect(messages.single.text, f['chat_detail']['messages'][0]['content']);
    empty = true;
    expect(await api.listSessions(), isEmpty);
  });

  test(
      'R1 valid three-page reconciliation finds a late record and distinguishes true absence',
      () async {
    await h.login('A');
    final pages = fixture()['memory_pages'] as List;
    final offsets = <int>[];
    final dio = localDio((r) {
      final offset = r.queryParameters['offset'] as int;
      offsets.add(offset);
      return response(pages[offset ~/ 20]);
    });
    addTearDown(dio.close);
    final api = MemoryApi(dio: dio);
    final last = (pages.last['items'] as List).last;
    expect((await api.getById(last['id'], h.session.generation))!.content,
        last['content']);
    expect(offsets, [0, 20, 40]);
    expect(await api.getById('absent', h.session.generation), isNull);
    expect(offsets, [0, 20, 40, 0, 20, 40]);
  });

  testWidgets(
      'R1 project name uses backend Unicode codepoint limits, not grapheme count',
      (tester) async {
    final api = ProjectFake(Project.fromJson(fixture()['project_created']));
    await tester.pumpWidget(host(ProjectEditor(api: api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('project-name')),
        List.filled(18, '👩‍👩‍👧‍👦').join());
    await tap(tester, find.byKey(const ValueKey('save-project')));
    expect(api.writes, 0);
    expect(find.text('Bitte Text kürzen.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('project-name')),
        List.filled(120, '🙂').join());
    await tap(tester, find.byKey(const ValueKey('save-project')));
    expect(api.writes, 1);
    expect(api.row.name.runes.length, 120);
  });

  for (final language in ['de', 'en']) {
    for (final theme in [EmieThemeMode.dark, EmieThemeMode.light]) {
      testWidgets(
          'R1 history failure after confirmed send stays distinct in $language $theme',
          (tester) async {
        await h.session.setLanguage(language);
        await h.session.setThemeMode(theme);
        final chat = ChatController(repository: HistoryFailureAfterReply());
        addTearDown(chat.dispose);
        await tester.pumpWidget(host(Builder(
            builder: (context) => Localizations.override(
                context: context,
                delegates: const [AppLocalizations.delegate],
                child: ChangeNotifierProvider.value(
                    value: chat, child: const ChatScreen())))));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Synthetic message');
        tester.widget<ChatInputBar>(find.byType(ChatInputBar)).onSend();
        await tester.pumpAndSettle();
        expect(chat.lastSendConfirmed, true);
        expect(chat.error, 'history_load_failed');
        expect(
            find.text(language == 'de'
                ? 'Nachrichten gespeichert.'
                : 'Messages saved.'),
            findsOneWidget);
        expect(
            find.text(language == 'de'
                ? 'Historie nicht aktuell. Bitte neu laden.'
                : 'History is not up to date. Please reload.'),
            findsOneWidget);
        expect(
            find.textContaining(language == 'de'
                ? 'Ausgang nicht bestätigt'
                : 'Outcome unconfirmed'),
            findsNothing);
        expect(Theme.of(tester.element(find.byType(ChatScreen))).brightness,
            theme == EmieThemeMode.dark ? Brightness.dark : Brightness.light);
      });
    }
  }

  test(
      'R1 pending device preference write and account cleanup cannot cross token keys',
      () async {
    await h.login('A');
    final entered = Completer<void>(), release = Completer<void>();
    h.storage.before = (operation, key, value) async {
      if (operation == 'write' && key == 'emie_device_preferences_v1') {
        entered.complete();
        await release.future;
      }
    };
    final preference = h.session.setLanguage('en');
    await entered.future;
    final cleanup = SecureStorageService.clearTokens();
    final next = SecureStorageService.saveTokens(
        accessToken: 'synthetic-B', refreshToken: 'synthetic-refresh-B');
    release.complete();
    await preference;
    await cleanup;
    await next;
    expect(h.storage.values['emie_access_token'], 'synthetic-B');
    expect(h.storage.values['emie_refresh_token'], 'synthetic-refresh-B');
    final settings =
        jsonDecode((await SecureStorageService.readPreferences())!);
    expect(settings, {'theme': 'dark', 'language': 'en'});
    expect(h.storage.events.where((e) => e.startsWith('delete:preferences')),
        isEmpty);
    h.session.clear();
    expect(h.session.language, 'en');
  });

  testWidgets(
      'R1 newer Home refresh wins even when the first response arrives last',
      (tester) async {
    final requests = <Completer<dynamic>>[];
    final dio = localDio((r) async {
      final pending = Completer<dynamic>();
      requests.add(pending);
      return response(await pending.future);
    });
    addTearDown(dio.close);
    await tester
        .pumpWidget(host(Scaffold(body: HomeOverview(api: HomeApi(dio: dio)))));
    for (var frame = 0; frame < 20 && requests.isEmpty; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(requests.length, 1);
    await tester.tap(find.byTooltip('Aktualisieren'));
    for (var frame = 0; frame < 20 && requests.length < 2; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(requests.length, 2);
    final fresh = {
      ...fixture()['home'],
      'recent_project': null,
      'recent_memory': null,
      'user_stats': {
        'total_projects': 7,
        'total_memories': 0,
        'memories_today': 0
      },
      'generated_at': DateTime.now().toUtc().toIso8601String()
    };
    requests[1].complete(fresh);
    await tester.pumpAndSettle();
    expect(find.text('7 Projekte · 0 Erinnerungen'), findsOneWidget);
    requests[0].complete(fixture()['home']);
    await tester.pumpAndSettle();
    expect(find.text('7 Projekte · 0 Erinnerungen'), findsOneWidget);
    expect(find.text('Updated'), findsNothing);
  });

  testWidgets(
      'R1 memory UI traverses all three pages and edits and deletes the last record',
      (tester) async {
    final rows = (fixture()['memory_pages'] as List)
        .expand((p) => p['items'] as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final id = rows.last['id'];
    final offsets = <int>[];
    final dio = localDio((r) {
      if (r.method == 'GET') {
        final offset = r.queryParameters['offset'] as int;
        offsets.add(offset);
        return response({
          'items': rows.skip(offset).take(20).toList(),
          'total_items': rows.length,
          'offset': offset,
          'limit': 20
        });
      }
      expect(r.path, '/v1/memory/$id');
      if (r.method == 'DELETE') {
        rows.removeWhere((row) => row['id'] == id);
        return response({'deleted': id});
      }
      rows.last['content'] = rows.last['value'] = r.data['value'];
      return response(rows.last);
    });
    addTearDown(dio.close);
    await tester.pumpWidget(host(MemoryScreen(api: MemoryApi(dio: dio))));
    await tester.pumpAndSettle();
    for (var page = 0; page < 2; page++) {
      await tester.scrollUntilVisible(find.text('Weitere laden'), 400,
          scrollable: find.byType(Scrollable).last);
      await tap(tester, find.text('Weitere laden'));
    }
    expect(find.text('48 von 48 geladen'), findsOneWidget);
    expect(offsets, [0, 20, 40]);
    await tester.scrollUntilVisible(find.byKey(ValueKey('memory-$id')), 400,
        scrollable: find.byType(Scrollable).last);
    await tap(tester, find.byKey(ValueKey('memory-$id')));
    await tester.enterText(
        find.byKey(const ValueKey('memory-content')), 'Last page changed');
    await tap(tester, find.text('Speichern'));
    await tap(tester, find.byType(BackButton));
    expect(offsets.sublist(offsets.length - 3), [0, 20, 40]);
    await tester.scrollUntilVisible(find.byKey(ValueKey('memory-$id')), 400,
        scrollable: find.byType(Scrollable).last);
    await tap(tester, find.byKey(ValueKey('memory-$id')));
    expect(find.text('Last page changed'), findsOneWidget);
    await tap(tester, find.text('Löschen'));
    await tap(tester, find.text('Bestätigen'));
    expect(find.text('47 von 47 geladen'), findsOneWidget);
    expect(rows.any((row) => row['id'] == id), false);
    expect(offsets.sublist(offsets.length - 3), [0, 20, 40]);
  });
}
