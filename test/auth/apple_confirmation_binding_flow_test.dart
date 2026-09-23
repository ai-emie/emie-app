import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:emie/api/client.dart';
import 'package:emie/data/auth/apple_code_binding_native.dart';
import 'package:emie/data/auth/apple_confirmation_models.dart';
import 'package:emie/data/auth/auth_api.dart';
import 'package:emie/data/auth/auth_models.dart';
import 'package:emie/features/auth/controller/auth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_deletion_session_test.dart' show Kl5Harness;

const _prefix = '/v1/auth/apple/confirmations';
const _channel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
const _token = 'SENSITIVE_BINDING_TOKEN_%2F';
const _code = 'SENSITIVE_BINDING_CODE_%2F!';
final _nonce = ''.padRight(43, 'n');
final _state = ''.padRight(43, 's');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Kl5Harness h;
  late AuthController controller;
  late _ObservedNative adapter;
  late DateTime now;
  late DateTime expiry;
  late int serial;
  late bool controllerDisposed;
  late List<RequestOptions> requests;
  late List<MethodCall> nativeCalls;
  late List<String> output;
  late DebugPrintCallback previousPrint;
  Future<Map<String, dynamic>?> Function(MethodCall)? native;
  Future<ResponseBody> Function(RequestOptions, Map<String, dynamic>?)? server;
  String id() => serial.toRadixString(16).padLeft(32, '0');
  Map<String, dynamic> credential(MethodCall call) => {
        'type': 'appleid',
        'userIdentifier': 'synthetic-subject',
        'givenName': null,
        'familyName': null,
        'email': null,
        'identityToken': _token,
        'authorizationCode': _code,
        'state': (call.arguments as List).single['state'],
      };
  Iterable<RequestOptions> completes() =>
      requests.where((r) => r.path.endsWith('/complete'));
  Future<AppleConfirmationResult> invoke() =>
      runZoned(controller.confirmAppleAccount,
          zoneSpecification: ZoneSpecification(
              print: (self, parent, zone, text) => output.add(text)));

  setUp(() async {
    h = Kl5Harness();
    await h.login('A');
    h.requests.clear();
    h.storage.events.clear();
    h.googleEvents.clear();
    adapter = _ObservedNative();
    controllerDisposed = false;
    now = DateTime.utc(2026, 9, 23, 12);
    expiry = now.add(const Duration(seconds: 300));
    controller = AuthController(
        repository: h.repository,
        confirmationNative: adapter,
        confirmationNow: () => now);
    requests = [];
    nativeCalls = [];
    output = [];
    serial = 0;
    native = null;
    server = null;
    previousPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) output.add(message);
    };
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    ApiClient().dio.httpClientAdapter = _Wire((request, body) async {
      requests.add(request);
      if (!request.path.startsWith(_prefix)) return h.defaultResponse(request);
      expect(request.headers['Authorization'] == 'Bearer synthetic-A', isTrue);
      expect(request.extra[ApiClient.noRefreshKey], isTrue);
      expect(request.followRedirects, isFalse);
      if (server != null) return server!(request, body);
      if (request.path == _prefix) {
        serial++;
        return Kl5Harness.json({
          'id': id(),
          'nonce': _nonce,
          'state': _state,
          'expires_at': expiry.toIso8601String()
        }, status: 201);
      }
      if (request.path.endsWith('/complete')) {
        expect(body?.keys.toSet(), {'id_token', 'state', 'authorization_code'});
        expect(body?['id_token'] == _token, isTrue);
        expect(body?['authorization_code'] == _code, isTrue);
        expect(body?['state'] == _state, isTrue);
        return Kl5Harness.json({'id': id(), 'status': 'confirmed'});
      }
      if (request.path.endsWith('/cancel')) {
        return Kl5Harness.json({'id': id(), 'status': 'cancelled'});
      }
      throw StateError('Unexpected confirmation transport');
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      nativeCalls.add(call);
      return native == null ? credential(call) : await native!(call);
    });
  });

  tearDown(() {
    for (final pair in adapter.pairs) {
      expect(pair.identityToken, isNull);
      expect(pair.authorizationCode, isNull);
      expect(pair.state, isNull);
    }
    expect(output.any((text) => text.contains(_token) || text.contains(_code)),
        isFalse,
        reason: 'Sensitive sentinel in captured output');
    expect(jsonEncode(h.storage.values).contains('SENSITIVE_BINDING'), isFalse);
    expect(
        requests
            .where((r) => r.path.endsWith('/complete'))
            .every((r) => r.data == null),
        isTrue);
    if (!controllerDisposed) controller.dispose();
    debugPrint = previousPrint;
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    h.dispose();
  });

  Future<ResponseBody> beginOr(RequestOptions request,
      FutureOr<ResponseBody> Function() complete) async {
    if (request.path == _prefix) {
      serial++;
      return Kl5Harness.json({
        'id': id(),
        'nonce': _nonce,
        'state': _state,
        'expires_at': expiry.toIso8601String()
      }, status: 201);
    }
    return complete();
  }

  test(
      'binding actual controller adapter and wire serialization complete once without session writes',
      () async {
    final generation = h.session.generation, user = h.session.user;
    final storage = Map<String, String>.from(h.storage.values);
    var notifications = 0;
    void listen() {
      notifications++;
    }

    h.session.addListener(listen);
    addTearDown(() => h.session.removeListener(listen));
    final result = await invoke();
    expect(result.outcome, AppleConfirmationOutcome.confirmed);
    expect(result.operationId, id());
    expect(result.completionMayHaveOccurred, isFalse);
    expect(completes(), hasLength(1));
    expect(requests.map((r) => '${r.method} ${r.path}'),
        ['POST $_prefix', 'POST $_prefix/${id()}/complete']);
    final args = (nativeCalls.single.arguments as List).single as Map;
    expect(args['nonce'] == _nonce && args['state'] == _state, isTrue);
    expect(args['scopes'], isEmpty);
    expect(h.session.generation, generation);
    expect(h.session.user, same(user));
    expect(h.storage.values, storage);
    expect(h.storage.events, isEmpty);
    expect(h.refreshRequests, isEmpty);
    expect(h.googleEvents, isEmpty);
    expect(notifications, 0);
  });

  final invalid = <Object?>[
    null,
    '',
    '   ',
    '\t\n',
    'with space',
    'with\nnewline',
    'é',
    42,
    true,
    <Object?>[],
    <String, Object?>{}
  ];
  for (final field in ['identityToken', 'authorizationCode']) {
    final cases = field == 'identityToken'
        ? <Object?>[null, '', '   ', 42, ''.padRight(16385, 'x')]
        : [...invalid, ''.padRight(4097, 'x')];
    for (var i = 0; i < cases.length; i++) {
      test('binding invalid native $field case $i sends no complete', () async {
        native = (call) async => credential(call)..[field] = cases[i];
        final result = await invoke();
        expect(result.outcome, isNot(AppleConfirmationOutcome.confirmed));
        expect(completes(), isEmpty);
        expect(h.storage.events, isEmpty);
      });
    }
    test('binding missing native $field sends no complete', () async {
      native = (call) async => credential(call)..remove(field);
      expect(
          (await invoke()).outcome, isNot(AppleConfirmationOutcome.confirmed));
      expect(completes(), isEmpty);
    });
  }

  test('binding valid input bounds are transmitted unchanged', () async {
    final token = ''.padRight(16384, 't'), code = ''.padRight(4096, '!');
    native = (call) async => credential(call)
      ..['identityToken'] = token
      ..['authorizationCode'] = code;
    server = (request, body) => beginOr(request, () {
          expect(
              body?['id_token'] == token && body?['authorization_code'] == code,
              isTrue);
          return Kl5Harness.json({'id': id(), 'status': 'confirmed'});
        });
    expect((await invoke()).outcome, AppleConfirmationOutcome.confirmed);
  });

  test('binding legacy body without code rejected at actual API boundary',
      () async {
    final operation =
        AppleConfirmationOperation(h.session.generation, now: () => now)
          ..serverId = ''.padLeft(32, 'a')
          ..nonce = _nonce
          ..state = _state
          ..expiresAt = expiry;
    final reply = await AuthApi().appleConfirmation(
        operation, 'POST', '/${operation.serverId}/complete',
        data: {'id_token': _token, 'state': _state}, isCurrent: () => true);
    expect(reply.statusCode, 422);
    expect(requests, isEmpty);
    expect(nativeCalls, isEmpty);
  });

  test('binding mismatched native state sends no complete', () async {
    native = (call) async => credential(call)..['state'] = 'wrong';
    expect((await invoke()).outcome, AppleConfirmationOutcome.invalidProof);
    expect(completes(), isEmpty);
  });

  test('binding native cancellation sends no complete and releases slot',
      () async {
    native = (_) async => throw PlatformException(
        code: 'authorization-error/canceled', message: _token, details: _code);
    expect((await invoke()).outcome, AppleConfirmationOutcome.cancelled);
    expect(completes(), isEmpty);
    native = null;
    expect((await invoke()).outcome, AppleConfirmationOutcome.confirmed);
    expect(nativeCalls, hasLength(2));
  });

  test('binding expired challenge never opens native dialog', () async {
    expiry = now;
    expect((await invoke()).outcome, AppleConfirmationOutcome.expired);
    expect(nativeCalls, isEmpty);
    expect(completes(), isEmpty);
  });

  final failures = <(int, String, AppleConfirmationOutcome)>[
    (
      409,
      'apple_code_binding_not_demonstrable',
      AppleConfirmationOutcome.codeNotDemonstrable
    ),
    (400, 'apple_code_binding_invalid', AppleConfirmationOutcome.codeInvalid),
    (
      503,
      'apple_code_binding_unavailable',
      AppleConfirmationOutcome.codeUnavailable
    ),
    (422, 'VALIDATION_ERROR', AppleConfirmationOutcome.validationRejected),
    (404, 'NOT_FOUND', AppleConfirmationOutcome.notAvailable),
    (409, 'CONFLICT', AppleConfirmationOutcome.conflict),
    (409, 'apple_code_binding_invalid', AppleConfirmationOutcome.conflict),
    (400, 'INVALID_PROOF', AppleConfirmationOutcome.invalidProof),
    (401, 'UNAUTHORIZED', AppleConfirmationOutcome.authenticationRejected),
    (503, 'UNCONFIRMED', AppleConfirmationOutcome.unconfirmed),
  ];
  for (final entry in failures) {
    test(
        'binding status and code ${entry.$1} ${entry.$2} remain distinct and redacted',
        () async {
      server = (request, body) => beginOr(
          request,
          () => Kl5Harness.json({
                'ok': false,
                'code': entry.$2,
                'message': _token,
                'detail': _code
              }, status: entry.$1));
      final result = await invoke();
      expect(result.outcome, entry.$3);
      expect(result.toString().contains('SENSITIVE_BINDING'), isFalse);
      expect(result.completionMayHaveOccurred,
          entry.$3 == AppleConfirmationOutcome.unconfirmed);
      expect(completes(), hasLength(1));
      expect(requests, hasLength(2));
      expect(h.refreshRequests, isEmpty);
      expect(h.storage.events, isEmpty);
    });
  }

  for (var index = 0; index < 7; index++) {
    test(
        'binding unusable acknowledgement $index cannot confirm or trigger lookup/retry',
        () async {
      server = (request, body) => beginOr(request, () {
            final bodies = [
              <String, dynamic>{},
              {'id': id(), 'status': 'cancelled'},
              {'id': ''.padLeft(32, 'f'), 'status': 'confirmed'},
              {'id': id(), 'status': 'confirmed', 'detail': _code},
              {'id': id(), 'status': 'confirmed'},
              {'id': id(), 'status': 'confirmed'}
            ];
            if (index == 6) {
              return ResponseBody.fromString('$_token {broken $_code', 200);
            }
            return Kl5Harness.json(bodies[index],
                status: index == 4
                    ? 201
                    : index == 5
                        ? 307
                        : 200);
          });
      final result = await invoke();
      expect(result.outcome, AppleConfirmationOutcome.unconfirmed);
      expect(result.completionMayHaveOccurred, isTrue);
      expect(result.toString().contains('SENSITIVE_BINDING'), isFalse);
      expect(completes(), hasLength(1));
      expect(requests, hasLength(2));
    });
  }

  for (final type in [
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError
  ]) {
    test('binding $type after send remains unknown without refresh or replay',
        () async {
      server = (request, body) => beginOr(
          request,
          () => throw DioException(
              requestOptions: request,
              type: type,
              message: _token,
              error: StateError(_code)));
      final result = await invoke();
      expect(result.outcome, AppleConfirmationOutcome.unconfirmed);
      expect(result.completionMayHaveOccurred, isTrue);
      expect(result.toString().contains('SENSITIVE_BINDING'), isFalse);
      expect(completes(), hasLength(1));
      expect(requests, hasLength(2));
      expect(h.refreshRequests, isEmpty);
      expect(h.storage.events, isEmpty);
    });
  }

  for (final phase in ['begin', 'native', 'complete']) {
    test(
        'binding concurrent calls during $phase cannot open a second operation',
        () async {
      final entered = Completer<void>(), release = Completer<void>();
      if (phase == 'native') {
        native = (call) async {
          entered.complete();
          await release.future;
          return credential(call);
        };
      } else {
        server = (request, body) async {
          if ((phase == 'begin' && request.path == _prefix) ||
              (phase == 'complete' && request.path.endsWith('/complete'))) {
            entered.complete();
            await release.future;
          }
          return beginOr(request,
              () => Kl5Harness.json({'id': id(), 'status': 'confirmed'}));
        };
      }
      final pending = invoke();
      await entered.future;
      expect((await invoke()).outcome, AppleConfirmationOutcome.busy);
      release.complete();
      expect((await pending).outcome, AppleConfirmationOutcome.confirmed);
      expect(nativeCalls, hasLength(1));
      expect(completes(), hasLength(1));
    });
  }

  for (final phase in ['native', 'complete']) {
    for (final change in [
      'logout',
      'account',
      'same-account',
      'cancel',
      'dispose'
    ]) {
      test(
          'binding $change during $phase discards late result without cross-account success',
          () async {
        final entered = Completer<void>(), release = Completer<void>();
        if (phase == 'native') {
          native = (call) async {
            entered.complete();
            await release.future;
            return credential(call);
          };
        } else {
          server = (request, body) => beginOr(request, () async {
                entered.complete();
                await release.future;
                return Kl5Harness.json({'id': id(), 'status': 'confirmed'});
              });
        }
        final pending = invoke();
        await entered.future;
        switch (change) {
          case 'logout':
            await h.auth.logout();
          case 'account':
            await h.login('B');
          case 'same-account':
            await h.login('A');
          case 'cancel':
            controller.cancelAppleConfirmation();
          case 'dispose':
            controller.dispose();
            controllerDisposed = true;
        }
        final generation = h.session.generation;
        final stored = Map<String, String>.from(h.storage.values);
        final events = List<String>.from(h.storage.events);
        release.complete();
        final result = await pending;
        expect(result.outcome, AppleConfirmationOutcome.stale);
        expect(result.completionMayHaveOccurred, phase == 'complete');
        expect(h.session.generation, generation);
        expect(h.storage.values, stored);
        expect(h.storage.events, events);
        expect(completes().length, phase == 'complete' ? 1 : 0);
        if (change != 'dispose') {
          // Explicitly fresh attempts wait until the old native call has ended.
          native = null;
          server = null;
          if (change != 'logout' && change != 'account') {
            expect(
                (await invoke()).outcome, AppleConfirmationOutcome.confirmed);
          }
        }
      });
    }
  }

  for (final phase in ['native', 'complete']) {
    test(
        'binding account identity change without generation advance during $phase is stale',
        () async {
      final entered = Completer<void>(), release = Completer<void>();
      if (phase == 'native') {
        native = (call) async {
          entered.complete();
          await release.future;
          return credential(call);
        };
      } else {
        server = (request, body) => beginOr(request, () async {
              entered.complete();
              await release.future;
              return Kl5Harness.json({'id': id(), 'status': 'confirmed'});
            });
      }
      final generation = h.session.generation;
      final pending = invoke();
      await entered.future;
      h.session
          .updateUser(const UserProfile(id: 'B', email: 'b@example.invalid'));
      release.complete();
      final result = await pending;
      expect(result.outcome, AppleConfirmationOutcome.stale);
      expect(result.completionMayHaveOccurred, phase == 'complete');
      expect(h.session.generation, generation);
      expect(h.session.user?.id, 'B');
      expect(h.storage.events, isEmpty);
      expect(completes().length, phase == 'complete' ? 1 : 0);
    });
  }

  for (final phase in ['native', 'serialization', 'response']) {
    test('binding unchanged deadline rechecked at $phase boundary', () async {
      if (phase == 'native') {
        native = (call) async {
          now = expiry;
          return credential(call);
        };
      } else if (phase == 'serialization') {
        final original = ApiClient().dio.transformer;
        ApiClient().dio.transformer =
            _BeforeSerialize(original, (request) async {
          if (request.path.endsWith('/complete')) now = expiry;
        });
        addTearDown(() => ApiClient().dio.transformer = original);
      } else {
        server = (request, body) => beginOr(request, () {
              now = expiry;
              return Kl5Harness.json({'id': id(), 'status': 'confirmed'});
            });
      }
      final result = await invoke();
      expect(
          result.outcome,
          phase == 'response'
              ? AppleConfirmationOutcome.unconfirmed
              : AppleConfirmationOutcome.expired);
      expect(result.completionMayHaveOccurred, phase == 'response');
      expect(completes().length, phase == 'response' ? 1 : 0);
    });
  }

  test('binding API cannot dispatch a second complete for one operation',
      () async {
    final operation =
        AppleConfirmationOperation(h.session.generation, now: () => now)
          ..serverId = ''.padLeft(32, 'a')
          ..nonce = _nonce
          ..state = _state
          ..expiresAt = expiry;
    final entered = Completer<void>(), release = Completer<void>();
    server = (request, body) async {
      entered.complete();
      await release.future;
      return Kl5Harness.json({'id': operation.serverId, 'status': 'confirmed'});
    };
    Future<AppleConfirmationReply> send() => AuthApi().appleConfirmation(
        operation, 'POST', '/${operation.serverId}/complete',
        data: {
          'id_token': _token,
          'state': _state,
          'authorization_code': _code
        },
        isCurrent: () => true);
    final first = send();
    await entered.future;
    expect((await send()).statusCode, 409);
    release.complete();
    expect((await first).statusCode, 200);
    expect(completes(), hasLength(1));
  });

  for (final field in ['id', 'nonce', 'state', 'expiry']) {
    test(
        'binding changed challenge $field during serialization cannot dispatch',
        () async {
      final operation =
          AppleConfirmationOperation(h.session.generation, now: () => now)
            ..serverId = ''.padLeft(32, 'a')
            ..nonce = _nonce
            ..state = _state
            ..expiresAt = expiry;
      final original = ApiClient().dio.transformer;
      ApiClient().dio.transformer = _BeforeSerialize(original, (_) async {
        switch (field) {
          case 'id':
            operation.serverId = ''.padLeft(32, 'b');
          case 'nonce':
            operation.nonce = ''.padRight(43, 'x');
          case 'state':
            operation.state = ''.padRight(43, 'y');
          case 'expiry':
            operation.expiresAt = expiry.add(const Duration(seconds: 1));
        }
      });
      addTearDown(() => ApiClient().dio.transformer = original);
      final reply = await AuthApi().appleConfirmation(
          operation, 'POST', '/${operation.serverId}/complete',
          data: {
            'id_token': _token,
            'state': _state,
            'authorization_code': _code
          },
          isCurrent: () => true);
      expect(reply.stale, isTrue);
      expect(operation.completeSent, isFalse);
      expect(requests, isEmpty);
    });
  }

  test(
      'binding explicit new attempt obtains a fresh pair instead of reusing prior code',
      () async {
    native = (call) async => credential(call)
      ..['identityToken'] = '$_token${nativeCalls.length}'
      ..['authorizationCode'] = '$_code${nativeCalls.length}';
    var posts = 0;
    server = (request, body) => beginOr(request, () {
          posts++;
          expect(body?['id_token'] == '$_token$posts', isTrue);
          expect(body?['authorization_code'] == '$_code$posts', isTrue);
          return Kl5Harness.json(
              {'ok': false, 'code': 'apple_code_binding_invalid'},
              status: 400);
        });
    expect((await invoke()).outcome, AppleConfirmationOutcome.codeInvalid);
    expect((await invoke()).outcome, AppleConfirmationOutcome.codeInvalid);
    expect(nativeCalls, hasLength(2));
    expect(posts, 2);
    expect(serial, 2);
  });
}

class _ObservedNative extends AppleCodeBindingNative {
  final pairs = <AppleCodeBindingPair>[];
  @override
  Future<AppleCodeBindingNativeResult> request(
      {required String nonce,
      required String state,
      required AppleCodeBindingOperation operation}) async {
    final result =
        await super.request(nonce: nonce, state: state, operation: operation);
    if (result.pair != null) pairs.add(result.pair!);
    return result;
  }
}

class _Wire implements HttpClientAdapter {
  _Wire(this.respond);
  final Future<ResponseBody> Function(RequestOptions, Map<String, dynamic>?)
      respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    Map<String, dynamic>? body;
    if (stream != null) {
      final bytes = await stream.expand((chunk) => chunk).toList();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    }
    return respond(options, body);
  }

  @override
  void close({bool force = false}) {}
}

class _BeforeSerialize extends Transformer {
  _BeforeSerialize(this.delegate, this.before);
  final Transformer delegate;
  final Future<void> Function(RequestOptions) before;
  @override
  Future<String> transformRequest(RequestOptions options) async {
    await before(options);
    return delegate.transformRequest(options);
  }

  @override
  Future<dynamic> transformResponse(
          RequestOptions options, ResponseBody response) =>
      delegate.transformResponse(options, response);
}
