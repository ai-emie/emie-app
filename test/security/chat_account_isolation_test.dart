import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:emie/api/client.dart';
import 'package:emie/app.dart';
import 'package:emie/data/auth/auth_models.dart';
import 'package:emie/data/auth/auth_repository.dart';
import 'package:emie/data/chat/chat_models.dart';
import 'package:emie/data/chat/chat_repository.dart';
import 'package:emie/data/chat/chat_session_models.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import 'package:emie/features/chat/presentation/screens/chat_screen.dart';
import 'package:emie/features/chat/presentation/widgets/authenticated_chat_scope.dart';
import 'package:emie/features/home/presentation/screens/home_screen.dart';
import 'package:emie/features/main/presentation/screens/main_shell.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Empty IDs deliberately match the current /me parser's fallback.
const _userA = UserProfile(id: '', email: 'a@example.invalid', name: 'A');
const _userB = UserProfile(id: '', email: 'b@example.invalid', name: 'B');
final _session = SessionStore.instance;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    _session.clear();
    _session.finishBootstrap();
    await _session.loadPreferences();
  });

  for (final nextUser in [_userA, _userB]) {
    testWidgets('logout then ${nextUser.name} gets a fresh controller',
        (tester) async {
      _login(_userA);
      final factory = _ControllerFactory();
      await _mount(tester, factory);
      final old = factory.current;
      await _seed(old, 'A');
      final oldId = old.chatSessionId;
      await tester.pump();
      expect(find.text('A private message'), findsOneWidget);
      expect(find.text('A private title'), findsOneWidget);

      _session.clear();
      _expectDisposed(old);
      await tester.pump();
      expect(find.text('signed out'), findsOneWidget);
      expect(find.text('A private message'), findsNothing);
      expect(find.text('A private title'), findsNothing);

      _login(nextUser);
      await tester.pump();
      final fresh = factory.current;
      expect(identical(fresh, old), isFalse);
      _expectFresh(fresh, oldId);
      expect(find.text('A private message'), findsNothing);
      expect(find.text('A private title'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('direct A to B switch replaces controller despite empty user IDs',
      (tester) async {
    _login(_userA);
    final factory = _ControllerFactory();
    await _mount(tester, factory);
    final old = factory.current;
    await _seed(old, 'A');
    final oldId = old.chatSessionId;

    _login(_userB);
    _expectDisposed(old);
    await tester.pump();
    _expectFresh(factory.current, oldId);
    expect(find.text('A private message'), findsNothing);
    expect(find.text('A private title'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final nextUser in [_userA, _userB]) {
    testWidgets(
        'clear and ${nextUser.name} login before next frame is isolated',
        (tester) async {
      _login(_userA);
      final factory = _ControllerFactory();
      await _mount(tester, factory);
      final old = factory.current;
      await _seed(old, 'A');
      final oldId = old.chatSessionId;

      _session.clear();
      _expectDisposed(old);
      _login(nextUser);
      await tester.pump();
      _expectFresh(factory.current, oldId);
      expect(factory.controllers, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('token refresh, profile reload and preferences preserve identity',
      (tester) async {
    _login(_userA);
    final factory = _ControllerFactory();
    await _mount(tester, factory);
    final current = factory.current;
    await _seed(current, 'A');

    _session.updateTokens('rotated-access', refresh: 'rotated-refresh');
    _session.updateUser(const UserProfile(
      id: '',
      email: 'a@example.invalid',
      name: 'Updated name',
    ));
    _session.setLanguage('en');
    _session.setThemeMode(EmieThemeMode.light);
    _session.setTone(EmieTone.focused);
    _session.setOnline(false);
    await tester.pump();

    expect(identical(factory.current, current), isTrue);
    expect(current.disposeCount, 0);
    expect(current.messages.single.text, 'A private message');
    expect(current.sessions.single.title, 'A private title');
    expect(current.chatSessionId, 'A-session');
    expect(factory.controllers, hasLength(1));
  });

  testWidgets('nonempty user ID changes also invalidate the controller',
      (tester) async {
    _login(const UserProfile(id: 'id-a', email: 'same@example.invalid'));
    final factory = _ControllerFactory();
    await _mount(tester, factory);
    final old = factory.current;
    await _seed(old, 'A');
    _session.updateUser(
      const UserProfile(id: 'id-b', email: 'same@example.invalid'),
    );
    _expectDisposed(old);
    await tester.pump();
    _expectFresh(factory.current, 'A-session');
  });

  for (final action in ['logout', 'account delete']) {
    testWidgets('$action repository flow disposes authenticated chat scope',
        (tester) async {
      final requests = <String>[];
      _installAdapter((options) {
        requests.add('${options.method} ${options.path}');
        return _json({'status': action == 'account delete' ? 'deleted' : 'ok'});
      });
      _login(_userA);
      final factory = _ControllerFactory();
      await _mount(tester, factory);
      final old = factory.current;
      await _seed(old, 'A');

      final auth = AuthRepository();
      if (action == 'logout') {
        await tester.runAsync(auth.logout);
        expect(requests, ['POST /v1/auth/logout']);
      } else {
        await tester.runAsync(auth.deleteAccount);
        expect(requests, ['DELETE /v1/me']);
      }
      _expectDisposed(old);
      expect(_session.isAuthenticated, isFalse);
      await tester.pump();
      expect(find.text('signed out'), findsOneWidget);
      _login(_userB);
      await tester.pump();
      _expectFresh(factory.current, 'A-session');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('irreparable 401 through ApiClient discards account chat state',
      (tester) async {
    _installAdapter((_) => _json({'code': 'UNAUTHORIZED'}, status: 401));
    _login(_userA, withRefresh: false);
    final factory = _ControllerFactory();
    await _mount(tester, factory);
    final old = factory.current;
    await _seed(old, 'A');

    await tester.runAsync(() => expectLater(
          ApiClient().dio.get<dynamic>('/v1/me'),
          throwsA(isA<DioException>()),
        ));
    _expectDisposed(old);
    expect(_session.isAuthenticated, isFalse);
    await tester.pump();
    _login(_userB);
    await tester.pump();
    _expectFresh(factory.current, 'A-session');
    expect(tester.takeException(), isNull);
  });

  for (final operation in _Operation.values) {
    for (final completion in ['success', 'Dio error', 'other error']) {
      testWidgets('late ${operation.name} $completion cannot reach account B',
          (tester) async {
        _login(_userA);
        final factory = _ControllerFactory();
        await _mount(tester, factory);
        final old = factory.current;
        await _seed(old, 'A');
        final gate = Completer<void>();
        old.repository.gate = gate.future;
        final future = _start(old, operation);
        if (operation == _Operation.send) expect(old.isSending, isTrue);
        if (operation == _Operation.list || operation == _Operation.open) {
          expect(old.isLoadingHistory, isTrue);
        }
        final listCalls = old.repository.listCalls;
        var notifications = 0;
        old.addListener(() => notifications++);

        _session.clear();
        _expectDisposed(old);
        _login(_userB);
        await tester.pump();
        final fresh = factory.current;
        await _seed(fresh, 'B');
        await tester.pump();

        if (completion == 'success') {
          gate.complete();
        } else {
          gate.completeError(completion == 'Dio error'
              ? DioException(requestOptions: RequestOptions(path: '/test'))
              : StateError('delayed test failure'));
        }
        final result = await future;
        await tester.pump();

        if (operation == _Operation.welcome) expect(result, '');
        _expectDisposed(old);
        expect(notifications, 0);
        // In particular send/delete must not initiate a post-logout list call.
        expect(old.repository.listCalls, listCalls);
        expect(fresh.messages.single.text, 'B private message');
        expect(fresh.sessions.single.title, 'B private title');
        expect(fresh.chatSessionId, 'B-session');
        expect(fresh.isSending, isFalse);
        expect(fresh.isLoadingHistory, isFalse);
        expect(fresh.error, isNull);
        expect(find.text('A private message'), findsNothing);
        expect(find.text('A private title'), findsNothing);
        expect(find.text('B private message'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('disposed controller ignores all further entrypoints',
      (tester) async {
    _login(_userA);
    final factory = _ControllerFactory();
    await _mount(tester, factory);
    final old = factory.current;
    await _seed(old, 'A');
    _session.clear();
    final calls = old.repository.calls;
    for (final operation in _Operation.values) {
      await _start(old, operation);
    }
    old.newChat();
    old.clearError();
    _expectDisposed(old);
    expect(old.repository.calls, calls);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth boundary clears existing chat errors and pending flags',
      (tester) async {
    _login(_userA);
    final factory = _ControllerFactory();
    await _mount(tester, factory);
    final old = factory.current;
    old.repository.gate = Future<void>.error(StateError('test load failure'));
    await old.loadSessions();
    expect(old.error, isNotNull);
    _session.clear();
    _expectDisposed(old);
    await tester.pump();
    _login(_userB);
    await tester.pump();
    _expectFresh(factory.current, 'A-session');
  });

  testWidgets('real app: MainShell, Home, Chat and History share auth lifetime',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Only canned local responses, never sockets or live provider calls.
    _installAdapter((options) {
      final account =
          options.headers['Authorization'] == 'Bearer access-A' ? 'A' : 'B';
      switch (options.path) {
        case '/v1/chat/sessions':
          return _json({
            'items': [
              {'id': '$account-session', 'title': '$account private title'}
            ]
          });
        case '/v1/memory/list':
        case '/v1/projects':
          return _json({'items': [], 'total_items': 0, 'offset': 0, 'limit': 20});
        case '/v1/home/summary':
          return _json({'user_stats': {'total_memories': 0, 'memories_today': 0, 'total_projects': 0},
            'recent_project': null, 'recent_memory': null, 'generated_at': '2026-09-30T00:00:00Z'});
        case '/v1/get-daily-welcome':
          return _json({'message': '$account daily welcome'});
        case '/v1/chat/sessions/A-session':
          return _json({
            'messages': [
              {
                'id': 'a-message',
                'role': 'user',
                'content': 'A private message'
              }
            ]
          });
        default:
          throw StateError('Unexpected test request: ${options.path}');
      }
    });
    await tester.pumpWidget(const EmieApp());
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    _login(_userA);
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);
    final homeContext = tester.element(find.byType(HomeScreen));
    final chatContext = tester.element(
      find.byType(ChatScreen, skipOffstage: false),
    );
    final old = homeContext.read<ChatController>();
    expect(identical(chatContext.read<ChatController>(), old), isTrue);
    expect(find.text('A daily welcome'), findsOneWidget);
    await tester.runAsync(() => old.openChat('A-session'));
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('A private message'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();
    expect(find.text('A private title'), findsOneWidget);
    final search = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.hintText == 'Chats suchen...');
    await tester.enterText(search, 'A private');
    await tester.pump();

    // The direct identity switch must remove the open route and search state,
    // not just replace the controller below an otherwise surviving modal.
    _login(_userB);
    expect(old.messages, isEmpty);
    expect(old.sessions, isEmpty);
    expect(old.chatSessionId, isEmpty);
    await tester.pumpAndSettle();
    final fresh =
        tester.element(find.byType(HomeScreen)).read<ChatController>();
    expect(identical(fresh, old), isFalse);
    expect(fresh.messages, isEmpty);
    expect(fresh.chatSessionId, isNot('A-session'));
    expect(fresh.sessions.single.title, 'B private title');
    expect(find.text('A private message'), findsNothing);
    expect(find.text('A private title'), findsNothing);
    expect(find.text('A daily welcome'), findsNothing);
    expect(find.text('B daily welcome'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();
    expect(find.text('B private title'), findsOneWidget);
    final editable = find.descendant(
      of: search,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editable).controller.text, isEmpty);
    _session.clear();
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(fresh.messages, isEmpty);
    expect(fresh.sessions, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

void _login(UserProfile user, {bool withRefresh = true}) {
  _session.updateTokens(
    'access-${user.name ?? user.id}',
    refresh: withRefresh ? 'test-refresh' : null,
  );
  _session.updateUser(user);
}

Future<void> _mount(WidgetTester tester, _ControllerFactory factory) async {
  await tester.pumpWidget(ChangeNotifierProvider<SessionStore>.value(
    value: _session,
    child: Consumer<SessionStore>(builder: (context, session, _) {
      final app = MaterialApp(
        key: ValueKey(session.isAuthenticated),
        home: session.isAuthenticated
            ? const _ChatProbe()
            : const Scaffold(body: Text('signed out')),
      );
      return session.isAuthenticated
          ? AuthenticatedChatScope(
              session: session,
              createController: factory.create,
              child: app,
            )
          : app;
    }),
  ));
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
}

class _ChatProbe extends StatelessWidget {
  const _ChatProbe();

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    return Scaffold(
      body: Column(children: [
        Text(chat.messages.map((message) => message.text).join('|')),
        Text(chat.sessions.map((session) => session.title).join('|')),
        Text(chat.chatSessionId),
      ]),
    );
  }
}

class _ControllerFactory {
  final controllers = <_TrackedChatController>[];
  _TrackedChatController get current => controllers.last;

  ChatController create() {
    final controller = _TrackedChatController(_FakeChatRepository());
    controllers.add(controller);
    return controller;
  }
}

class _TrackedChatController extends ChatController {
  _TrackedChatController(this.repository) : super(repository: repository);

  final _FakeChatRepository repository;
  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }
}

Future<void> _seed(_TrackedChatController controller, String owner) async {
  controller.repository.sessions = [
    ChatSession(
      id: '$owner-session',
      title: '$owner private title',
      createdAt: null,
      updatedAt: null,
    ),
  ];
  controller.repository.messages = [_message('$owner private message')];
  await controller.loadSessions();
  await controller.openChat('$owner-session');
}

ChatMessage _message(String text) => ChatMessage(
      id: 'test-message',
      role: 'user',
      text: text,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void _expectDisposed(_TrackedChatController controller) {
  expect(controller.disposeCount, 1);
  expect(controller.messages, isEmpty);
  expect(controller.sessions, isEmpty);
  expect(controller.chatSessionId, isEmpty);
  expect(controller.isLoadingHistory, isFalse);
  expect(controller.isSending, isFalse);
  expect(controller.error, isNull);
}

void _expectFresh(ChatController controller, String oldId) {
  expect(controller.messages, isEmpty);
  expect(controller.sessions, isEmpty);
  expect(controller.chatSessionId, isNotEmpty);
  expect(controller.chatSessionId, isNot(oldId));
  expect(controller.isLoadingHistory, isFalse);
  expect(controller.isSending, isFalse);
  expect(controller.error, isNull);
}

enum _Operation { send, list, open, delete, welcome }

Future<dynamic> _start(ChatController controller, _Operation operation) {
  switch (operation) {
    case _Operation.send:
      return controller.send('A delayed send');
    case _Operation.list:
      return controller.loadSessions();
    case _Operation.open:
      return controller.openChat('A-session');
    case _Operation.delete:
      return controller.deleteChat('A-session');
    case _Operation.welcome:
      return controller.getDailyWelcome();
  }
}

class _FakeChatRepository implements ChatRepository {
  Future<void>? gate;
  List<ChatSession> sessions = [];
  List<ChatMessage> messages = [];
  int calls = 0;
  int listCalls = 0;

  @override
  Future<List<ChatSession>> listSessions() async {
    calls++;
    listCalls++;
    await gate;
    return sessions;
  }

  @override
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    calls++;
    await gate;
    return messages;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    calls++;
    await gate;
  }

  @override
  Future<String> getDailyWelcome() async {
    calls++;
    await gate;
    return 'A delayed welcome';
  }

  @override
  Future<ChatMessage> sendUserMessage({
    required String text,
    required String chatSessionId,
    String provider = 'openai',
    int maxTokens = 400,
    double temperature = 0.3,
  }) async {
    calls++;
    await gate;
    return _message('A delayed reply');
  }
}

void _installAdapter(ResponseBody Function(RequestOptions) respond) {
  final dio = ApiClient().dio;
  final previous = dio.httpClientAdapter;
  dio.httpClientAdapter = _LocalAdapter(respond);
  addTearDown(() => dio.httpClientAdapter = previous);
}

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _LocalAdapter implements HttpClientAdapter {
  _LocalAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      respond(options);

  @override
  void close({bool force = false}) {}
}
