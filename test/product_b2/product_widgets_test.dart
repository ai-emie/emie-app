import 'dart:async';
import 'package:emie/api/client.dart';
import 'package:emie/core/storage/secure_storage.dart';
import 'package:emie/data/home/api/home_api.dart';
import 'package:emie/data/memory/api/memory_api.dart';
import 'package:emie/data/memory/models/memory_item.dart';
import 'package:emie/data/profile/profile_api.dart';
import 'package:emie/data/projects/project_api.dart';
import 'package:emie/features/home/presentation/screens/home_overview.dart';
import 'package:emie/features/memory/presentation/screens/memory_editor.dart';
import 'package:emie/features/memory/presentation/screens/memory_screen.dart';
import 'package:emie/features/plus/presentation/screens/emie_plus_screen.dart';
import 'package:emie/features/profile/presentation/screens/profile_editor.dart';
import 'package:emie/features/projects/presentation/screens/project_editor.dart';
import 'package:emie/features/projects/presentation/screens/project_screen.dart';
import 'package:emie/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:emie/state/paged_list.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'product_contract_test.dart'
    show fixture, localDio, response, FixtureTransport, login;

Widget host(Widget child) => ChangeNotifierProvider.value(
    value: SessionStore.instance,
    child: Consumer<SessionStore>(
        builder: (context, session, _) => MaterialApp(
              key: ValueKey(session.generation),
              locale: session.locale,
              supportedLocales: const [Locale('de'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate
              ],
              theme: ThemeData(brightness: Brightness.light),
              darkTheme: ThemeData(brightness: Brightness.dark),
              themeMode: session.flutterThemeMode,
              home: child,
            )));

class ProjectFake extends ProjectApi {
  ProjectFake(this.row);
  Project row;
  int writes = 0, deletes = 0;
  bool fail = false;
  Completer<Project>? pending;
  @override
  Future<ListPage<Project>> list(int offset, int generation) async =>
      ListPage(deletes > 0 ? [] : [row], deletes > 0 ? 0 : 1, offset, 20);
  @override
  Future<Project> get(String id, int generation) async {
    if (fail) throw StateError('SENSITIVE_MARKER');
    return row;
  }

  @override
  Future<Project> save(
      {String? id,
      required String name,
      required String description,
      required String content,
      required int generation}) async {
    writes++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('SENSITIVE_MARKER');
    row = Project(
        id: row.id,
        name: name,
        description: description,
        content: content,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt);
    return row;
  }

  @override
  Future<void> delete(String id, int generation) async {
    if (fail) throw StateError('SENSITIVE_MARKER');
    deletes++;
  }
}

class MemoryFake extends MemoryApi {
  MemoryFake(this.rows);
  List<MemoryItem> rows;
  int writes = 0, deletes = 0;
  @override
  Future<ListPage<MemoryItem>> fetchPage(
      {int offset = 0,
      String? category,
      String? search,
      int? generation}) async {
    final selected = rows
        .where((r) =>
            (category == null || category == 'all' || category == r.category) &&
            (search == null || r.content.contains(search)))
        .toList();
    return ListPage(
        selected.skip(offset).take(20).toList(), selected.length, offset, 20);
  }

  @override
  Future<MemoryItem?> getById(String id, int generation) async =>
      rows.where((r) => r.id == id).firstOrNull;
  @override
  Future<MemoryItem> updateMemory(
      {required String id,
      String? content,
      int? importance,
      int? generation}) async {
    writes++;
    final i = rows.indexWhere((r) => r.id == id),
        old = rows.firstWhere((r) => r.id == id);
    return rows[i] = MemoryItem(
        id: id,
        content: content!,
        category: old.category,
        importance: old.importance,
        createdAt: old.createdAt);
  }

  @override
  Future<void> deleteMemory(String id, {int? generation}) async {
    deletes++;
    rows.removeWhere((r) => r.id == id);
  }
}

class ProfileFake extends ProfileApi {
  ProfileFake(this.row);
  EditableProfile row;
  bool fail = false;
  int writes = 0;
  Completer<EditableProfile>? pending;
  @override
  Future<EditableProfile> get(int generation) async => row;
  @override
  Future<EditableProfile> save(
      {required String username,
      required String bio,
      required String dailyGoal,
      required int generation}) async {
    writes++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('SENSITIVE_MARKER');
    return row = EditableProfile(
        id: row.id,
        email: row.email,
        username: username.trim(),
        bio: bio.trim(),
        dailyGoal: dailyGoal.trim());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> f;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SecureStorageService.useStorageForTesting(const FlutterSecureStorage());
    login();
    await SessionStore.instance.setLanguage('de');
    await SessionStore.instance.setThemeMode(EmieThemeMode.dark);
    f = fixture();
  });
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.pump();
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final language in ['de', 'en']) {
    for (final theme in [EmieThemeMode.dark, EmieThemeMode.light]) {
      testWidgets('project explicit save/reload supported in $language $theme',
          (tester) async {
        await SessionStore.instance.setLanguage(language);
        await SessionStore.instance.setThemeMode(theme);
        final api = ProjectFake(Project.fromJson(f['project_created']));
        await tester.pumpWidget(host(ProjectEditor(api: api)));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byKey(const ValueKey('project-name')), 'Work');
        await tester.enterText(
            find.byKey(const ValueKey('project-content')), 'A private note');
        expect(api.writes, 0);
        await tap(tester, find.byKey(const ValueKey('save-project')));
        expect(api.writes, 1);
        expect(api.row.content, 'A private note');
        expect(
            find.text(
                language == 'de' ? 'Projekt gespeichert.' : 'Project saved.'),
            findsOneWidget);
        expect(Theme.of(tester.element(find.byType(ProjectEditor))).brightness,
            theme == EmieThemeMode.dark ? Brightness.dark : Brightness.light);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester
            .pumpWidget(host(ProjectEditor(projectId: api.row.id, api: api)));
        await tester.pumpAndSettle();
        expect(find.text('A private note'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'project list opens real record and deletion requires confirmation',
      (tester) async {
    final api = ProjectFake(Project.fromJson(f['project_created']));
    await tester.pumpWidget(host(ProjectScreen(api: api)));
    await tester.pumpAndSettle();
    await tap(tester, find.text(api.row.name));
    expect(find.byType(ProjectEditor), findsOneWidget);
    await tap(tester, find.text('Projekt löschen'));
    expect(api.deletes, 0);
    await tap(tester, find.text('Bestätigen'));
    expect(api.deletes, 1);
    expect(
        find.text('Noch keine Projekte. Lege dein erstes an.'), findsOneWidget);
  });

  testWidgets('unsaved project warns before back and preserves draft on cancel',
      (tester) async {
    final api = ProjectFake(Project.fromJson(f['project_created']));
    await tester.pumpWidget(host(ProjectScreen(api: api)));
    await tester.pumpAndSettle();
    await tap(tester, find.text(api.row.name));
    await tester.enterText(find.byKey(const ValueKey('project-name')), 'Draft');
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Ungespeicherte Änderungen verwerfen?'), findsOneWidget);
    await tap(tester, find.text('Abbrechen'));
    expect(find.text('Draft'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Bestätigen'));
    expect(find.byType(ProjectEditor), findsNothing);
    expect(api.writes, 0);
  });

  testWidgets(
      'failed project write shows no success and requires reconciliation',
      (tester) async {
    final api = ProjectFake(Project.fromJson(f['project_created']))
      ..fail = true;
    await tester.pumpWidget(host(ProjectEditor(api: api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('project-name')), 'Draft');
    await tester.pump();
    await tap(tester, find.byKey(const ValueKey('save-project')));
    expect(find.textContaining('Ausgang nicht bestätigt'), findsOneWidget);
    expect(find.text('Projekt gespeichert.'), findsNothing);
    expect(find.textContaining('SENSITIVE_MARKER'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-project')))
            .onPressed,
        isNull);
    expect(api.writes, 1);
  });

  testWidgets(
      'memory editor reads edits reloads and deletes an item from page three',
      (tester) async {
    final rows = (f['memory_pages'] as List)
        .expand((p) => p['items'] as List)
        .map((j) => MemoryItem.fromJson(j))
        .toList();
    final api = MemoryFake(rows), item = rows.last;
    await tester.pumpWidget(host(MemoryEditor(item: item, api: api)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('memory-content')), 'Edited late page');
    await tap(tester, find.text('Speichern'));
    expect(api.writes, 1);
    await tap(tester, find.byTooltip('Neu laden'));
    expect(find.text('Edited late page'), findsOneWidget);
    await tap(tester, find.text('Löschen'));
    expect(api.deletes, 0);
    await tap(tester, find.text('Bestätigen'));
    expect(api.deletes, 1);
    expect(api.rows.any((r) => r.id == item.id), false);
  });

  testWidgets(
      'memory UI loads beyond twenty then searches the server-side collection',
      (tester) async {
    final rows = (f['memory_pages'] as List)
        .expand((p) => p['items'] as List)
        .map((j) => MemoryItem.fromJson(j))
        .toList();
    final api = MemoryFake(rows);
    await tester.pumpWidget(host(MemoryScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('20 von 48 geladen'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Weitere laden'), 400,
        scrollable: find.byType(Scrollable).last);
    await tap(tester, find.text('Weitere laden'));
    expect(find.text('40 von 48 geladen'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('memory-search')), 'Notiz 0');
    await tap(tester, find.byTooltip('Suchen'));
    expect(find.text('1 von 1 geladen'), findsOneWidget);
  });

  testWidgets(
      'profile edits only existing allowed fields and reloads confirmed result',
      (tester) async {
    final api = ProfileFake(EditableProfile.fromJson(f['profile']));
    await tester.pumpWidget(host(ProfileEditor(api: api)));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(3));
    await tester.enterText(find.byType(TextFormField).first, 'New Ada');
    await tap(tester, find.text('Speichern'));
    expect(api.writes, 1);
    expect(SessionStore.instance.user!.name, 'New Ada');
    await tap(tester, find.byTooltip('Neu laden'));
    expect(find.text('New Ada'), findsOneWidget);
  });

  testWidgets(
      'profile failed save never claims success or changes the session profile',
      (tester) async {
    final api = ProfileFake(EditableProfile.fromJson(f['profile']))
      ..fail = true;
    await tester.pumpWidget(host(ProfileEditor(api: api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Unsaved');
    await tap(tester, find.text('Speichern'));
    expect(SessionStore.instance.user!.name, 'Ada');
    expect(find.text('Profil gespeichert.'), findsNothing);
    expect(find.textContaining('Speichern nicht bestätigt'), findsOneWidget);
    expect(find.textContaining('SENSITIVE_MARKER'), findsNothing);
  });

  testWidgets('pending A profile save cannot modify B or display success',
      (tester) async {
    final api = ProfileFake(EditableProfile.fromJson(f['profile']))
      ..pending = Completer<EditableProfile>();
    await tester.pumpWidget(host(ProfileEditor(api: api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Late A');
    await tester.ensureVisible(find.text('Speichern'));
    await tester.tap(find.text('Speichern'));
    await tester.pump();
    login('b2-b');
    await tester.pumpWidget(host(const Scaffold(body: Text('B workspace'))));
    api.pending!.complete(api.row);
    await tester.pumpAndSettle();
    expect(SessionStore.instance.user!.id, 'b2-b');
    expect(SessionStore.instance.user!.name, isNull);
    expect(find.text('Profil gespeichert.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'pending A project save cannot populate B detail or display success',
      (tester) async {
    final api = ProjectFake(Project.fromJson(f['project_created']))
      ..pending = Completer<Project>();
    await tester.pumpWidget(host(ProjectEditor(api: api)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('project-name')), 'Private A');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('save-project')));
    await tester.tap(find.byKey(const ValueKey('save-project')));
    await tester.pump();
    login('b2-b');
    await tester.pumpWidget(host(const Scaffold(body: Text('B workspace'))));
    api.pending!.complete(api.row);
    await tester.pumpAndSettle();
    expect(find.text('Private A'), findsNothing);
    expect(find.text('Projekt gespeichert.'), findsNothing);
    expect(find.text('B workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new B2 editors and summary fit a narrow phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final project = ProjectFake(Project.fromJson(f['project_created']));
    final profile = ProfileFake(EditableProfile.fromJson(f['profile']));
    for (final widget in [
      ProjectEditor(api: project),
      ProfileEditor(api: profile),
      const EmiePlusScreen()
    ]) {
      await tester.pumpWidget(host(widget));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
      'home shows real summary, navigates to project and distinguishes empty/error/stale',
      (tester) async {
    var fail = false;
    final dio = localDio((r) => fail
        ? response({'detail': 'SENSITIVE_MARKER'}, 500)
        : response(f['home']));
    ApiClient().dio.httpClientAdapter =
        FixtureTransport((r) => response(f['project_updated']));
    await tester.pumpWidget(host(Scaffold(
        body: SingleChildScrollView(
            child: HomeOverview(api: HomeApi(dio: dio))))));
    await tester.pumpAndSettle();
    expect(find.text('1 Projekte · 48 Erinnerungen'), findsOneWidget);
    await tap(tester, find.text('Updated'));
    expect(find.byType(ProjectEditor), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    fail = true;
    await tap(tester, find.byTooltip('Aktualisieren'));
    expect(
        find.textContaining('Stand möglicherweise veraltet'), findsOneWidget);
    expect(find.text('Updated'), findsOneWidget);
    expect(find.textContaining('SENSITIVE_MARKER'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    dio.close();
    final empty = localDio((r) => response({
          'user_stats': {
            'total_memories': 0,
            'memories_today': 0,
            'total_projects': 0
          },
          'recent_project': null,
          'recent_memory': null,
          'generated_at': DateTime.now().toUtc().toIso8601String()
        }));
    await tester.pumpWidget(
        host(Scaffold(body: HomeOverview(api: HomeApi(dio: empty)))));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Projekte gespeichert.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    empty.close();
  });

  testWidgets('late A home response is ignored after direct account switch',
      (tester) async {
    final pending = Completer<dynamic>();
    final dio = localDio((r) async => response(await pending.future));
    await tester
        .pumpWidget(host(Scaffold(body: HomeOverview(api: HomeApi(dio: dio)))));
    await tester.pump();
    login('b2-b');
    await tester.pumpWidget(host(const Scaffold(body: Text('B workspace'))));
    pending.complete(f['home']);
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsNothing);
    expect(find.text('B workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
    dio.close();
  });

  testWidgets(
      'Plus and attachments are visibly unavailable in English light theme',
      (tester) async {
    await SessionStore.instance.setLanguage('en');
    await SessionStore.instance.setThemeMode(EmieThemeMode.light);
    await tester.pumpWidget(host(const EmiePlusScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Plus and billing are not available in this beta yet.'),
        findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    final text = TextEditingController();
    await tester.pumpWidget(host(Scaffold(
        body: ChatInputBar(
            controller: text,
            onSend: () {},
            onSnack: (_) {},
            surface: Colors.white,
            border: Colors.grey,
            textPrimary: Colors.black,
            textSecondary: Colors.grey,
            bg: Colors.white,
            hintText: 'Message',
            attachHintText: 'Attachments are not available yet.'))));
    final button = find.byTooltip('Attachments are not available yet.');
    expect(
        tester
            .widget<IconButton>(
                find.ancestor(of: button, matching: find.byType(IconButton)))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    text.dispose();
  });
}
