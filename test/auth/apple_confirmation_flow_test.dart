import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:emie/api/client.dart';
import 'package:emie/data/auth/apple_confirmation_models.dart';
import 'package:emie/features/auth/controller/auth_controller.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import 'package:emie/features/chat/presentation/widgets/authenticated_chat_scope.dart';
import 'package:emie/features/memory/presentation/screens/memory_screen.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'account_deletion_session_test.dart' show Kl5Harness;

const prefix = '/v1/auth/apple/confirmations';
const appleChannel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
final nonce = ''.padRight(43, 'n');
final state = ''.padRight(43, 's');
const tokenMarker = 'SYNTHETIC_IDENTITY_TOKEN_ONLY';
const codeMarker = 'NEVER_COPY_AUTHORIZATION_CODE';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Kl5Harness h;
  late List<RequestOptions> requests;
  late List<MethodCall> nativeCalls;
  late int number;
  Future<Map<String, dynamic>?> Function(MethodCall)? native;
  Future<ResponseBody> Function(RequestOptions)? server;
  String currentId() => number.toRadixString(16).padLeft(32, '0');
  Map<String, dynamic> credential(MethodCall call) => {
    'type': 'appleid',
    'userIdentifier': 'synthetic-subject', 'givenName': null, 'familyName': null,
    'email': null, 'identityToken': tokenMarker, 'authorizationCode': codeMarker,
    'state': (call.arguments as List).single['state'],
  };
  setUp(() async {
    h = Kl5Harness();
    requests = []; nativeCalls = []; number = 0; native = null; server = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await h.login('A');
    h.requests.clear(); h.storage.events.clear(); h.googleEvents.clear();
    h.onMain = (request) async {
      if (!request.path.startsWith(prefix)) return h.defaultResponse(request);
      requests.add(request);
      if (server != null) return server!(request);
      if (request.path == prefix) {
        number++;
        return Kl5Harness.json({'id': currentId(), 'nonce': nonce, 'state': state,
          'expires_at': '2030-01-01T00:05:00Z'}, status: 201);
      }
      return Kl5Harness.json({'id': currentId(),
        'status': request.path.endsWith('/cancel') ? 'cancelled' : 'confirmed'});
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appleChannel, (call) async {
      nativeCalls.add(call);
      expect(call.method, 'performAuthorizationRequest');
      return native == null ? credential(call) : await native!(call);
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appleChannel, null);
    debugDefaultTargetPlatformOverride = null;
    h.dispose();
  });

  void unchanged(int generation, Object? user, Map<String, String> stored) {
    expect(h.session.generation, generation);
    expect(h.session.user, same(user));
    expect(h.storage.values, stored);
    expect(h.storage.events, isEmpty);
    expect(h.refreshRequests, isEmpty);
    expect(h.googleEvents, isEmpty);
    h.expectOwner('A');
  }

  test('KL6.2 actual chain and MethodChannel keep nonce state scopes and session', () async {
    final generation = h.session.generation, user = h.session.user;
    final stored = Map<String, String>.from(h.storage.values);
    var notifications = 0;
    void listener() { notifications++; }
    h.session.addListener(listener);
    addTearDown(() => h.session.removeListener(listener));
    final result = await h.auth.confirmAppleAccount();
    expect(result.outcome, AppleConfirmationOutcome.confirmed);
    expect(result.operationId, currentId());
    expect(requests.map((r) => '${r.method} ${r.path}'), ['POST $prefix', 'POST $prefix/${currentId()}/complete']);
    final sent = (nativeCalls.single.arguments as List).single as Map;
    expect(sent['nonce'], nonce); expect(sent['state'], state); expect(sent['scopes'], isEmpty);
    expect(requests.last.data, {'id_token': tokenMarker, 'state': state});
    for (final request in requests) {
      expect(request.extra[ApiClient.sessionKey], generation);
      expect(request.extra[ApiClient.noRefreshKey], isTrue);
      expect(request.responseType, ResponseType.plain);
      expect(request.receiveDataWhenStatusError, isFalse);
      expect(request.headers['Authorization'], 'Bearer synthetic-A');
    }
    expect(notifications, 0);
    unchanged(generation, user, stored);
  });

  test('KL6.2 native cancellation sends one cancel and no login or storage change', () async {
    final generation = h.session.generation, user = h.session.user;
    final stored = Map<String, String>.from(h.storage.values);
    native = (_) async => throw PlatformException(code: 'authorization-error/canceled');
    final result = await h.auth.confirmAppleAccount();
    expect(result.outcome, AppleConfirmationOutcome.cancelled);
    expect(requests.map((r) => r.path), [prefix, '$prefix/${currentId()}/cancel']);
    unchanged(generation, user, stored);
  });

  for (final returned in [null, '', 'wrong']) {
    test('KL6.2 invalid returned state $returned sends no complete', () async {
      native = (call) async => {...credential(call), 'state': returned};
      expect((await h.auth.confirmAppleAccount()).outcome, AppleConfirmationOutcome.invalidProof);
      expect(requests.length, 1); expect(h.storage.events, isEmpty);
    });
  }

  test('KL6.2 unsupported platform invokes neither API nor native channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect((await h.auth.confirmAppleAccount()).outcome, AppleConfirmationOutcome.notAvailable);
    expect(requests, isEmpty); expect(nativeCalls, isEmpty); expect(h.storage.events, isEmpty);
  });

  for (final owner in ['B', 'A']) {
    for (final phase in ['begin', 'native', 'complete']) {
      test('KL6.2 $owner replaces session during $phase and discards old return', () async {
        final arrived = Completer<void>(), release = Completer<void>();
        if (phase == 'native') {
          native = (call) async { arrived.complete(); await release.future; return credential(call); };
        } else {
          server = (request) async {
            if ((phase == 'begin' && request.path == prefix) || request.path.endsWith('/complete')) {
              arrived.complete(); await release.future;
            }
            if (request.path == prefix) {
              number++;
              return Kl5Harness.json({'id': currentId(), 'nonce': nonce, 'state': state,
                'expires_at': '2030-01-01T00:05:00Z'}, status: 201);
            }
            return Kl5Harness.json({'id': currentId(), 'status': 'confirmed'});
          };
        }
        final pending = h.auth.confirmAppleAccount();
        await arrived.future;
        await h.login(owner);
        final generation = h.session.generation;
        release.complete();
        expect((await pending).outcome, AppleConfirmationOutcome.stale);
        expect(h.session.generation, generation); h.expectOwner(owner);
        expect(requests.every((r) => r.headers['Authorization']=='Bearer synthetic-A'), isTrue);
        expect(requests.length, phase == 'complete' ? 2 : 1);
        expect(h.refreshRequests, isEmpty);
      });
    }
  }

  test('KL6.2 disposed controller discards native return without cancel under another context', () async {
    final controller = AuthController(repository: h.repository);
    final arrived = Completer<void>(), release = Completer<void>();
    native = (call) async { arrived.complete(); await release.future; return credential(call); };
    final pending = controller.confirmAppleAccount();
    await arrived.future;
    controller.dispose(); release.complete();
    expect((await pending).outcome, AppleConfirmationOutcome.stale);
    expect(requests.length, 1); h.expectOwner('A'); expect(h.storage.events, isEmpty);
  });

  for (final switchSession in [false, true]) {
    test('KL6.2 last transport boundary rejects ${switchSession ? 'generation' : 'object'} replacement', () async {
      final arrived = Completer<void>(), release = Completer<void>();
      final dio = ApiClient().dio, original = ApiClient().dio.transformer;
      var first = true;
      dio.transformer = _DelayedTransformer(original, () async {
        if (first) { first = false; arrived.complete(); await release.future; }
      });
      addTearDown(() => dio.transformer = original);
      final pending = h.auth.confirmAppleAccount();
      await arrived.future;
      if (switchSession) {
        await h.login('B');
      } else {
        expect((await h.auth.confirmAppleAccount()).outcome, AppleConfirmationOutcome.confirmed);
      }
      final sent = requests.length;
      release.complete();
      expect((await pending).outcome, AppleConfirmationOutcome.stale);
      await Future<void>.delayed(Duration.zero);
      expect(requests.length, sent);
      expect(h.refreshRequests, isEmpty);
    });
  }

  for (final status in [401, 409, 503]) {
    test('KL6.2 malformed HTTP $status keeps status and never refreshes or replays', () async {
      final generation = h.session.generation, user = h.session.user;
      final stored = Map<String, String>.from(h.storage.values);
      server = (_) async => ResponseBody.fromBytes([0xff, 0xfe, 0x7b], status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
      final result = await h.auth.confirmAppleAccount();
      expect(result.outcome, status==401 ? AppleConfirmationOutcome.authenticationRejected :
          status==409 ? AppleConfirmationOutcome.conflict : AppleConfirmationOutcome.unconfirmed);
      expect(requests.length, 1); expect(nativeCalls, isEmpty);
      unchanged(generation, user, stored);
    });
  }

  for (final action in ['complete', 'cancel']) {
    for (final status in ['confirmed', 'cancelled', 'pending', 'missing', 'broken']) {
      test('KL6.2 lost $action acknowledgement has exactly one status lookup: $status', () async {
        if (action=='cancel') native = (_) async => throw PlatformException(code: 'authorization-error/canceled');
        server = (request) async {
          if (request.path == prefix) {
            number++;
            return Kl5Harness.json({'id': currentId(), 'nonce': nonce, 'state': state,
              'expires_at': '2030-01-01T00:05:00Z'}, status: 201);
          }
          if (request.method == 'POST') {
            throw DioException(requestOptions: request, type: DioExceptionType.receiveTimeout);
          }
          return status=='missing' ? Kl5Harness.json({}, status: 404) : status=='broken'
              ? ResponseBody.fromString('{broken', 200)
              : Kl5Harness.json({'id': currentId(), 'status': status});
        };
        final result = await h.auth.confirmAppleAccount();
        final expected = status=='confirmed' ? AppleConfirmationOutcome.confirmed :
            status=='cancelled' ? AppleConfirmationOutcome.cancelled :
            status=='missing' ? AppleConfirmationOutcome.notAvailable : AppleConfirmationOutcome.unconfirmed;
        expect(result.outcome, expected);
        expect(requests.map((r)=>r.method), ['POST', 'POST', 'GET']);
        expect(h.refreshRequests, isEmpty); expect(h.storage.events, isEmpty); h.expectOwner('A');
      });
    }
  }

  test('KL6.2 lost begin response cannot recover a challenge or issue status requests', () async {
    server = (request) async => throw DioException(requestOptions: request, type: DioExceptionType.receiveTimeout);
    expect((await h.auth.confirmAppleAccount()).outcome, AppleConfirmationOutcome.unconfirmed);
    expect(requests.length, 1); expect(nativeCalls, isEmpty); h.expectOwner('A');
  });

  for (final action in ['complete', 'cancel']) {
    for (final status in [401, 409, 503]) {
      test('KL6.2 malformed $action $status retains status and limits lookup', () async {
        if (action=='cancel') native = (_) async => throw PlatformException(code: 'authorization-error/canceled');
        server = (request) async {
          if (request.path==prefix) {
            number++;
            return Kl5Harness.json({'id': currentId(), 'nonce': nonce, 'state': state,
              'expires_at': '2030-01-01T00:05:00Z'}, status: 201);
          }
          if (request.method=='GET') return Kl5Harness.json({'id': currentId(), 'status': 'pending'});
          return ResponseBody.fromBytes([0xff, 0xfe], status,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
        };
        final result = await h.auth.confirmAppleAccount();
        expect(result.outcome, status==401 ? AppleConfirmationOutcome.authenticationRejected :
            status==409 ? AppleConfirmationOutcome.conflict : AppleConfirmationOutcome.unconfirmed);
        expect(requests.map((r)=>r.method), status==503 ? ['POST','POST','GET'] : ['POST','POST']);
        expect(h.refreshRequests, isEmpty); expect(h.storage.events, isEmpty); h.expectOwner('A');
      });
    }
  }

  test('KL6.2 missing native identity token has no complete request', () async {
    native = (call) async => {...credential(call), 'identityToken': null};
    expect((await h.auth.confirmAppleAccount()).outcome, AppleConfirmationOutcome.invalidProof);
    expect(requests.length, 1); expect(h.storage.events, isEmpty); h.expectOwner('A');
  });

  test('KL6.2 authorization code is absent from HTTP storage results and actual logs', () async {
    final logs = <String>[], previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) { if (message != null) logs.add(message); };
    addTearDown(() => debugPrint = previous);
    final result = await h.auth.confirmAppleAccount();
    expect(result.outcome, AppleConfirmationOutcome.confirmed);
    expect(jsonEncode(requests.map((r)=>r.data).toList()), isNot(contains(codeMarker)));
    expect(jsonEncode(h.storage.values), isNot(contains(codeMarker)));
    expect(result.toString(), isNot(contains(codeMarker)));
    expect(logs.join(), isNot(contains(codeMarker)));
    expect(logs.join(), isNot(contains(tokenMarker)));
  });

  for (final outcome in ['confirmed', 'cancelled', 'error']) {
  testWidgets('KL6.2 $outcome preserves actual chat scope and memory screen cache', (tester) async {
    if (outcome!='confirmed') {
      native = (_) async => throw PlatformException(code: outcome=='cancelled'
          ? 'authorization-error/canceled' : 'authorization-error/failed');
    }
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<SessionStore>.value(value: h.session,
      child: AuthenticatedChatScope(session: h.session,
        child: const MaterialApp(home: MemoryScreen()))));
    await tester.pumpAndSettle();
    final memory = tester.state(find.byType(MemoryScreen));
    final chat = tester.element(find.byType(MemoryScreen)).read<ChatController>();
    final loaded = h.requests.where((r)=>r.contains('/v1/memory/list')).length;
    final result = await tester.runAsync(h.auth.confirmAppleAccount);
    await tester.pumpAndSettle();
    expect(result?.outcome, outcome=='confirmed' ? AppleConfirmationOutcome.confirmed :
        outcome=='cancelled' ? AppleConfirmationOutcome.cancelled : AppleConfirmationOutcome.notAvailable);
    expect(tester.state(find.byType(MemoryScreen)), same(memory));
    expect(tester.element(find.byType(MemoryScreen)).read<ChatController>(), same(chat));
    expect(h.requests.where((r)=>r.contains('/v1/memory/list')).length, loaded);
    expect(h.storage.events, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });
  }
}

class _DelayedTransformer extends Transformer {
  _DelayedTransformer(this.delegate, this.delay);
  final Transformer delegate;
  final Future<void> Function() delay;
  @override
  Future<String> transformRequest(RequestOptions options) async {
    await delay();
    return delegate.transformRequest(options);
  }
  @override
  Future<dynamic> transformResponse(RequestOptions options, ResponseBody response) =>
      delegate.transformResponse(options, response);
}
