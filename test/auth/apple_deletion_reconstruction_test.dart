// Reconstruction 2026-09-26. Transport doubles; no native/Apple live evidence.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:emie/features/auth/controller/auth_controller.dart';
import 'package:emie/data/auth/auth_api.dart';
import 'package:emie/data/auth/auth_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_deletion_session_test.dart' show Kl5Harness;

const channel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');
const prefix = '/v1/me/apple-deletion';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Kl5Harness h;
  late AuthController controller;
  late DateTime now, expiry;
  Future<ResponseBody> Function(RequestOptions)? completionResponse;
  late String nonce, state, id;
  late int completions;
  Future<Object?> Function(MethodCall)? native;
  Completer<void>? requestStarted;
  Completer<void>? releaseComplete;

  Map<String, Object?> credential() => {
    'type': 'appleid', 'userIdentifier': 'synthetic-subject',
    'givenName': null, 'familyName': null, 'email': null,
    'identityToken': 'synthetic-ephemeral-token',
    'authorizationCode': 'synthetic-ephemeral-code', 'state': state,
  };

  setUp(() async {
    h = Kl5Harness();
    await h.login('A');
    now = DateTime.utc(2026, 9, 27, 12);
    expiry = now.add(const Duration(minutes: 5));
    controller = AuthController(repository: h.repository, confirmationNow: () => now);
    completionResponse = null;
    nonce = ''.padRight(43, 'n');
    state = ''.padRight(43, 's');
    id = ''.padRight(32, 'a');
    completions = 0;
    native = null;
    requestStarted = null;
    releaseComplete = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    h.requests.clear();
    h.storage.events.clear();
    h.onMain = (request) async {
      if (request.path == '/v1/me' && request.method == 'DELETE') {
        return Kl5Harness.json({'ok': false, 'code': 'apple_deletion_required'}, status: 409);
      }
      if (request.path == prefix) {
        return Kl5Harness.json({'id': id, 'nonce': nonce, 'state': state,
          'expires_at': expiry.toIso8601String()}, status: 201);
      }
      if (request.path == '$prefix/$id/complete') {
        completions++;
        requestStarted?.complete();
        if (releaseComplete != null) await releaseComplete!.future;
        if (completionResponse != null) return completionResponse!(request);
        return Kl5Harness.json({'status': 'deleted', 'apple_revocation': 'pending'});
      }
      if (request.path == '$prefix/$id/cancel') {
        return Kl5Harness.json({'id': id, 'status': 'cancelled'});
      }
      return h.defaultResponse(request);
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => native == null ? credential() : await native!(call));
  });

  tearDown(() {
    expect(jsonEncode(h.storage.values).contains('synthetic-ephemeral'), isFalse);
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    controller.dispose();
    h.dispose();
  });

  test('settings deletion operation follows required Apple flow once', () async {
    final operation = controller.prepareAccountDeletion();
    final first = controller.deleteAccount(operation);
    final second = controller.deleteAccount(operation);
    expect(identical(first, second), isTrue);
    final result = await first;
    expect(result.server, DeletionServerResult.applePending);
    expect(result.message('de'), contains('noch nicht bestätigt'));
    expect(completions, 1);
    expect(h.session.isAuthenticated, isFalse);
    expect(h.refreshRequests, isEmpty);
  });

  test('native cancellation retains account and never completes deletion', () async {
    native = (_) async => throw PlatformException(code: 'authorization-error/canceled');
    final result = await controller.deleteAccount();
    expect(result.server, DeletionServerResult.notSent);
    expect(completions, 0);
    h.expectOwner('A');
  });

  test('account switch while native dialog waits discards A credentials', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    native = (_) async {
      started.complete();
      await release.future;
      return credential();
    };
    final deletion = controller.deleteAccount();
    await started.future;
    await h.login('B');
    release.complete();
    await deletion;
    expect(completions, 0);
    h.expectOwner('B');
    expect(controller.deletionNotice, isNull);
  });

  test('late server completion for A cannot clear B tokens or UI', () async {
    requestStarted = Completer<void>();
    releaseComplete = Completer<void>();
    final deletion = controller.deleteAccount();
    await requestStarted!.future;
    await h.login('B');
    releaseComplete!.complete();
    await deletion;
    h.expectOwner('B');
    expect(controller.deletionNotice, isNull);
    expect(completions, 1);
  });

  test('R1-F1 same session sent before deadline late reply remains visible uncertainty', () async {
    requestStarted = Completer<void>();
    releaseComplete = Completer<void>();
    final operation = controller.prepareAccountDeletion();
    final deletion = controller.deleteAccount(operation);
    await requestStarted!.future;
    now = expiry.add(const Duration(seconds: 1));
    releaseComplete!.complete();
    final result = await deletion;
    expect(result.server, DeletionServerResult.unconfirmed);
    expect(result.sessionEnd, LocalSessionEnd.unchanged);
    expect(controller.deletionNotice?.server, DeletionServerResult.unconfirmed);
    h.expectOwner('A');
    await controller.deleteAccount(operation);
    expect(completions, 1);
    expect(h.refreshRequests, isEmpty);
  });

  for (final failure in [DioExceptionType.connectionError, DioExceptionType.cancel]) {
    test('R1-F1 post-dispatch ${failure.name} never claims notSent for A', () async {
      requestStarted = Completer<void>();
      releaseComplete = Completer<void>();
      completionResponse = (request) async =>
          throw DioException(requestOptions: request, type: failure);
      final operation = controller.prepareAccountDeletion();
      final deletion = controller.deleteAccount(operation);
      await requestStarted!.future;
      now = expiry.add(const Duration(seconds: 1));
      releaseComplete!.complete();
      final result = await deletion;
      expect(result.server, DeletionServerResult.unconfirmed);
      expect(result.sessionEnd, LocalSessionEnd.unchanged);
      expect(controller.deletionNotice?.server, DeletionServerResult.unconfirmed);
      h.expectOwner('A');
      await controller.deleteAccount(operation);
      expect(completions, 1);
      expect(h.refreshRequests, isEmpty);
    });
  }

  test('R1-F1 expired before dispatch retains strict proof deadline', () async {
    native = (_) async {
      now = expiry;
      return credential();
    };
    final result = await controller.deleteAccount();
    expect(result.server, DeletionServerResult.appleProofRejected);
    expect(completions, 0);
    h.expectOwner('A');
  });

  test('backend-generated HTTP fixtures drive the exact Flutter parser', () {
    final path = Platform.environment['EMIE_APPLE_CONTRACT_FILE'];
    expect(path, isNotNull, reason: 'Requires real output of run_apple_deletion_reconstruction.py unit <new.json>');
    final fixture = jsonDecode(File(path!).readAsStringSync()) as Map<String, dynamic>;
    expect(fixture['origin'], 'actual synthetic HTTP responses');
    expect((fixture['sources'] as Map).isNotEmpty, isTrue);
    final responses = fixture['responses'] as List;
    expect(responses.length, greaterThanOrEqualTo(5));
    for (final item in responses.cast<Map<String, dynamic>>()) {
      expect(AuthApi.parseDeletionReply(item['status'] as int, item['body']).name,
          item['expected'], reason: item['id'] as String);
    }
  });
}
