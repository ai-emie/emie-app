import 'dart:async';

import 'package:emie/data/auth/apple_code_binding_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_deletion_session_test.dart' show Kl5Harness;

const _channel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
const _nonce = 'synthetic-NONCE_%2F';
const _state = 'synthetic-STATE_%2F';
const _token = 'SENSITIVE_KL63_TOKEN_MARKER';
const _code = 'SENSITIVE_KL63_CODE_MARKER';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Kl5Harness h;
  late AppleCodeBindingNative adapter;
  late List<MethodCall> calls;
  late List<String> output;
  late int generation;
  late Object? user;
  late String? access;
  late String? refresh;
  late Map<String, String> stored;
  late int notifications;
  late VoidCallback listener;
  late DebugPrintCallback previousDebugPrint;
  Future<Map<String, dynamic>?> Function(MethodCall)? native;

  Map<String, dynamic> credential(MethodCall call) => {
        'type': 'appleid',
        'userIdentifier': 'synthetic-subject',
        'givenName': 'SENSITIVE_NAME_MARKER',
        'familyName': null,
        'email': 'synthetic@example.invalid',
        'identityToken': _token,
        'authorizationCode': _code,
        'state': (call.arguments as List).single['state'],
      };

  AppleCodeBindingOperation operation() =>
      AppleCodeBindingOperation(originGeneration: h.session.generation);

  Future<AppleCodeBindingNativeResult> request(
          {AppleCodeBindingOperation? context,
          String nonce = _nonce,
          String state = _state}) =>
      runZoned(
        () => adapter.request(
            nonce: nonce, state: state, operation: context ?? operation()),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => output.add(line),
        ),
      );

  void snapshot() {
    generation = h.session.generation;
    user = h.session.user;
    access = h.session.accessToken;
    refresh = h.session.refreshToken;
    stored = Map<String, String>.from(h.storage.values);
    h.requests.clear();
    h.refreshRequests.clear();
    h.storage.events.clear();
    h.googleEvents.clear();
    notifications = 0;
    h.onMain = (_) async => throw StateError('Unexpected HTTP action');
  }

  setUp(() async {
    h = Kl5Harness();
    adapter = AppleCodeBindingNative();
    calls = [];
    output = [];
    native = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await h.login('A');
    snapshot();
    listener = () => notifications++;
    h.session.addListener(listener);
    previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) output.add(message);
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      expect(call.method, 'performAuthorizationRequest');
      return native == null ? credential(call) : await native!(call);
    });
  });

  tearDown(() {
    expect(h.session.generation, generation);
    expect(h.session.user, same(user));
    expect(h.session.accessToken == access, isTrue);
    expect(h.session.refreshToken == refresh, isTrue);
    expect(mapEquals(h.storage.values, stored), isTrue);
    expect(h.storage.events, isEmpty);
    expect(h.requests, isEmpty);
    expect(h.refreshRequests, isEmpty);
    expect(h.googleEvents, isEmpty);
    expect(notifications, 0);
    expect(
        output.any((line) => [
              _token,
              _code,
              _nonce,
              _state,
              'SENSITIVE_NAME_MARKER'
            ].any(line.contains)),
        isFalse,
        reason: 'Credential content in actual output');
    adapter.dispose();
    h.session.removeListener(listener);
    debugPrint = previousDebugPrint;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
    h.dispose();
  });

  void neutral(AppleCodeBindingNativeResult result,
      AppleCodeBindingNativeStatus status) {
    expect(result.status, status);
    expect(result.pair, isNull);
    expect(result.toString().contains('MARKER'), isFalse);
  }

  test(
      'KL6.3 exact native arguments and one-response pair without side effects',
      () async {
    final result = await request();
    expect(result.status, AppleCodeBindingNativeStatus.received);
    final sent = (calls.single.arguments as List).single as Map;
    expect(sent['nonce'] == _nonce, isTrue);
    expect(sent['state'] == _state, isTrue);
    expect(sent['scopes'], isEmpty);
    final pair = result.pair!;
    expect(pair.identityToken == _token, isTrue);
    expect(pair.authorizationCode == _code, isTrue);
    expect(pair.state == _state, isTrue);
    expect(pair.toString(), 'AppleCodeBindingPair(<redacted>)');
    expect(result.toString(), 'AppleCodeBindingNativeResult(received)');
    expect(operation().toString(), 'AppleCodeBindingOperation(<local>)');
    pair.release();
    expect(pair.identityToken, isNull);
    expect(pair.authorizationCode, isNull);
    expect(pair.state, isNull);
  });

  test('KL6.3 sequential native replies never mix token and code', () async {
    final first = await request();
    native = (call) async => credential(call)
      ..['identityToken'] = '${_token}_second'
      ..['authorizationCode'] = '${_code}_second';
    final second = await request();
    expect(first.pair!.identityToken == _token, isTrue);
    expect(first.pair!.authorizationCode == _code, isTrue);
    expect(second.pair!.identityToken == '${_token}_second', isTrue);
    expect(second.pair!.authorizationCode == '${_code}_second', isTrue);
    expect(calls, hasLength(2));
    first.pair!.release();
    second.pair!.release();
  });

  for (final field in ['identityToken', 'authorizationCode', 'state']) {
    for (final missing in [true, false]) {
      test('KL6.3 missing or empty response $field $missing', () async {
        native = (call) async {
          final response = credential(call);
          if (missing) {
            response.remove(field);
          } else {
            response[field] = '';
          }
          return response;
        };
        neutral(await request(), AppleCodeBindingNativeStatus.invalidResponse);
      });
    }
  }

  test('KL6.3 state comparison is exact and never normalized', () async {
    native = (call) async => credential(call)..['state'] = _state.toLowerCase();
    neutral(await request(), AppleCodeBindingNativeStatus.stateMismatch);
  });

  for (final entry in {
    'authorization-error/canceled': AppleCodeBindingNativeStatus.cancelled,
    'authorization-error/failed': AppleCodeBindingNativeStatus.pluginFailure,
    'authorization-error/invalidResponse':
        AppleCodeBindingNativeStatus.invalidResponse,
    'unknown-synthetic': AppleCodeBindingNativeStatus.pluginFailure,
    'not-supported': AppleCodeBindingNativeStatus.unsupported,
  }.entries) {
    test('KL6.3 neutral plugin outcome ${entry.key}', () async {
      native = (_) async => throw PlatformException(
          code: entry.key, message: _token, details: _code);
      neutral(await request(), entry.value);
    });
  }

  test('KL6.3 malformed plugin response is a neutral plugin failure', () async {
    native = (call) async => credential(call)..['identityToken'] = 42;
    neutral(await request(), AppleCodeBindingNativeStatus.pluginFailure);
  });

  test('KL6.3 null plugin response is a neutral plugin failure', () async {
    native = (_) async => null;
    neutral(await request(), AppleCodeBindingNativeStatus.pluginFailure);
  });

  test('KL6.3 second parallel operation opens no second native dialog',
      () async {
    final entered = Completer<void>();
    final reply = Completer<Map<String, dynamic>>();
    native = (_) {
      entered.complete();
      return reply.future;
    };
    final firstOperation = operation();
    final secondOperation = operation();
    final pending = request(context: firstOperation);
    await entered.future;
    neutral(await request(context: secondOperation),
        AppleCodeBindingNativeStatus.busy);
    expect(calls, hasLength(1));
    reply.complete(credential(calls.single));
    final result = await pending;
    expect(result.status, AppleCodeBindingNativeStatus.received);
    result.pair!.release();
    neutral(await request(context: firstOperation),
        AppleCodeBindingNativeStatus.stale);
    native = null;
    final next = await request(context: secondOperation);
    expect(next.status, AppleCodeBindingNativeStatus.received);
    next.pair!.release();
  });

  for (final owner in ['B', 'A']) {
    for (final error in [false, true]) {
      test('KL6.3 late response preserves new $owner session error $error',
          () async {
        final entered = Completer<void>();
        final reply = Completer<Map<String, dynamic>>();
        native = (_) {
          entered.complete();
          return reply.future;
        };
        final pending = request();
        await entered.future;
        h.onMain = null;
        await h.login(owner);
        expect(h.session.generation, greaterThan(generation));
        snapshot();
        if (error) {
          reply.completeError(PlatformException(
              code: 'authorization-error/canceled', message: _code));
        } else {
          reply.complete(credential(calls.single));
        }
        neutral(await pending, AppleCodeBindingNativeStatus.stale);
        h.expectOwner(owner);
      });
    }
  }

  for (final action in ['cancel', 'operation', 'dispose']) {
    test(
        'KL6.3 local $action rejects late pair and retains pending native slot',
        () async {
      final entered = Completer<void>();
      final reply = Completer<Map<String, dynamic>>();
      native = (_) {
        entered.complete();
        return reply.future;
      };
      final context = operation();
      final pending = request(context: context);
      await entered.future;
      if (action == 'dispose') {
        adapter.dispose();
      } else if (action == 'operation') {
        context.cancel();
      } else {
        adapter.cancel();
      }
      neutral(
          await request(),
          action == 'dispose'
              ? AppleCodeBindingNativeStatus.disposed
              : AppleCodeBindingNativeStatus.busy);
      expect(calls, hasLength(1));
      reply.complete(credential(calls.single));
      neutral(await pending, AppleCodeBindingNativeStatus.stale);
      if (action != 'dispose') {
        native = null;
        final next = await request();
        expect(next.status, AppleCodeBindingNativeStatus.received);
        next.pair!.release();
      }
    });
  }

  test(
      'KL6.3 previously cancelled or foreign-generation operation never starts',
      () async {
    final cancelled = operation()..cancel();
    neutral(
        await request(context: cancelled), AppleCodeBindingNativeStatus.stale);
    neutral(
        await request(
            context:
                AppleCodeBindingOperation(originGeneration: generation - 1)),
        AppleCodeBindingNativeStatus.stale);
    expect(calls, isEmpty);
  });

  test('KL6.3 disposed adapter never starts', () async {
    adapter.dispose();
    neutral(await request(), AppleCodeBindingNativeStatus.disposed);
    expect(calls, isEmpty);
  });

  test('KL6.3 explicit nonempty nonce and state required', () async {
    neutral(
        await request(nonce: ''), AppleCodeBindingNativeStatus.invalidRequest);
    neutral(
        await request(state: ''), AppleCodeBindingNativeStatus.invalidRequest);
    expect(calls, isEmpty);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.linux
  ]) {
    test('KL6.3 unsupported ${platform.name} without native call', () async {
      debugDefaultTargetPlatformOverride = platform;
      neutral(await request(), AppleCodeBindingNativeStatus.unsupported);
      expect(calls, isEmpty);
    });
  }

  test('KL6.3 macOS uses the same installed MethodChannel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final result = await request();
    expect(result.status, AppleCodeBindingNativeStatus.received);
    expect(calls, hasLength(1));
    result.pair!.release();
  });
}
