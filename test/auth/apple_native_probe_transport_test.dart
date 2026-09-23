import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/apple_native_probe/main.dart';
import '../../tool/apple_native_probe/transport.dart';
import '../../tool/apple_native_probe/evaluation.dart';

const enabled = bool.fromEnvironment('EMIE_APPLE_NATIVE_PROBE');
const channel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
String jwt(Object payload) {
  String enc(Object x) =>
      base64Url.encode(utf8.encode(jsonEncode(x))).replaceAll('=', '');
  return '${enc({})}.${enc(payload)}.c2ln';
}

Map<String, Object?> reply(MethodCall call) => {
      'type': 'appleid',
      'userIdentifier': 'SENTINEL_USER',
      'givenName': 'SENTINEL_NAME',
      'familyName': 'SENTINEL_FAMILY',
      'email': 'SENTINEL_EMAIL',
      'identityToken': jwt({'c_hash': 'SENTINEL_HASH'}),
      'authorizationCode': 'SENTINEL_CODE',
      'state': (call.arguments as List).single['state'],
    };

void probeTest(String name, WidgetTesterCallback body, {bool skip = false}) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: skip);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Future<Object?> Function(MethodCall) response;
  setUp(() {
    calls = [];
    response = (call) async => reply(call);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return response(call);
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  probeTest(
      'actual flag gate: construction silent, conscious start uses plugin boundary',
      (tester) async {
    await tester.pumpWidget(const AppleNativeProbeApp());
    expect(calls, isEmpty);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed != null, enabled);
    if (enabled) {
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(calls.length, 1);
      final strings = tester
          .widgetList<Text>(find.byType(Text))
          .map((x) => x.data ?? '')
          .join();
      expect(strings.contains('SENTINEL'), isFalse);
      expect(strings.contains('stringPresent'), isTrue);
      final args = (calls.single.arguments as List).single as Map;
      expect(strings.contains(args['state'] as String), isFalse);
      expect(strings.contains(args['nonce'] as String), isFalse);
    } else {
      final controller = ProbeController();
      controller.start();
      await tester.pump();
      expect(controller.phase, ProbePhase.blocked);
      expect(calls, isEmpty);
      controller.dispose();
    }
    await tester.pumpWidget(const SizedBox());
  });

  probeTest('actual platform guard blocks direct start', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = ProbeController();
    controller.start();
    await tester.pump();
    expect(calls, isEmpty);
    controller.dispose();
  });

  probeTest(
      'real random parameters are independent fresh 32-byte URL-safe values',
      (tester) async {
    final controller = ProbeController();
    for (var n = 0; n < 2; n++) {
      controller.start();
      await tester.pump();
      expect(controller.result?.cHash, ProbeCHash.stringPresent);
    }
    final values = <String>{};
    for (final call in calls) {
      expect(call.method, 'performAuthorizationRequest');
      final args = (call.arguments as List).single as Map;
      expect(args['scopes'], isEmpty);
      for (final key in ['state', 'nonce']) {
        final value = args[key] as String;
        expect(RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value), isTrue);
        expect(base64Url.decode(base64Url.normalize(value)).length, 32);
        values.add(value);
        expect(controller.result.toString().contains(value), isFalse);
      }
    }
    expect(calls.length, 2);
    expect(values.length, 4);
    controller.dispose();
  }, skip: !enabled);

  probeTest('secure random failure is redacted without native call or fallback',
      (tester) async {
    Random fail() => throw StateError('SENTINEL_RANDOM');
    final controller = ProbeController.withRandomSource(fail);
    controller.start();
    await tester.pump();
    expect(calls, isEmpty);
    expect(controller.result?.response, ProbeResponse.error);
    expect(controller.result.toString().contains('SENTINEL'), isFalse);
    controller.dispose();
  }, skip: !enabled);

  probeTest(
      'plugin replies retain only observations for missing and malformed fields',
      (tester) async {
    final controller = ProbeController();
    for (final state in [null, 'WRONG']) {
      response = (call) async => reply(call)..['state'] = state;
      controller.start();
      await tester.pump();
      expect(controller.result?.response, ProbeResponse.error);
      expect(controller.result?.cHash, ProbeCHash.notExamined);
    }
    for (final payload in [
      {},
      {'c_hash': ''},
      {'c_hash': 7}
    ]) {
      response = (call) async => reply(call)..['identityToken'] = jwt(payload);
      controller.start();
      await tester.pump();
      expect(controller.result?.token, ProbeToken.readable);
      expect(
          controller.result?.cHash,
          payload.isEmpty
              ? ProbeCHash.missing
              : payload['c_hash'] == ''
                  ? ProbeCHash.empty
                  : ProbeCHash.invalidType);
    }
    for (final field in ['identityToken', 'authorizationCode']) {
      response = (call) async => reply(call)..[field] = '';
      controller.start();
      await tester.pump();
      expect(
          field == 'identityToken'
              ? controller.result?.tokenPresent
              : controller.result?.codePresent,
          isFalse);
    }
    for (final malformed in ['SENTINEL_BAD', 'x' * 16385]) {
      response = (call) async => reply(call)..['identityToken'] = malformed;
      controller.start();
      await tester.pump();
      expect(controller.result?.token, ProbeToken.unreadable);
    }
    controller.dispose();
  }, skip: !enabled);

  probeTest('cancel and sensitive plugin error are fixed states without logs',
      (tester) async {
    final logs = <String>[];
    final oldPrint = debugPrint;
    debugPrint = (text, {wrapWidth}) {
      if (text != null) logs.add(text);
    };
    final controller = ProbeController();
    try {
      await runZoned(() async {
        for (final code in ['authorization-error/canceled', 'SENTINEL_ERROR']) {
          response = (_) async => throw PlatformException(
              code: code,
              message: 'SENTINEL_TOKEN SENTINEL_CODE SENTINEL_EMAIL');
          controller.start();
          await tester.pump();
          expect(
              controller.result?.response,
              code.endsWith('canceled')
                  ? ProbeResponse.cancelled
                  : ProbeResponse.error);
          expect(controller.result.toString().contains('SENTINEL'), isFalse);
        }
      },
          zoneSpecification: ZoneSpecification(
              print: (_, __, ___, message) => logs.add(message)));
      expect(logs, isEmpty);
    } finally {
      debugPrint = oldPrint;
      controller.dispose();
    }
  }, skip: !enabled);

  for (final lateError in [false, true]) {
    probeTest(
        'timeout/dispose lock survives rebuild; late error=$lateError is discarded',
        (tester) async {
      final pending = Completer<Object?>();
      response = (_) => pending.future;
      final first = ProbeController();
      first.start();
      first.start();
      await tester.pump();
      expect(calls.length, 1);
      await tester.pump(ProbeController.timeout);
      expect(first.phase, ProbePhase.timedOut);
      expect(first.result, isNull);
      first.start();
      expect(calls.length, 1);
      first.dispose();
      final second = ProbeController();
      second.start();
      await tester.pump();
      expect(calls.length, 1);
      expect(second.nativePending, isTrue);
      if (lateError) {
        pending.completeError(PlatformException(code: 'SENTINEL_LATE'));
      } else {
        pending.complete(reply(calls.single));
      }
      await tester.pump();
      expect(second.result, isNull);
      expect(first.result, isNull);
      expect(second.nativePending, isFalse);
      expect(tester.takeException(), isNull);
      response = (call) async => reply(call);
      second.start();
      await tester.pump();
      expect(calls.length, 2);
      expect(second.result?.cHash, ProbeCHash.stringPresent);
      second.dispose();
    }, skip: !enabled);
  }

  probeTest('dispose before timeout discards pending success', (tester) async {
    final pending = Completer<Object?>();
    response = (_) => pending.future;
    final first = ProbeController();
    first.start();
    await tester.pump();
    first.dispose();
    final second = ProbeController();
    second.start();
    await tester.pump();
    expect(calls.length, 1);
    pending.complete(reply(calls.single));
    await tester.pump();
    expect(first.result, isNull);
    expect(second.result, isNull);
    second.dispose();
  }, skip: !enabled);
}
