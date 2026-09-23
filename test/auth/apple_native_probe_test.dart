import 'dart:async';
import 'dart:convert';

import 'package:emie/data/auth/apple_code_binding_native.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/apple_native_probe/evaluation.dart';
import '../../tool/apple_native_probe/main.dart';

String segment(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
String token(Object? payload) =>
    '${segment(utf8.encode('{}'))}.${segment(utf8.encode(jsonEncode(payload)))}.c2ln';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const state = 'SENTINEL_STATE';
  const code = 'SENTINEL_CODE';
  ProbeEvaluation evaluate(String? jwt,
          {String? returned = state, String? authCode = code}) =>
      evaluateProbe(
          identityToken: jwt,
          authorizationCode: authCode,
          returnedState: returned,
          expectedState: state);

  test('payload observations are unverified fixed states', () {
    final r = evaluate(token({
      'c_hash': 'SENTINEL_HASH',
      'sub': 'SENTINEL_SUB',
      'email': 'SENTINEL_EMAIL',
      'name': 'SENTINEL_NAME'
    }));
    expect(r.response, ProbeResponse.received);
    expect(r.tokenPresent, isTrue);
    expect(r.codePresent, isTrue);
    expect(r.state, ProbeState.matching);
    expect(r.token, ProbeToken.readable);
    expect(r.cHash, ProbeCHash.stringPresent);
    expect(r.toString(), contains(probeDisclaimer));
    expect(r.toString(), isNot(contains('SENTINEL')));
    expect(r.toString(), isNot(contains('VERIFIED')));
    expect(r.toString(), isNot(contains('confirmed')));
    expect(r.toString(), isNot(contains('Login erfolgreich')));
  });

  test('missing, empty and non-string c_hash remain separate observations', () {
    for (final pair in <(Object?, ProbeCHash)>[
      ({}, ProbeCHash.missing),
      ({'c_hash': ''}, ProbeCHash.empty),
      ({'c_hash': null}, ProbeCHash.invalidType),
      ({'c_hash': 1}, ProbeCHash.invalidType),
      ({'c_hash': []}, ProbeCHash.invalidType),
      ({'c_hash': {}}, ProbeCHash.invalidType),
      ({'c_hash': false}, ProbeCHash.invalidType),
    ]) {
      expect(evaluate(token(pair.$1)).cHash, pair.$2);
    }
  });

  test('missing token or code is observable without authorization claims', () {
    for (final jwt in [null, '']) {
      final r = evaluate(jwt);
      expect(r.tokenPresent, isFalse);
      expect(r.token, ProbeToken.notExamined);
    }
    for (final authCode in [null, '']) {
      final r = evaluate(token({}), authCode: authCode);
      expect(r.codePresent, isFalse);
      expect(r.cHash, ProbeCHash.missing);
    }
  });

  test('missing and mismatching state prohibit payload interpretation', () {
    for (final returned in [null, '', 'WRONG']) {
      final r =
          evaluate(token({'c_hash': 'SENTINEL_HASH'}), returned: returned);
      expect(r.state,
          returned == 'WRONG' ? ProbeState.mismatching : ProbeState.missing);
      expect(r.token, ProbeToken.notExamined);
      expect(r.cHash, ProbeCHash.notExamined);
    }
    expect(
        evaluateProbe(
                identityToken: token({}),
                authorizationCode: code,
                returnedState: state,
                expectedState: '')
            .state,
        ProbeState.mismatching);
  });

  test('bounds, base64url, UTF8, JSON and payload shape are enforced', () {
    final invalid = [
      'SENTINEL_TOKEN', 'a.b', 'a.b.c.d', 'e30.***.c2ln', 'e30..c2ln',
      'e30.${segment([255])}.c2ln',
      'e30.${segment(utf8.encode('{SENTINEL_INVALID_JSON'))}.c2ln',
      token([]), token('SENTINEL_STRING'), token(null), token(7),
      token({'c_hash': 'x' * 9000}), 'x' * 16385,
      'e30.e31.c2ln', // Noncanonical trailing base64 bits.
    ];
    for (final jwt in invalid) {
      final r = evaluate(jwt);
      expect(r.token, ProbeToken.unreadable);
      expect(r.cHash, ProbeCHash.notExamined);
      expect(r.toString(), isNot(contains('SENTINEL')));
    }
  });

  test('cancellation and credential-bearing errors are redacted and not logged',
      () {
    final logs = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      runZoned(() {
        final error = PlatformException(
            code: 'SENTINEL_CODE',
            message: 'SENTINEL_TOKEN SENTINEL_EMAIL',
            details: {'sub': 'SENTINEL_SUB'});
        expect(probeFailure(error).response, ProbeResponse.error);
        expect(probeFailure(error, cancelled: true).response,
            ProbeResponse.cancelled);
        expect(probeFailure(error).toString(), isNot(contains('SENTINEL')));
        evaluate(token({'c_hash': 'SENTINEL_HASH'}));
      },
          zoneSpecification:
              ZoneSpecification(print: (_, __, ___, line) => logs.add(line)));
      expect(logs, isEmpty);
    } finally {
      debugPrint = previous;
    }
  });

  test('configuration gates require explicit iOS debug', () {
    for (final debug in [false, true]) {
      for (final enabled in [false, true]) {
        expect(
            probeGate(
                debug: debug,
                enabled: enabled,
                web: false,
                platform: TargetPlatform.iOS),
            debug && enabled ? ProbeGate.ready : ProbeGate.disabled);
      }
    }
    expect(
        probeGate(
            debug: true,
            enabled: true,
            web: true,
            platform: TargetPlatform.iOS),
        ProbeGate.unsupported);
    for (final platform
        in TargetPlatform.values.where((p) => p != TargetPlatform.iOS)) {
      expect(
          probeGate(debug: true, enabled: true, web: false, platform: platform),
          ProbeGate.unsupported);
    }
    expect(
        requestProbe(),
        const bool.fromEnvironment('EMIE_APPLE_NATIVE_PROBE')
            ? ProbeGate.unsupported
            : ProbeGate.disabled); // Host platform.
  });

  testWidgets(
      'construction, repeated direct callbacks and dispose never call native',
      (tester) async {
    final calls = <MethodCall>[];
    const channel =
        MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw StateError('Native call prohibited');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const AppleNativeProbeApp());
    expect(
        find.text('Apple-Diagnose – keine Anmeldung bei Emie'), findsOneWidget);
    expect(find.text(probeDisclaimer), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    requestProbe();
    requestProbe();
    await tester.pump(const Duration(minutes: 3));
    await tester.pumpWidget(const SizedBox());
    requestProbe();
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test(
      'actual adapter refuses unauthenticated diagnostic context before native dispatch',
      () async {
    final session = SessionStore.instance;
    expect(session.isAuthenticated, isFalse);
    final generation = session.generation;
    var notifications = 0;
    void changed() => notifications++;
    session.addListener(changed);
    final adapter = AppleCodeBindingNative();
    const channel =
        MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
    var nativeCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async {
      nativeCalls++;
      throw StateError('Native call prohibited');
    });
    try {
      final r = await adapter.request(
          nonce: 'SYNTHETIC_NONCE',
          state: state,
          operation: AppleCodeBindingOperation(originGeneration: generation));
      expect(r.status, AppleCodeBindingNativeStatus.stale);
      expect(r.pair, isNull);
      expect(nativeCalls, 0);
      expect(session.generation, generation);
      expect(notifications, 0);
    } finally {
      adapter.dispose();
      session.removeListener(changed);
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
}
