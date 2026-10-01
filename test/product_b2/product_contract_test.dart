import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:emie/api/client.dart';
import 'package:emie/core/storage/secure_storage.dart';
import 'package:emie/data/auth/auth_models.dart';
import 'package:emie/data/chat/chat_api.dart';
import 'package:emie/data/home/api/home_api.dart';
import 'package:emie/data/memory/api/memory_api.dart';
import 'package:emie/data/memory/models/memory_item.dart';
import 'package:emie/data/profile/profile_api.dart';
import 'package:emie/data/projects/project_api.dart';
import 'package:emie/state/paged_list.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Map<String, dynamic> fixture() => jsonDecode(
    File('test/fixtures/product_b2_responses.json').readAsStringSync());

class FixtureTransport implements HttpClientAdapter {
  FixtureTransport(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
          Future<void>? cancelFuture) async =>
      respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(Object body, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Dio localDio(FutureOr<ResponseBody> Function(RequestOptions) respond) =>
    Dio(BaseOptions(baseUrl: 'https://synthetic.example.invalid'))
      ..httpClientAdapter = FixtureTransport(respond);
void login([String id = 'b2-a']) {
  final session = SessionStore.instance;
  final origin = session.beginSession();
  session.updateTokens('synthetic-$id', generation: origin);
  session.updateUser(UserProfile(id: id, email: '$id@example.com'),
      generation: origin);
}

class FailingPreferencesStorage extends FlutterSecureStorage {
  @override
  Future<void> write(
          {required String key,
          required String? value,
          IOSOptions? iOptions,
          AndroidOptions? aOptions,
          LinuxOptions? lOptions,
          WebOptions? webOptions,
          MacOsOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      throw StateError('synthetic storage failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> f;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SecureStorageService.useStorageForTesting(const FlutterSecureStorage());
    login();
    await SessionStore.instance.setLanguage('de');
    f = fixture();
  });

  test(
      'backend generated project create/list/read/update/delete contract and no write replay',
      () async {
    final commands = <String>[];
    final dio = localDio((r) {
      commands.add(r.method);
      if (r.method != 'GET') expect(r.extra[ApiClient.noRefreshKey], true);
      expect(r.extra[ApiClient.sessionKey], SessionStore.instance.generation);
      if (r.method == 'POST' || r.method == 'PUT') {
        expect(
            (r.data as Map).keys.toSet(), {'name', 'description', 'content'});
      }
      return response(switch (r.method) {
        'POST' => f['project_created'],
        'PUT' => f['project_updated'],
        'DELETE' => f['project_deleted'],
        _ =>
          r.path == '/v1/projects' ? f['project_list'] : f['project_updated'],
      });
    });
    final api = ProjectApi(dio: dio),
        generation = SessionStore.instance.generation;
    final created = await api.save(
        name: 'Reise 🙂',
        description: 'D',
        content: 'C',
        generation: generation);
    expect(created.content, 'Klartext\n東京 🙂');
    final updated = await api.save(
        id: created.id,
        name: 'Updated',
        description: 'D',
        content: 'Gespeichert\n🙂',
        generation: generation);
    expect((await api.get(created.id, generation)).content, updated.content);
    expect((await api.list(0, generation)).items.single.id, created.id);
    await api.delete(created.id, generation);
    expect(commands, ['POST', 'PUT', 'GET', 'GET', 'DELETE']);
    dio.close();
  });

  test(
      'backend home and profile fixtures use actual identifiers and strict field allowlist',
      () async {
    final requests = <RequestOptions>[];
    final dio = localDio((r) {
      requests.add(r);
      return response(r.path.contains('home') ? f['home'] : f['profile']);
    });
    final summary = await HomeApi(dio: dio).fetchSummary();
    expect(summary.recentProject!.id, f['project_updated']['id']);
    expect(summary.totalProjects, 1);
    expect(summary.totalMemories, 48);
    expect(summary.recentMemory!.id, isNotEmpty);
    final api = ProfileApi(dio: dio),
        generation = SessionStore.instance.generation;
    final saved = await api.save(
        username: 'Ada', bio: 'Bio', dailyGoal: 'Goal', generation: generation);
    expect((await api.get(generation)).username, saved.username);
    expect(requests[1].data,
        {'username': 'Ada', 'bio': 'Bio', 'daily_goal': 'Goal'});
    expect(requests[1].extra[ApiClient.noRefreshKey], true);
    dio.close();
  });

  test(
      'memory backend fixture across more than two pages has no missing or duplicate rows',
      () async {
    final offsets = <int>[];
    final dio = localDio((r) {
      final offset = r.queryParameters['offset'] as int;
      offsets.add(offset);
      expect(r.queryParameters['limit'], 20);
      return response(f['memory_pages'][offset ~/ 20]);
    });
    final api = MemoryApi(dio: dio);
    final list = PagedList<MemoryItem>(
        fetch: (offset, generation) =>
            api.fetchPage(offset: offset, generation: generation),
        id: (m) => m.id);
    addTearDown(list.dispose);
    await list.refresh();
    await list.more();
    await list.more();
    await list.more();
    expect(offsets, [0, 20, 40]);
    expect(list.items.length, 48);
    expect(list.items.map((m) => m.id).toSet().length, 48);
    expect(list.hasMore, false);
    dio.close();
  });

  test(
      'page failure retries same offset; failed refresh retries replacement instead of skipping',
      () async {
    var fail = false;
    final offsets = <int>[];
    final list = PagedList<int>(
        id: (x) => '$x',
        fetch: (offset, generation) async {
          offsets.add(offset);
          if (fail) throw StateError('synthetic');
          return ListPage(
              List.generate(offset == 40 ? 5 : 20, (i) => offset + i),
              45,
              offset,
              20);
        });
    addTearDown(list.dispose);
    await list.refresh();
    fail = true;
    await list.more();
    expect(list.items.length, 20);
    expect(list.failed, true);
    fail = false;
    await list.retry();
    expect(list.items.length, 40);
    fail = true;
    await list.refresh();
    fail = false;
    await list.retry();
    expect(list.items.length, 20);
    expect(offsets, [0, 20, 20, 0, 0]);
  });

  test(
      'refresh and filter revisions reject late pages, then account switch clears synchronously',
      () async {
    final pending = <Completer<ListPage<int>>>[];
    final list = PagedList<int>(
        id: (x) => '$x',
        fetch: (offset, generation) {
          final value = Completer<ListPage<int>>();
          pending.add(value);
          return value.future;
        });
    addTearDown(list.dispose);
    final old = list.refresh();
    final fresh = list.refresh(clear: true);
    pending[1].complete(const ListPage([2], 1, 0, 20));
    await fresh;
    pending[0].complete(const ListPage([1], 1, 0, 20));
    await old;
    expect(list.items, [2]);
    final late = list.refresh();
    login('b2-b');
    expect(list.items, isEmpty);
    pending[2].complete(const ListPage([3], 1, 0, 20));
    await late;
    expect(list.items, isEmpty);
    expect(list.loading, false);
  });

  test(
      'memory filter/search are sent server-side and writes on later IDs use canonical value',
      () async {
    final dio = localDio((r) {
      if (r.method == 'GET') {
        expect(r.queryParameters, {
          'limit': 20,
          'offset': 40,
          'category': 'facts',
          'search_query': 'needle'
        });
        return response(f['memory_pages'][2]);
      }
      expect(r.path, '/v1/memory/b2-memory-000');
      expect(r.extra[ApiClient.noRefreshKey], true);
      if (r.method == 'DELETE') return response({'deleted': 'b2-memory-000'});
      expect(r.data, {'value': 'Edited'});
      return response({
        ...f['memory_pages'][2]['items'].last,
        'content': 'Edited',
        'value': 'Edited'
      });
    });
    final api = MemoryApi(dio: dio);
    await api.fetchPage(offset: 40, category: 'facts', search: ' needle ');
    expect(
        (await api.updateMemory(id: 'b2-memory-000', content: 'Edited'))
            .content,
        'Edited');
    await api.deleteMemory('b2-memory-000');
    dio.close();
  });

  test(
      'reload through previous loaded range fills offsets after a later deletion',
      () async {
    var rows = List.generate(45, (i) => i);
    final list = PagedList<int>(
        id: (x) => '$x',
        fetch: (offset, generation) async => ListPage(
            rows.skip(offset).take(20).toList(), rows.length, offset, 20));
    addTearDown(list.dispose);
    await list.refresh(through: 45);
    rows.remove(23);
    await list.refresh(through: 45);
    expect(list.items, rows);
    expect(list.hasMore, false);
  });

  test('malformed pagination is failure, not a fabricated empty list',
      () async {
    final list = PagedList<int>(
        id: (x) => '$x', fetch: (o, g) async => const ListPage([], 10, 0, 20));
    addTearDown(list.dispose);
    await list.refresh();
    expect(list.failed, true);
    expect(list.loaded, false);
  });

  test(
      'device preferences survive a new store, logout and account switch without sharing tokens',
      () async {
    final store = SessionStore.forTesting();
    addTearDown(store.dispose);
    await store.setThemeMode(EmieThemeMode.light);
    await store.setLanguage('en');
    final restarted = SessionStore.forTesting();
    addTearDown(restarted.dispose);
    await restarted.loadPreferences();
    expect(restarted.themeMode, EmieThemeMode.light);
    expect(restarted.language, 'en');
    restarted.clear();
    restarted.beginSession();
    expect(restarted.themeMode, EmieThemeMode.light);
    expect(restarted.language, 'en');
    expect(restarted.user, isNull);
    expect(restarted.accessToken, isNull);
    await SecureStorageService.saveTokens(accessToken: 'synthetic');
    await SecureStorageService.clearTokens();
    await restarted.loadPreferences();
    expect(restarted.language, 'en');
  });

  test('rapid preference updates are persisted in order', () async {
    final store = SessionStore.forTesting();
    addTearDown(store.dispose);
    await Future.wait([
      store.setThemeMode(EmieThemeMode.light),
      store.setLanguage('en'),
      store.setThemeMode(EmieThemeMode.dark)
    ]);
    final restarted = SessionStore.forTesting();
    addTearDown(restarted.dispose);
    await restarted.loadPreferences();
    expect(restarted.themeMode, EmieThemeMode.dark);
    expect(restarted.language, 'en');
    expect(store.preferencesSaving, false);
    expect(store.preferencesFailed, false);
  });

  test('corrupt stored preferences produce a visible failure state', () async {
    await SecureStorageService.writePreferences('broken');
    final store = SessionStore.forTesting();
    addTearDown(store.dispose);
    await store.loadPreferences();
    expect(store.preferencesFailed, true);
    await store.persistPreferences();
    expect(store.preferencesFailed, false);
  });
  test('preference storage failure is visible and never claims persistence',
      () async {
    SecureStorageService.useStorageForTesting(FailingPreferencesStorage());
    addTearDown(() => SecureStorageService.useStorageForTesting(
        const FlutterSecureStorage()));
    final store = SessionStore.forTesting();
    addTearDown(store.dispose);
    await store.setLanguage('en');
    expect(store.language, 'en');
    expect(store.preferencesFailed, true);
    expect(store.preferencesSaving, false);
  });
  test('malformed chat acknowledgement cannot be treated as a saved reply',
      () async {
    final dio = localDio((r) => response({'unexpected': 'body'}));
    await expectLater(
        ChatApi(dio: dio)
            .sendMessage(text: 'hello', chatSessionId: 'synthetic'),
        throwsFormatException);
    dio.close();
  });
}
