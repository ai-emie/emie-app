import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:emie/api/client.dart';
import 'package:emie/core/storage/secure_storage.dart';
import 'package:emie/data/auth/auth_api.dart';
import 'package:emie/data/auth/auth_models.dart';
import 'package:emie/data/auth/auth_repository.dart';
import 'package:emie/features/auth/controller/auth_controller.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void repairDirectRefreshTests() {
  test('KL5 repair RED R3: direct refresh 401 ends its invalid session', () async {
    final h = Kl5Harness();
    addTearDown(h.dispose);
    await h.login('A');
    final origin = h.session.generation;
    h.requests.clear();
    h.storage.events.clear();
    h.onMain = (request) async {
      expect(request.method, 'POST');
      expect(request.path, '/v1/auth/refresh');
      expect(request.data, {'refresh_token': 'synthetic-refresh-A'});
      expect(request.extra[ApiClient.sessionKey], origin);
      return Kl5Harness.json({'code': 'UNAUTHORIZED'}, status: 401);
    };
    Object? observed;
    try {
      await h.repository.refreshTokens().timeout(const Duration(seconds: 3));
    } catch (error) {
      observed = error;
    }
    debugPrint('KL5_REPAIR_RED_R3 error=${observed.runtimeType} '
        'status=${observed is DioException ? observed.response?.statusCode : null} '
        'authenticated=${h.session.isAuthenticated} '
        'userPresent=${h.session.user != null} '
        'storedKeys=${h.storage.values.length} events=${h.storage.events} '
        'requests=${h.requests} autoRefresh=${h.refreshRequests.length}');
    expect(observed, isA<DioException>());
    final error = observed as DioException;
    expect(error.type, DioExceptionType.badResponse);
    expect(error.response?.statusCode, 401);
    expect(error.requestOptions.extra[ApiClient.sessionKey], origin);
    expect(h.requests, ['POST /v1/auth/refresh A']);
    expect(h.refreshRequests, isEmpty);
    expect(h.session.generation, origin + 1);
    expect(h.session.isAuthenticated, isFalse);
    expect(h.session.user, isNull);
    expect(h.session.accessToken, isNull);
    expect(h.session.refreshToken, isNull);
    expect(h.storage.values, isEmpty);
    expect(h.storage.events, [
      'delete:access:start', 'delete:access:end',
      'delete:refresh:start', 'delete:refresh:end'
    ]);
  });
}

void repairDirectRefreshEdgeTests() {
  group('KL5 repair direct refresh', () {
    late Kl5Harness h;
    setUp(() => h = Kl5Harness());
    tearDown(() => h.dispose());

    for (final malformed in [false, true]) {
      for (final failedKeys in ['none', 'access', 'refresh', 'both']) {
        if (!malformed && failedKeys == 'none') {
          continue; // Covered by RED R3.
        }
        test('401 ${malformed ? 'malformed' : 'valid'} cleanup $failedKeys',
            () async {
          await h.login('A');
          final origin = h.session.generation;
          h.requests.clear();
          h.storage.events.clear();
          if (failedKeys == 'access' || failedKeys == 'both') {
            h.storage.failures.add('delete:access');
          }
          if (failedKeys == 'refresh' || failedKeys == 'both') {
            h.storage.failures.add('delete:refresh');
          }
          h.storage.before = (operation, key, _) async {
            if (operation == 'delete') {
              expect(h.session.generation, origin + 1);
              expect(h.session.user, isNull);
              expect(h.session.accessToken, isNull);
              expect(h.session.refreshToken, isNull);
            }
          };
          h.onMain = (request) async {
            expect(request.path, '/v1/auth/refresh');
            expect(request.extra[ApiClient.sessionKey], origin);
            expect(request.data, {'refresh_token': 'synthetic-refresh-A'});
            expect(request.receiveDataWhenStatusError, isFalse);
            expect(request.validateStatus(401), isFalse);
            expect(request.responseType, ResponseType.json);
            return ResponseBody.fromString(
                malformed ? '{broken' : '{"code":"UNAUTHORIZED"}', 401,
                headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
          };
          DioException? original;
          final observer = InterceptorsWrapper(onError: (error, handler) {
            original = error;
            handler.next(error);
          });
          ApiClient().dio.interceptors.add(observer);
          addTearDown(() => ApiClient().dio.interceptors.remove(observer));
          var completions = 0;
          final outcome = await h.repository.refreshTokens().then<Object?>((_) {
            completions++;
            return null;
          }, onError: (Object error) {
            completions++;
            return error;
          }).timeout(const Duration(seconds: 3));
          expect(outcome, isA<DioException>());
          final error = outcome as DioException;
          expect(identical(error, original), isTrue);
          expect(error.type, DioExceptionType.badResponse);
          expect(error.response?.statusCode, 401);
          expect(error.response?.data, isNull);
          expect(error.requestOptions.extra[ApiClient.sessionKey], origin);
          expect(completions, 1);
          expect(h.session.generation, origin + 1);
          expect(h.session.isAuthenticated, isFalse);
          expect(h.storage.events, [
            'delete:access:start',
            h.storage.failures.contains('delete:access')
                ? 'delete:access:failed' : 'delete:access:end',
            'delete:refresh:start',
            h.storage.failures.contains('delete:refresh')
                ? 'delete:refresh:failed' : 'delete:refresh:end'
          ]);
          expect(h.storage.values.containsKey(FakeTokenStorage.access),
              h.storage.failures.contains('delete:access'));
          expect(h.storage.values.containsKey(FakeTokenStorage.refresh),
              h.storage.failures.contains('delete:refresh'));
          expect(h.requests, ['POST /v1/auth/refresh A']);
          expect(h.refreshRequests, isEmpty);
        });
      }
    }

    for (final nextOwner in ['B', 'A']) {
      for (final status in [401, 200]) {
        test('late A $status preserves new $nextOwner session', () async {
          await h.login('A');
          final origin = h.session.generation;
          final arrived = Completer<void>();
          final response = Completer<ResponseBody>();
          h.onMain = (request) async {
            if (request.path == '/v1/auth/refresh') {
              expect(request.extra[ApiClient.sessionKey], origin);
              expect(request.data, {'refresh_token': 'synthetic-refresh-A'});
              arrived.complete();
              return response.future;
            }
            return h.defaultResponse(request);
          };
          final pending = h.repository.refreshTokens().then<Object?>(
              (_) => null, onError: (Object error) => error);
          await arrived.future;
          await h.login(nextOwner);
          final generation = h.session.generation;
          expect(generation, greaterThan(origin));
          final stored = Map<String, String>.from(h.storage.values);
          final events = List<String>.from(h.storage.events);
          response.complete(status == 401
              ? ResponseBody.fromString('{broken', 401, headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType]
                })
              : Kl5Harness.tokens('A', rotated: true));
          final outcome = await pending.timeout(const Duration(seconds: 3));
          if (status == 401) {
            expect(outcome, isA<DioException>());
            expect((outcome as DioException).response?.statusCode, 401);
            expect(outcome.type, DioExceptionType.badResponse);
            expect(outcome.requestOptions.extra[ApiClient.sessionKey], origin);
          } else {
            expect(outcome, isA<StaleSessionException>());
          }
          expect(h.session.generation, generation);
          h.expectOwner(nextOwner);
          expect(h.session.accessToken, 'synthetic-$nextOwner');
          expect(h.session.refreshToken, 'synthetic-refresh-$nextOwner');
          expect(h.storage.values, stored);
          expect(h.storage.events, events);
          expect(h.requests.where((r) => r.startsWith('POST /v1/auth/refresh')),
              ['POST /v1/auth/refresh A']);
          expect(h.refreshRequests, isEmpty);
        });
      }
    }

    test('started 401 cleanup precedes queued B writes', () async {
      await h.login('A');
      h.storage.events.clear();
      final entered = Completer<void>(), release = Completer<void>();
      final bLoginArrived = Completer<void>();
      h.storage.before = (operation, key, _) async {
        if (operation == 'delete' && key == FakeTokenStorage.access) {
          expect(h.session.isAuthenticated, isFalse);
          entered.complete();
          await release.future;
        }
      };
      h.onMain = (request) async {
        if (request.path == '/v1/auth/refresh') {
          return Kl5Harness.json({}, status: 401);
        }
        if (request.path == '/v1/auth/login') bLoginArrived.complete();
        return h.defaultResponse(request);
      };
      final pending = h.repository.refreshTokens().then<Object?>(
          (_) => null, onError: (Object error) => error);
      await entered.future;
      final login = h.login('B');
      await bLoginArrived.future;
      release.complete();
      final outcome = await pending.timeout(const Duration(seconds: 3));
      await login;
      expect(outcome, isA<DioException>());
      expect((outcome as DioException).response?.statusCode, 401);
      h.expectOwner('B');
      expect(h.storage.events.indexOf('delete:refresh:end'),
          lessThan(h.storage.events.indexOf('write:access:start')));
      expect(h.storage.events.where((e) => e.startsWith('delete:')), [
        'delete:access:start', 'delete:access:end',
        'delete:refresh:start', 'delete:refresh:end'
      ]);
      expect(h.refreshRequests, isEmpty);
    });

    test('rotation updates the same generation and persisted pair', () async {
      await h.login('A');
      final origin = h.session.generation;
      h.requests.clear();
      h.storage.events.clear();
      h.onMain = (request) async {
        expect(request.data, {'refresh_token': 'synthetic-refresh-A'});
        expect(request.extra[ApiClient.sessionKey], origin);
        return Kl5Harness.tokens('A', rotated: true);
      };
      await h.repository.refreshTokens();
      expect(h.session.generation, origin);
      h.expectOwner('A');
      expect(h.session.accessToken, 'synthetic-A-rotated');
      expect(h.session.refreshToken, 'synthetic-refresh-A-rotated');
      expect(h.storage.values, {
        FakeTokenStorage.access: 'synthetic-A-rotated',
        FakeTokenStorage.refresh: 'synthetic-refresh-A-rotated'
      });
      expect(h.storage.events.where((e) => e.startsWith('delete:')), isEmpty);
      expect(h.requests, ['POST /v1/auth/refresh A']);
      expect(h.refreshRequests, isEmpty);
    });

    for (final kind in ['timeout', 'connection', '503', '503 malformed']) {
      test('$kind preserves its error category and session', () async {
        await h.login('A');
        final origin = h.session.generation;
        h.requests.clear();
        h.storage.events.clear();
        final expected = kind == 'timeout' ? DioExceptionType.receiveTimeout
            : kind == 'connection' ? DioExceptionType.connectionError
            : DioExceptionType.badResponse;
        h.onMain = (request) async {
          if (kind.startsWith('503')) {
            return ResponseBody.fromString(
                kind == '503' ? '{}' : '{broken', 503,
                headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
          }
          throw DioException(requestOptions: request, type: expected);
        };
        Object? observed;
        try {
          await h.repository.refreshTokens();
        } catch (error) {
          observed = error;
        }
        expect(observed, isA<DioException>());
        final error = observed as DioException;
        expect(error.type, expected);
        expect(error.response?.statusCode, kind.startsWith('503') ? 503 : null);
        expect(error.requestOptions.extra[ApiClient.sessionKey], origin);
        expect(h.session.generation, origin);
        h.expectOwner('A');
        expect(h.storage.events, isEmpty);
        expect(h.requests, ['POST /v1/auth/refresh A']);
        expect(h.refreshRequests, isEmpty);
      });
    }

    test('other auth 401 does not reset an active session', () async {
      await h.login('B');
      final origin = h.session.generation;
      h.requests.clear();
      h.storage.events.clear();
      h.onMain = (_) async => Kl5Harness.json({}, status: 401);
      await expectLater(
          AuthApi().login(email: 'invalid@example.invalid',
              password: 'synthetic', generation: origin),
          throwsA(isA<DioException>()
              .having((e) => e.response?.statusCode, 'status', 401)));
      expect(h.session.generation, origin);
      h.expectOwner('B');
      expect(h.storage.events, isEmpty);
      expect(h.requests, ['POST /v1/auth/login B']);
      expect(h.refreshRequests, isEmpty);
    });

    test('session switch before dispatch cancels direct refresh as A',
        () async {
      await h.login('A');
      final pending = h.repository.refreshTokens().then<Object?>(
          (_) => null, onError: (Object error) => error);
      await h.login('B');
      final generation = h.session.generation;
      final outcome = await pending;
      expect(outcome, isA<DioException>());
      expect((outcome as DioException).type, DioExceptionType.cancel);
      expect(outcome.error, isA<StaleSessionException>());
      expect(h.session.generation, generation);
      h.expectOwner('B');
      expect(h.requests.where((r) => r.startsWith('POST /v1/auth/refresh')),
          isEmpty);
      expect(h.refreshRequests, isEmpty);
    });
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  repairDirectRefreshTests();
  repairDirectRefreshEdgeTests();
  sessionContractTests();
  storageAndRefreshTests();
  googleCoordinationTests();
  test('KL5 RED B: late A DELETE 401 cannot refresh as B or clear B', () async {
    final session = SessionStore.instance;
    FlutterSecureStorage.setMockInitialValues({});
    session.clear();
    session.finishBootstrap();
    session.updateTokens('synthetic-A', refresh: 'synthetic-refresh-A');
    session.updateUser(const UserProfile(id: 'A', email: 'a@example.invalid'));
    final arrived = Completer<void>();
    final response = Completer<ResponseBody>();
    final requests = <String>[];
    final nativeRequests = <String>[];
    final dio = ApiClient().dio;
    final original = dio.httpClientAdapter;
    dio.httpClientAdapter = _Adapter((request) async {
      final header = request.headers['Authorization'];
      final identity = header == 'Bearer synthetic-A'
          ? 'A'
          : header == 'Bearer synthetic-B'
              ? 'B'
              : 'none';
      requests.add('${request.method} ${request.path} $identity');
      if (request.method == 'DELETE') {
        if (!arrived.isCompleted) {
          arrived.complete();
          return response.future;
        }
        return _json({'status': 'deleted'});
      }
      if (request.path == '/v1/auth/login') {
        return _json({
          'access_token': 'synthetic-B',
          'refresh_token': 'synthetic-refresh-B'
        });
      }
      if (request.path == '/v1/me') {
        return _json({'id': 'B', 'email': 'b@example.invalid'});
      }
      throw StateError('Unexpected synthetic route');
    });
    addTearDown(() {
      dio.httpClientAdapter = original;
      session.clear();
    });
    await HttpOverrides.runZoned(() async {
      final repository = AuthRepository();
      final pending = repository
          .deleteAccount()
          .then<Object?>((_) => null, onError: (Object _) => null);
      await arrived.future;
      await repository.loginWithEmail(
          'b@example.invalid', 'synthetic-password');
      expect(session.user?.id, 'B');
      response.complete(_json({'code': 'UNAUTHORIZED'}, status: 401));
      await pending;
    }, createHttpClient: (_) => _NoNetworkClient(nativeRequests));
    final storageIsB = await SecureStorageService.getAccessToken() ==
            'synthetic-B' &&
        await SecureStorageService.getRefreshToken() == 'synthetic-refresh-B';
    debugPrint(
        'KL5_RED_B requests=$requests refresh=$nativeRequests owner=${session.user?.id} storageIsB=$storageIsB');
    expect(requests.where((request) => request.startsWith('DELETE')).toList(),
        ['DELETE /v1/me A']);
    expect(nativeRequests, isEmpty);
    expect(session.user?.id, 'B');
    expect(session.accessToken, 'synthetic-B');
    expect(session.refreshToken, 'synthetic-refresh-B');
    expect(storageIsB, isTrue);
  });
}

ResponseBody _json(Object body, {int status = 200}) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
          Future<void>? cancelFuture) =>
      respond(options);
  @override
  void close({bool force = false}) {}
}

// The old private refresh Dio has no injection seam. Intercept its actual IO
// transport, including serialized body, without replacing any auth logic.
class _NoNetworkClient implements HttpClient {
  _NoNetworkClient(this.events);
  final List<String> events;
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Request(method, url, events);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.method, this.uri, this.events);
  @override
  final String method;
  @override
  final Uri uri;
  final List<String> events;
  final List<int> bytes = [];
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      bytes.addAll(data);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    if (uri.path != '/v1/auth/refresh') {
      throw StateError('Network forbidden');
    }
    final body = jsonDecode(utf8.decode(bytes)) as Map;
    events.add(
        '$method ${uri.path} ${body['refresh_token'] == 'synthetic-refresh-B' ? 'B' : 'A'}');
    return _Response();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  void forEach(void Function(String, List<String>) action) =>
      action('content-type', ['application/json']);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 401;
  @override
  String get reasonPhrase => 'Unauthorized';
  @override
  HttpHeaders get headers => _Headers();
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(utf8.encode('{"code":"UNAUTHORIZED"}')).listen(
          onData,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Shared only by the three KL5 test files. Production client, repository,
// controller and storage queue stay real; only transport/plugin IO is replaced.
class Kl5Harness {
  Kl5Harness() {
    session.clear();
    session.finishBootstrap();
    SecureStorageService.useStorageForTesting(storage);
    previousMain = ApiClient().dio.httpClientAdapter;
    previousRefresh = ApiClient().refreshDio.httpClientAdapter;
    ApiClient().dio.httpClientAdapter = _Adapter((request) async {
      requests.add('${request.method} ${request.path} ${owner(request)}');
      return onMain == null ? defaultResponse(request) : await onMain!(request);
    });
    ApiClient().refreshDio.httpClientAdapter = _Adapter((request) async {
      refreshRequests.add(ownerOf(request.data['refresh_token']));
      if (onRefresh == null) {
        throw StateError('Unexpected refresh; network forbidden');
      }
      return onRefresh!(request);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(googleChannel, (call) async {
      googleEvents.add('${call.method}:start');
      await beforeGoogle?.call(call.method);
      if (googleFailures.contains(call.method)) {
        googleEvents.add('${call.method}:failed');
        throw PlatformException(code: 'synthetic');
      }
      googleEvents.add('${call.method}:end');
      switch (call.method) {
        case 'init':
        case 'signOut':
          return null;
        case 'signIn':
          if (cancelGoogle) {
            return null;
          }
          return {
            'id': googleOwner,
            'email': '${googleOwner.toLowerCase()}@example.invalid',
            'displayName': googleOwner,
            'photoUrl': null,
            'serverAuthCode': null
          };
        case 'getTokens':
          return {
            'idToken': 'synthetic-$googleOwner',
            'accessToken': 'synthetic-$googleOwner'
          };
        default:
          throw StateError('Unexpected Google method');
      }
    });
    auth = AuthController();
  }
  static const googleChannel =
      MethodChannel('plugins.flutter.io/google_sign_in');
  final session = SessionStore.instance;
  final storage = FakeTokenStorage();
  final repository = AuthRepository();
  late final AuthController auth;
  late final HttpClientAdapter previousMain;
  late final HttpClientAdapter previousRefresh;
  final requests = <String>[];
  final refreshRequests = <String>[];
  final googleEvents = <String>[];
  final googleFailures = <String>{};
  String googleOwner = 'B';
  bool cancelGoogle = false;
  Future<void> Function(String)? beforeGoogle;
  Future<ResponseBody> Function(RequestOptions)? onMain;
  Future<ResponseBody> Function(RequestOptions)? onRefresh;

  static String ownerOf(Object? token) {
    final text = token?.toString() ?? '';
    for (final owner in ['A', 'B', 'C']) {
      if (text.contains('synthetic-$owner') ||
          text.contains('synthetic-refresh-$owner')) {
        return owner;
      }
    }
    return 'none';
  }

  static String owner(RequestOptions request) =>
      ownerOf(request.headers['Authorization']);
  static ResponseBody json(Object? body, {int status = 200}) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  static ResponseBody tokens(String owner, {bool rotated = false}) => json({
        'access_token': 'synthetic-$owner${rotated ? '-rotated' : ''}',
        'refresh_token': 'synthetic-refresh-$owner${rotated ? '-rotated' : ''}',
      });
  ResponseBody defaultResponse(RequestOptions request) {
    if (request.path == '/v1/auth/login') {
      return tokens(
          (request.data['email'] as String).substring(0, 1).toUpperCase());
    }
    if (request.path == '/v1/auth/google' || request.path == '/v1/auth/apple') {
      return tokens(ownerOf(request.data['id_token']));
    }
    if (request.path == '/v1/auth/register' ||
        request.path == '/v1/auth/verify') {
      return json({'message': 'synthetic'});
    }
    if (request.path == '/v1/auth/password/reset/start' ||
        request.path == '/v1/auth/logout') {
      return json({'status': 'ok'});
    }
    if (request.path == '/v1/me' && request.method == 'DELETE') {
      return json({'status': 'deleted'});
    }
    if (request.path == '/v1/me') {
      final id = owner(request);
      return json({
        'id': id,
        'email': '${id.toLowerCase()}@example.invalid',
        'display_name': id
      });
    }
    if (request.path == '/v1/chat/sessions') {
      return json({'items': []});
    }
    if (request.path == '/v1/memory/list' || request.path == '/v1/projects') {
      return json({'items': [], 'total_items': 0, 'offset': 0, 'limit': 20});
    }
    if (request.path == '/v1/home/summary') {
      return json({'user_stats': {'total_memories': 0, 'memories_today': 0, 'total_projects': 0},
        'recent_project': null, 'recent_memory': null, 'generated_at': '2026-09-30T00:00:00Z'});
    }
    if (request.path == '/v1/get-daily-welcome') {
      return json({'message': 'Welcome ${owner(request)}'});
    }
    throw StateError('Unexpected synthetic route ${request.path}');
  }

  Future<void> login(String owner) async {
    expect(
        await auth.loginWithEmail(
            '${owner.toLowerCase()}@example.invalid', 'synthetic-password'),
        isTrue);
  }

  void expectOwner(String id) {
    expect(session.user?.id, id);
    expect(ownerOf(session.accessToken), id);
    expect(ownerOf(session.refreshToken), id);
    expect(ownerOf(storage.values[FakeTokenStorage.access]), id);
    expect(ownerOf(storage.values[FakeTokenStorage.refresh]), id);
  }

  void dispose() {
    auth.dispose();
    session.clear();
    SecureStorageService.useStorageForTesting(const FlutterSecureStorage());
    ApiClient().dio.httpClientAdapter = previousMain;
    ApiClient().refreshDio.httpClientAdapter = previousRefresh;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(googleChannel, null);
  }
}

class FakeTokenStorage extends FlutterSecureStorage {
  static const access = 'emie_access_token';
  static const refresh = 'emie_refresh_token';
  String label(String key) => key == access ? 'access' : key == refresh ? 'refresh' : 'preferences';
  final values = <String, String>{};
  final events = <String>[];
  final failures = <String>{};
  Future<void> Function(String operation, String key, String? value)? before;
  Future<void> _start(String operation, String key, String? value) async {
    final short = label(key);
    final event = '$operation:$short';
    events.add('$event:start');
    await before?.call(operation, key, value);
    if (failures.contains(event)) {
      events.add('$event:failed');
      throw PlatformException(code: 'synthetic');
    }
  }

  @override
  Future<void> write(
      {required String key,
      required String? value,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    await _start('write', key, value);
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    events.add(
        'write:${label(key)}:end:${Kl5Harness.ownerOf(value)}');
  }

  @override
  Future<String?> read(
      {required String key,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    await _start('read', key, null);
    return values[key];
  }

  @override
  Future<void> delete(
      {required String key,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    await _start('delete', key, null);
    values.remove(key);
    events.add('delete:${label(key)}:end');
  }

  @override
  Future<void> deleteAll(
      {IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    events.add('deleteAll');
    throw StateError('deleteAll forbidden');
  }
}

void storageAndRefreshTests() {
  group('KL5 ordered storage and refresh', () {
    late Kl5Harness h;
    setUp(() {
      h = Kl5Harness();
    });
    tearDown(() {
      h.dispose();
    });

    test('started A cleanup finishes before queued B credential writes',
        () async {
      await h.login('A');
      h.storage.events.clear();
      final entered = Completer<void>(), release = Completer<void>();
      final bLoginArrived = Completer<void>();
      h.storage.before = (operation, key, _) async {
        if (operation == 'delete' && key == FakeTokenStorage.access) {
          entered.complete();
          await release.future;
        }
      };
      h.onMain = (request) async {
        if (request.path == '/v1/auth/login') bLoginArrived.complete();
        return h.defaultResponse(request);
      };
      final deletion = h.auth.deleteAccount();
      await entered.future;
      final b =
          h.auth.loginWithEmail('b@example.invalid', 'synthetic-password');
      await bLoginArrived.future;
      release.complete();
      await deletion;
      expect(await b, isTrue);
      h.expectOwner('B');
      expect(h.storage.events.indexOf('delete:refresh:end'),
          lessThan(h.storage.events.indexOf('write:access:end:B')));
      expect(h.googleEvents, isEmpty);
      expect(h.auth.deletionNotice, isNull);
    });

    test('started A tokenwrite cannot survive the subsequent session end',
        () async {
      await h.login('A');
      final origin = h.session.generation;
      final entered = Completer<void>(),
          release = Completer<void>(),
          ended = Completer<void>();
      h.storage.before = (operation, key, _) async {
        if (operation == 'write' && key == FakeTokenStorage.access) {
          entered.complete();
          await release.future;
        }
      };
      void observe() {
        if (!h.session.isAuthenticated && !ended.isCompleted) ended.complete();
      }

      h.session.addListener(observe);
      addTearDown(() => h.session.removeListener(observe));
      final write = SecureStorageService.saveTokens(
          accessToken: 'synthetic-A-late',
          refreshToken: 'synthetic-refresh-A-late',
          isCurrent: () => h.session.isCurrent(origin));
      await entered.future;
      final deletion = h.auth.deleteAccount();
      await ended.future;
      release.complete();
      expect(await write, isFalse);
      expect((await deletion).server, DeletionServerResult.confirmed);
      expect(h.storage.values, isEmpty);
      expect(h.session.isAuthenticated, isFalse);
    });

    test('queued stale writes and deletes are checked at execution', () async {
      await h.login('A');
      final origin = h.session.generation;
      final entered = Completer<void>(), release = Completer<void>();
      h.storage.events.clear();
      h.storage.before = (operation, key, _) async {
        if (operation == 'read' && key == FakeTokenStorage.access) {
          entered.complete();
          await release.future;
        }
      };
      final read = SecureStorageService.readTokens(
          isCurrent: () => h.session.isCurrent(origin));
      await entered.future;
      final write = SecureStorageService.saveTokens(
          accessToken: 'synthetic-A-late',
          refreshToken: 'synthetic-refresh-A-late',
          isCurrent: () => h.session.isCurrent(origin));
      final cleanup = SecureStorageService.clearTokens(
          isCurrent: () => h.session.isCurrent(origin));
      final b =
          h.auth.loginWithEmail('b@example.invalid', 'synthetic-password');
      release.complete();
      expect(await read, isNull);
      expect(await write, isFalse);
      expect((await cleanup).access, LocalCleanupStep.differentSession);
      expect(await b, isTrue);
      h.expectOwner('B');
      expect(h.storage.events.where((e) => e.startsWith('delete:')), isEmpty);
      expect(h.storage.events.where((e) => e.endsWith(':end:A')), isEmpty);
      expect(h.storage.events.indexOf('read:refresh:start'),
          lessThan(h.storage.events.indexOf('write:access:start')));
    });

    test('a throwing queued write releases subsequent operations', () async {
      await h.login('A');
      h.storage.failures.add('write:access');
      await expectLater(
          SecureStorageService.saveTokens(accessToken: 'synthetic-A'),
          throwsA(isA<PlatformException>()));
      h.storage.failures.clear();
      await h.login('B');
      h.expectOwner('B');
    });

    test('normal 401 refresh and one retry preserve logical generation',
        () async {
      await h.login('A');
      final generation = h.session.generation;
      h.onMain = (request) async => Kl5Harness.json({'value': 'synthetic'},
          status:
              request.headers['Authorization'] == 'Bearer synthetic-A-rotated'
                  ? 200
                  : 401);
      h.onRefresh = (_) async => Kl5Harness.tokens('A', rotated: true);
      final response = await ApiClient().dio.get('/protected');
      expect(response.statusCode, 200);
      expect(h.refreshRequests, ['A']);
      expect(h.requests.where((r) => r.contains('/protected')).length, 2);
      expect(h.session.generation, generation);
      h.expectOwner('A');
    });

    test('same-session concurrent 401 requests share their refresh', () async {
      await h.login('A');
      final entered = Completer<void>(),
          release = Completer<void>(),
          both = Completer<void>();
      var originals = 0;
      h.onMain = (request) async {
        if (request.headers['Authorization'] == 'Bearer synthetic-A') {
          originals++;
          if (originals == 2) both.complete();
          return Kl5Harness.json({}, status: 401);
        }
        return Kl5Harness.json({});
      };
      h.onRefresh = (_) async {
        entered.complete();
        await release.future;
        return Kl5Harness.tokens('A', rotated: true);
      };
      final first = ApiClient().dio.get('/first'),
          second = ApiClient().dio.get('/second');
      await entered.future;
      await both.future;
      release.complete();
      expect((await first).statusCode, 200);
      expect((await second).statusCode, 200);
      expect(h.refreshRequests, ['A']);
    });

    for (final oldRefresh in ['success', '401', 'network']) {
      test('late A refresh $oldRefresh is not shared with or applied to B',
          () async {
        await h.login('A');
        final entered = Completer<void>(), release = Completer<void>();
        h.onMain = (request) async {
          if (!request.path.startsWith('/protected')) {
            return h.defaultResponse(request);
          }
          return Kl5Harness.json({},
              status: request.headers['Authorization']
                      .toString()
                      .endsWith('-rotated')
                  ? 200
                  : 401);
        };
        h.onRefresh = (request) async {
          if (Kl5Harness.ownerOf(request.data['refresh_token']) == 'A') {
            entered.complete();
            await release.future;
            if (oldRefresh == '401') {
              return Kl5Harness.json({}, status: 401);
            }
            if (oldRefresh == 'network') {
              throw DioException(
                  requestOptions: request,
                  type: DioExceptionType.connectionError);
            }
            return Kl5Harness.tokens('A', rotated: true);
          }
          return Kl5Harness.tokens('B', rotated: true);
        };
        final a = ApiClient().dio.get('/protected-a');
        final checked = expectLater(a, throwsA(isA<DioException>()));
        await entered.future;
        await h.login('B');
        expect((await ApiClient().dio.get('/protected-b')).statusCode, 200);
        release.complete();
        await checked;
        h.expectOwner('B');
        expect(h.session.accessToken, 'synthetic-B-rotated');
        expect(h.refreshRequests, ['A', 'B']);
        expect(h.requests.where((r) => r.contains('/protected-a')).length, 1);
      });
    }

    for (final failures in [
      <String>{},
      {'delete:access'},
      {'delete:access', 'delete:refresh'}
    ]) {
      test(
          'auth reset finishes once with storage failures ${failures.join('+')}',
          () async {
        await h.login('A');
        h.storage.failures.addAll(failures);
        h.onMain = (_) async => Kl5Harness.json({}, status: 401);
        h.onRefresh = (_) async => Kl5Harness.json({}, status: 401);
        var finished = 0;
        final request = ApiClient().dio.get('/protected').then<void>((_) {
          finished++;
        }, onError: (Object error) {
          finished++;
          expect(error, isA<DioException>());
        });
        await request.timeout(const Duration(seconds: 3));
        expect(finished, 1);
        expect(h.session.isAuthenticated, isFalse);
        expect(h.storage.events,
            containsAll(['delete:access:start', 'delete:refresh:start']));
        h.storage.failures.clear();
        h.onMain = null;
        await h.login('B');
        h.expectOwner('B');
      });
    }

    test('retry 500 is propagated instead of the original 401', () async {
      await h.login('A');
      h.onMain = (request) async => Kl5Harness.json({},
          status: request.headers['Authorization'] == 'Bearer synthetic-A'
              ? 401
              : 500);
      h.onRefresh = (_) async => Kl5Harness.tokens('A', rotated: true);
      await expectLater(
          ApiClient().dio.get('/protected'),
          throwsA(isA<DioException>().having(
              (e) => e.response?.statusCode, 'actual retry status', 500)));
      expect(h.session.isAuthenticated, isTrue);
      expect(h.refreshRequests, ['A']);
      expect(h.requests.where((r) => r.contains('/protected')).length, 2);
    });

    for (final key in ['write:access', 'write:refresh']) {
      test('refresh storage failure $key completes and releases later B writes',
          () async {
        await h.login('A');
        h.storage.failures.add(key);
        h.onMain = (_) async => Kl5Harness.json({}, status: 401);
        h.onRefresh = (_) async => Kl5Harness.tokens('A', rotated: true);
        var completions = 0;
        await ApiClient().dio.get('/protected').then<void>(
          (_) => fail('Storage failure must be surfaced'),
          onError: (Object error) {
            completions++;
            expect(error, isA<DioException>());
          },
        ).timeout(const Duration(seconds: 3));
        expect(completions, 1);
        expect(h.requests.where((r) => r.contains('/protected')).length, 1);
        h.storage.failures.clear();
        h.onMain = null;
        await h.login('B');
        h.expectOwner('B');
      });
    }

    test('repeated retry 401 ends same session without refresh loop', () async {
      await h.login('A');
      h.onMain = (_) async => Kl5Harness.json({}, status: 401);
      h.onRefresh = (_) async => Kl5Harness.tokens('A', rotated: true);
      await expectLater(
          ApiClient().dio.get('/protected'), throwsA(isA<DioException>()));
      expect(h.refreshRequests, ['A']);
      expect(h.requests.where((r) => r.contains('/protected')).length, 2);
      expect(h.session.isAuthenticated, isFalse);
    });

    test('refresh transport failure does not clear a current session',
        () async {
      await h.login('A');
      h.onMain = (_) async => Kl5Harness.json({}, status: 401);
      h.onRefresh = (request) async => throw DioException(
          requestOptions: request, type: DioExceptionType.connectionError);
      await expectLater(
          ApiClient().dio.get('/protected'), throwsA(isA<DioException>()));
      h.expectOwner('A');
    });

    test(
        'registration verification password reset and ordinary logout remain usable',
        () async {
      expect(
          await h.auth.registerWithEmail(
              'A', 'a@example.invalid', 'synthetic-password'),
          isTrue);
      expect(await h.auth.verifyEmail('synthetic-verification'), isTrue);
      expect(await h.auth.requestPasswordReset('a@example.invalid'), isTrue);
      await h.login('A');
      await h.auth.logout();
      expect(h.session.isAuthenticated, isFalse);
      expect(h.storage.values, isEmpty);
      expect(h.googleEvents, contains('signOut:end'));
      expect(h.refreshRequests, isEmpty);
    });

    test('Apple repository login keeps the native provider outside the test',
        () async {
      await h.repository.loginWithApple('synthetic-A');
      h.expectOwner('A');
    });

    test('unsupported Apple platform releases controller loading state',
        () async {
      // This suite runs on the documented Windows host, without native Apple IO.
      expect(Platform.isWindows, isTrue);
      expect(await h.auth.loginWithApple(), isFalse);
      expect(h.auth.isLoading, isFalse);
      expect(h.requests, isEmpty);
    });
  });
}

void googleCoordinationTests() {
  group('KL5 Google coordination', () {
    late Kl5Harness h;
    setUp(() {
      h = Kl5Harness();
    });
    tearDown(() {
      h.dispose();
    });

    for (final fail in [false, true]) {
      test('started signOut completes before new Google signIn, failure=$fail',
          () async {
        await h.login('A');
        final entered = Completer<void>(), release = Completer<void>();
        h.beforeGoogle = (method) async {
          if (method == 'signOut') {
            entered.complete();
            await release.future;
          }
        };
        if (fail) h.googleFailures.add('signOut');
        final deletion = h.auth.deleteAccount();
        await entered.future;
        final login = h.auth.loginWithGoogle();
        expect(h.googleEvents, isNot(contains('signIn:start')));
        release.complete();
        final result = await deletion;
        expect(result.google,
            fail ? LocalCleanupStep.unconfirmed : LocalCleanupStep.confirmed);
        expect(await login, isTrue);
        h.expectOwner('B');
        expect(h.googleEvents.indexOf(fail ? 'signOut:failed' : 'signOut:end'),
            lessThan(h.googleEvents.indexOf('signIn:start')));
        expect(h.auth.deletionNotice, isNull);
      });
    }

    test('queued stale A signOut is skipped before B Google signIn', () async {
      final entered = Completer<void>(), release = Completer<void>();
      var signIns = 0;
      h.beforeGoogle = (method) async {
        if (method == 'signIn' && ++signIns == 1) {
          entered.complete();
          await release.future;
        }
      };
      final oldLogin = h.auth.loginWithGoogle();
      await entered.future;
      await h.login('A');
      final ended = Completer<void>();
      void observe() {
        if (!h.session.isAuthenticated && !ended.isCompleted) ended.complete();
      }

      h.session.addListener(observe);
      addTearDown(() => h.session.removeListener(observe));
      final deletion = h.auth.deleteAccount();
      await ended.future;
      // Wait for storage pair: signOut is now either queued or will fail its
      // execution-time identity check. Neither path may invoke the plugin.
      await SecureStorageService.getAccessToken();
      final b = h.auth.loginWithGoogle();
      release.complete();
      expect(await oldLogin, isFalse);
      expect(await b, isTrue);
      final result = await deletion;
      expect(result.google, LocalCleanupStep.differentSession);
      expect(h.googleEvents, isNot(contains('signOut:start')));
      h.expectOwner('B');
    });

    test('old Google signIn result cannot overwrite newer email login',
        () async {
      final entered = Completer<void>(), release = Completer<void>();
      h.beforeGoogle = (method) async {
        if (method == 'signIn') {
          entered.complete();
          await release.future;
        }
      };
      final old = h.auth.loginWithGoogle();
      await entered.future;
      await h.login('A');
      release.complete();
      expect(await old, isFalse);
      h.expectOwner('A');
      expect(h.requests.where((r) => r.contains('/v1/auth/google')), isEmpty);
      expect(h.auth.errorMessage, isNull);
    });

    test(
        'Google cancellation remains quiet and failed queue permits next login',
        () async {
      h.cancelGoogle = true;
      expect(await h.auth.loginWithGoogle(), isFalse);
      expect(h.auth.errorMessage, isNull);
      h.cancelGoogle = false;
      h.googleFailures.add('signIn');
      expect(await h.auth.loginWithGoogle(), isFalse);
      h.googleFailures.clear();
      expect(await h.auth.loginWithGoogle(), isTrue);
      h.expectOwner('B');
    });
  });
}

void sessionContractTests() {
  group('KL5 session binding', () {
    late Kl5Harness h;
    setUp(() {
      h = Kl5Harness();
    });
    tearDown(() {
      h.dispose();
    });

    test(
        'reentrant login during RAM reset cannot become the A completion context',
        () async {
      await h.login('A');
      Future<bool>? newerLogin;
      var triggered = false;
      void observe() {
        if (!h.session.isAuthenticated && !triggered) {
          triggered = true;
          newerLogin = h.auth.loginWithGoogle();
        }
      }

      h.session.addListener(observe);
      addTearDown(() => h.session.removeListener(observe));
      final result = await h.auth.deleteAccount();
      expect(await newerLogin!, isTrue);
      expect(result.server, DeletionServerResult.confirmed);
      expect(result.tokens.access, LocalCleanupStep.differentSession);
      expect(result.google, LocalCleanupStep.differentSession);
      expect(h.googleEvents, isNot(contains('signOut:start')));
      h.expectOwner('B');
      expect(h.auth.deletionNotice, isNull);
    });

    test('reentrant newer login keeps its identity and controller action',
        () async {
      Future<bool>? newerLogin;
      var triggered = false;
      final entered = Completer<void>(), release = Completer<void>();
      h.onMain = (request) async {
        if (request.path == '/v1/auth/login') {
          entered.complete();
          await release.future;
        }
        return h.defaultResponse(request);
      };
      void observe() {
        if (!triggered) {
          triggered = true;
          newerLogin =
              h.auth.loginWithEmail('b@example.invalid', 'synthetic-password');
        }
      }

      h.session.addListener(observe);
      addTearDown(() => h.session.removeListener(observe));
      final old =
          h.auth.loginWithEmail('a@example.invalid', 'synthetic-password');
      await entered.future;
      expect(await old, isFalse);
      expect(h.auth.isLoading, isTrue);
      release.complete();
      expect(await newerLogin!, isTrue);
      h.expectOwner('B');
    });

    for (final outcome in ['200', '401', 'timeout', '500']) {
      for (final newOwner in ['B', 'A']) {
        test(
            'late A $outcome after new $newOwner login preserves the new session',
            () async {
          await h.login('A');
          final oldGeneration = h.session.generation;
          final arrived = Completer<void>();
          final release = Completer<void>();
          h.onMain = (request) async {
            if (request.method != 'DELETE') {
              return h.defaultResponse(request);
            }
            arrived.complete();
            await release.future;
            if (outcome == 'timeout') {
              throw DioException(
                  requestOptions: request,
                  type: DioExceptionType.receiveTimeout);
            }
            return Kl5Harness.json({'status': 'deleted'},
                status: int.parse(outcome));
          };
          final deletion = h.auth.deleteAccount();
          await arrived.future;
          await h.login(newOwner);
          expect(h.session.generation, isNot(oldGeneration));
          release.complete();
          final result = await deletion;
          if (outcome == '200') {
            expect(result.server, DeletionServerResult.confirmed);
          }
          h.expectOwner(newOwner);
          expect(h.auth.isLoading, isFalse);
          expect(h.auth.errorMessage, isNull);
          expect(h.auth.deletionNotice, isNull);
          expect(h.googleEvents, isEmpty);
          expect(h.refreshRequests, isEmpty);
          expect(h.requests.where((r) => r.startsWith('DELETE')).toList(),
              ['DELETE /v1/me A']);
        });
      }
    }

    test('stale dialog operation sends no DELETE', () async {
      await h.login('A');
      final operation = h.auth.prepareAccountDeletion();
      await h.login('B');
      final result = await h.auth.deleteAccount(operation);
      expect(result.server, DeletionServerResult.notSent);
      expect(h.requests.where((r) => r.startsWith('DELETE')), isEmpty);
      h.expectOwner('B');
    });

    test('queued before interceptor dispatch cannot be relabeled as B',
        () async {
      await h.login('A');
      final deletion = h.auth.deleteAccount();
      // fetch captured A synchronously; Dio has not dispatched its interceptor.
      final login =
          h.auth.loginWithEmail('b@example.invalid', 'synthetic-password');
      final result = await deletion;
      await login;
      expect(result.server, DeletionServerResult.notSent);
      expect(h.requests.where((r) => r.startsWith('DELETE')), isEmpty);
      h.expectOwner('B');
    });

    test('repeated confirmation of one operation sends one DELETE', () async {
      await h.login('A');
      final operation = h.auth.prepareAccountDeletion();
      final first = h.auth.deleteAccount(operation);
      final second = h.auth.deleteAccount(operation);
      expect(identical(first, second), isTrue);
      expect((await first).server, DeletionServerResult.confirmed);
      await second;
      expect(h.requests.where((r) => r.startsWith('DELETE')).length, 1);
    });

    test('session changes after initial interceptor check but before transport',
        () async {
      await h.login('A');
      final entered = Completer<void>(), release = Completer<void>();
      final delay = InterceptorsWrapper(onRequest: (request, handler) async {
        if (request.method == 'DELETE') {
          entered.complete();
          await release.future;
        }
        handler.next(request);
      });
      ApiClient().dio.interceptors.add(delay);
      addTearDown(() => ApiClient().dio.interceptors.remove(delay));
      final deletion = h.auth.deleteAccount();
      await entered.future;
      await h.login('B');
      release.complete();
      expect((await deletion).server, DeletionServerResult.notSent);
      expect(h.requests.where((r) => r.startsWith('DELETE')), isEmpty);
      h.expectOwner('B');
    });

    test('disposing controller cannot revoke an eventual server confirmation',
        () async {
      await h.login('A');
      final controller = AuthController();
      final entered = Completer<void>(), release = Completer<void>();
      h.onMain = (request) async {
        entered.complete();
        await release.future;
        return h.defaultResponse(request);
      };
      final deletion = controller.deleteAccount();
      await entered.future;
      controller.dispose();
      release.complete();
      expect((await deletion).server, DeletionServerResult.confirmed);
      expect(h.session.isAuthenticated, isFalse);
    });

    test('late A finally cannot finish an in-flight B login', () async {
      await h.login('A');
      final aArrived = Completer<void>(), aRelease = Completer<void>();
      final bArrived = Completer<void>(), bRelease = Completer<void>();
      h.onMain = (request) async {
        if (request.method == 'DELETE') {
          aArrived.complete();
          await aRelease.future;
        }
        if (request.path == '/v1/auth/login') {
          bArrived.complete();
          await bRelease.future;
        }
        return h.defaultResponse(request);
      };
      final deletion = h.auth.deleteAccount();
      await aArrived.future;
      final login =
          h.auth.loginWithEmail('b@example.invalid', 'synthetic-password');
      await bArrived.future;
      aRelease.complete();
      await deletion;
      expect(h.auth.isLoading, isTrue);
      expect(h.auth.errorMessage, isNull);
      bRelease.complete();
      expect(await login, isTrue);
      h.expectOwner('B');
    });

    test('older concurrent login cannot overwrite a newer login', () async {
      final arrived = Completer<void>(), release = Completer<void>();
      h.onMain = (request) async {
        if (request.path == '/v1/auth/login' &&
            request.data['email'] == 'a@example.invalid') {
          arrived.complete();
          await release.future;
        }
        return h.defaultResponse(request);
      };
      final a =
          h.auth.loginWithEmail('a@example.invalid', 'synthetic-password');
      await arrived.future;
      await h.login('B');
      release.complete();
      expect(await a, isFalse);
      h.expectOwner('B');
      expect(h.auth.errorMessage, isNull);
    });

    test('late refreshProfile cannot replace B profile', () async {
      await h.login('A');
      final arrived = Completer<void>(), release = Completer<void>();
      h.onMain = (request) async {
        if (request.path == '/v1/me' && Kl5Harness.owner(request) == 'A') {
          arrived.complete();
          await release.future;
        }
        return h.defaultResponse(request);
      };
      final profile = h.repository.refreshProfile();
      final checked =
          expectLater(profile, throwsA(isA<StaleSessionException>()));
      await arrived.future;
      await h.login('B');
      release.complete();
      await checked;
      h.expectOwner('B');
    });
  });
}
