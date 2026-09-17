import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:emie/api/client.dart';
import 'package:emie/core/storage/secure_storage.dart';
import 'package:emie/data/auth/auth_models.dart';
import 'package:emie/data/auth/auth_repository.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'account_deletion_session_test.dart' show Kl5Harness, FakeTokenStorage;

void repairDeletionTests() {
  test('KL5 repair RED R2: malformed JSON 401 ends only its session', () async {
    final h = Kl5Harness();
    addTearDown(h.dispose);
    await h.login('A');
    final origin = h.session.generation;
    h.requests.clear();
    h.storage.events.clear();
    h.onMain = (request) async {
      expect(request.method, 'DELETE');
      expect(request.path, '/v1/me');
      expect(request.validateStatus(401), isFalse);
      expect(request.responseType, ResponseType.json);
      expect(request.extra[ApiClient.sessionKey], origin);
      return ResponseBody.fromString('{broken', 401, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
    };
    final result = await h.repository.deleteAccount();
    debugPrint('KL5_REPAIR_RED_R2 server=${result.server.name} '
        'end=${result.sessionEnd.name} authenticated=${h.session.isAuthenticated} '
        'userPresent=${h.session.user != null} '
        'storedKeys=${h.storage.values.length} events=${h.storage.events} '
        'requests=${h.requests} autoRefresh=${h.refreshRequests.length}');
    expect(result.server, DeletionServerResult.authenticationRejected);
    expect(result.sessionEnd, LocalSessionEnd.ended);
    expect(result.tokens.access, LocalCleanupStep.confirmed);
    expect(result.tokens.refresh, LocalCleanupStep.confirmed);
    expect(h.session.generation, origin + 1);
    expect(h.session.isAuthenticated, isFalse);
    expect(h.session.accessToken, isNull);
    expect(h.session.refreshToken, isNull);
    expect(h.session.user, isNull);
    expect(h.storage.values, isEmpty);
    expect(h.storage.events, [
      'delete:access:start', 'delete:access:end',
      'delete:refresh:start', 'delete:refresh:end'
    ]);
    expect(h.requests, ['DELETE /v1/me A']);
    expect(h.refreshRequests, isEmpty);
  });
}

void repairDeletionEdgeTests() {
  group('KL5 repair DELETE status', () {
    late Kl5Harness h;
    setUp(() => h = Kl5Harness());
    tearDown(() => h.dispose());

    final bodies = <String, (List<int>, String)>{
      'valid JSON': (utf8.encode('{"code":"UNAUTHORIZED"}'), Headers.jsonContentType),
      'empty': (<int>[], Headers.jsonContentType),
      'text': (utf8.encode('unauthorized'), 'text/plain'),
      'invalid UTF8': ([0xff, 0xfe, 0x7b], Headers.jsonContentType),
    };
    for (final entry in bodies.entries) {
      test('401 ${entry.key} ends A without refresh or replay', () async {
        await h.login('A');
        final origin = h.session.generation;
        h.requests.clear();
        h.storage.events.clear();
        h.onMain = (request) async {
          expect(request.validateStatus(401), isFalse);
          expect(request.receiveDataWhenStatusError, isFalse);
          expect(request.responseType, ResponseType.json);
          return ResponseBody.fromBytes(entry.value.$1, 401, headers: {
            Headers.contentTypeHeader: [entry.value.$2]
          });
        };
        final result = await h.repository.deleteAccount();
        expect(result.server, DeletionServerResult.authenticationRejected);
        expect(result.sessionEnd, LocalSessionEnd.ended);
        expect(result.tokens.access, LocalCleanupStep.confirmed);
        expect(result.tokens.refresh, LocalCleanupStep.confirmed);
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
        expect(h.requests, ['DELETE /v1/me A']);
        expect(h.refreshRequests, isEmpty);
      });
    }

    test('malformed 401 still tries refresh-key removal after access failure',
        () async {
      await h.login('A');
      h.requests.clear();
      h.storage.events.clear();
      h.storage.failures.add('delete:access');
      h.storage.before = (operation, key, _) async {
        if (operation == 'delete') {
          expect(h.session.isAuthenticated, isFalse);
          expect(h.session.user, isNull);
          expect(h.session.accessToken, isNull);
          expect(h.session.refreshToken, isNull);
        }
      };
      h.onMain = (_) async => ResponseBody.fromString('{broken', 401, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
      final result = await h.repository.deleteAccount();
      expect(result.server, DeletionServerResult.authenticationRejected);
      expect(result.sessionEnd, LocalSessionEnd.ended);
      expect(result.tokens.access, LocalCleanupStep.unconfirmed);
      expect(result.tokens.refresh, LocalCleanupStep.confirmed);
      expect(h.storage.values.keys, [FakeTokenStorage.access]);
      expect(h.storage.events, [
        'delete:access:start', 'delete:access:failed',
        'delete:refresh:start', 'delete:refresh:end'
      ]);
      expect(h.requests, ['DELETE /v1/me A']);
      expect(h.refreshRequests, isEmpty);
    });

    test('late malformed A 401 preserves all B state', () async {
      await h.login('A');
      final arrived = Completer<void>();
      final response = Completer<ResponseBody>();
      h.onMain = (request) async {
        if (request.method == 'DELETE') {
          expect(Kl5Harness.owner(request), 'A');
          arrived.complete();
          return response.future;
        }
        return h.defaultResponse(request);
      };
      final pending = h.repository.deleteAccount();
      await arrived.future;
      await h.login('B');
      final generation = h.session.generation;
      final stored = Map<String, String>.from(h.storage.values);
      final events = List<String>.from(h.storage.events);
      response.complete(ResponseBody.fromString('{broken', 401, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      }));
      final result = await pending;
      expect(result.server, DeletionServerResult.authenticationRejected);
      expect(result.sessionEnd, LocalSessionEnd.differentSession);
      expect(result.tokens.access, LocalCleanupStep.differentSession);
      expect(result.tokens.refresh, LocalCleanupStep.differentSession);
      expect(h.session.generation, generation);
      h.expectOwner('B');
      expect(h.storage.values, stored);
      expect(h.storage.events, events);
      expect(h.requests.where((r) => r.startsWith('DELETE')),
          ['DELETE /v1/me A']);
      expect(h.refreshRequests, isEmpty);
      expect(h.googleEvents, isEmpty);
    });

    test('no response cannot infer 401 from exception text', () async {
      await h.login('A');
      h.requests.clear();
      h.storage.events.clear();
      h.onMain = (_) async => throw const FormatException('401 unauthorized');
      final result = await h.repository.deleteAccount();
      expect(result.server, DeletionServerResult.unconfirmed);
      expect(result.sessionEnd, LocalSessionEnd.unchanged);
      h.expectOwner('A');
      expect(h.storage.events, isEmpty);
      expect(h.requests, ['DELETE /v1/me A']);
      expect(h.refreshRequests, isEmpty);
    });
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  repairDeletionTests();
  repairDeletionEdgeTests();
  deletionContractTests();
  test('KL5 RED A: status ok cannot end the session or remove credentials',
      () async {
    final session = SessionStore.instance;
    FlutterSecureStorage.setMockInitialValues({});
    session.clear();
    session.finishBootstrap();
    session.updateTokens('synthetic-A', refresh: 'synthetic-refresh-A');
    session.updateUser(const UserProfile(id: 'A', email: 'a@example.invalid'));
    await SecureStorageService.saveTokens(
        accessToken: 'synthetic-A', refreshToken: 'synthetic-refresh-A');
    final dio = ApiClient().dio;
    final original = dio.httpClientAdapter;
    var deletes = 0;
    dio.httpClientAdapter = _Adapter((request) async {
      expect(request.method, 'DELETE');
      expect(request.path, '/v1/me');
      deletes++;
      return ResponseBody.fromString(jsonEncode({'status': 'ok'}), 200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    });
    addTearDown(() {
      dio.httpClientAdapter = original;
      session.clear();
    });
    await AuthRepository().deleteAccount();
    final accessPresent = await SecureStorageService.getAccessToken() != null;
    final refreshPresent = await SecureStorageService.getRefreshToken() != null;
    debugPrint(
        'KL5_RED_A deletes=$deletes authenticated=${session.isAuthenticated} accessPresent=$accessPresent refreshPresent=$refreshPresent');
    expect(deletes, 1);
    expect(session.isAuthenticated, isTrue);
    expect(session.user?.id, 'A');
    expect(accessPresent, isTrue);
    expect(refreshPresent, isTrue);
  });
}

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

void deletionContractTests() {
  group('KL5 deletion contract', () {
    late Kl5Harness h;
    setUp(() {
      h = Kl5Harness();
    });
    tearDown(() {
      h.dispose();
    });
    final responses = <String, (int, Object?)>{
      '200 deleted': (200, {'status': 'deleted'}),
      '200 ok': (200, {'status': 'ok'}),
      '200 empty object': (200, <String, dynamic>{}),
      '200 null': (200, null),
      '200 list': (200, ['deleted']),
      '200 JSON string': (200, 'deleted'),
      '200 nonexact value': (200, {'status': 'Deleted'}),
      '202 deleted': (202, {'status': 'deleted'}),
      '204 deleted': (204, {'status': 'deleted'}),
      '400 rejected': (400, {'detail': 'synthetic'}),
      '401 rejected': (401, {'code': 'UNAUTHORIZED'}),
      '403 rejected': (403, {}),
      '404 rejected': (404, {}),
      '409 rejected': (409, {}),
      '422 rejected': (422, {}),
      '429 rejected': (429, {}),
      '500 unclear': (500, {}),
      '503 unclear': (503, {}),
    };
    for (final entry in responses.entries) {
      test('response ${entry.key}', () async {
        await h.login('A');
        h.onMain = (_) async =>
            Kl5Harness.json(entry.value.$2, status: entry.value.$1);
        final result = await h.auth.deleteAccount();
        final expected = entry.key == '200 deleted'
            ? DeletionServerResult.confirmed
            : entry.value.$1 == 401
                ? DeletionServerResult.authenticationRejected
                : DeletionServerResult.unconfirmed;
        expect(result.server, expected);
        expect(h.refreshRequests, isEmpty);
        expect(h.requests.where((r) => r.startsWith('DELETE')).toList(),
            ['DELETE /v1/me A']);
        if (expected == DeletionServerResult.unconfirmed) {
          expect(result.sessionEnd, LocalSessionEnd.unchanged);
          expect(result.tokens.access, LocalCleanupStep.notRequired);
          h.expectOwner('A');
          expect(h.googleEvents, isEmpty);
        } else {
          expect(result.sessionEnd, LocalSessionEnd.ended);
          expect(h.session.isAuthenticated, isFalse);
          expect(h.session.user, isNull);
          expect(h.storage.values, isEmpty);
          expect(result.tokens.access, LocalCleanupStep.confirmed);
          expect(result.tokens.refresh, LocalCleanupStep.confirmed);
          expect(result.google, LocalCleanupStep.confirmed);
        }
      });
    }
    for (final body in ['', '{broken', 'deleted']) {
      test('empty or damaged JSON ${body.isEmpty ? 'empty' : body}', () async {
        await h.login('A');
        h.onMain = (_) async => ResponseBody.fromString(body, 200, headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
        final result = await h.auth.deleteAccount();
        expect(result.server, DeletionServerResult.unconfirmed);
        h.expectOwner('A');
      });
    }
    test('plain text deleted is not a JSON confirmation', () async {
      await h.login('A');
      h.onMain = (_) async => ResponseBody.fromString('deleted', 200, headers: {
            Headers.contentTypeHeader: ['text/plain']
          });
      expect((await h.auth.deleteAccount()).server,
          DeletionServerResult.unconfirmed);
      h.expectOwner('A');
    });
    for (final kind in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.cancel
    ]) {
      test('unconfirmed ${kind.name} preserves local session', () async {
        await h.login('A');
        h.onMain = (request) async =>
            throw DioException(requestOptions: request, type: kind);
        expect((await h.auth.deleteAccount()).server,
            DeletionServerResult.unconfirmed);
        h.expectOwner('A');
        expect(h.refreshRequests, isEmpty);
      });
    }
    test('simulated server effect followed by lost response is not confirmed',
        () async {
      await h.login('A');
      var simulatedEffect = false;
      h.onMain = (request) async {
        simulatedEffect = true; // Adapter evidence only, never a DB commit.
        throw DioException(
            requestOptions: request, type: DioExceptionType.receiveTimeout);
      };
      final result = await h.auth.deleteAccount();
      expect(simulatedEffect, isTrue);
      expect(result.server, DeletionServerResult.unconfirmed);
      h.expectOwner('A');
    });
    for (final failed in [
      {'delete:access'},
      {'delete:refresh'},
      {'delete:access', 'delete:refresh'}
    ]) {
      test('independent cleanup failures ${failed.join('+')}', () async {
        await h.login('A');
        h.storage.failures.addAll(failed);
        final result = await h.auth.deleteAccount();
        expect(result.server, DeletionServerResult.confirmed);
        expect(result.sessionEnd, LocalSessionEnd.ended);
        expect(h.session.isAuthenticated, isFalse);
        expect(h.session.accessToken, isNull);
        expect(h.session.refreshToken, isNull);
        expect(
            result.tokens.access,
            failed.contains('delete:access')
                ? LocalCleanupStep.unconfirmed
                : LocalCleanupStep.confirmed);
        expect(
            result.tokens.refresh,
            failed.contains('delete:refresh')
                ? LocalCleanupStep.unconfirmed
                : LocalCleanupStep.confirmed);
        expect(
            h.storage.events
                .where((e) => e.startsWith('delete:') && e.endsWith(':start'))
                .toList(),
            ['delete:access:start', 'delete:refresh:start']);
        expect(h.storage.events, isNot(contains('deleteAll')));
        expect(h.storage.values.containsKey(FakeTokenStorage.access),
            failed.contains('delete:access'));
        expect(h.storage.values.containsKey(FakeTokenStorage.refresh),
            failed.contains('delete:refresh'));
        expect(h.auth.deletionNotice!.message('de'),
            contains('gespeicherten Zugangsdaten'));
      });
    }
    test('RAM ends before the first storage operation completes', () async {
      await h.login('A');
      final entered = Completer<void>(), release = Completer<void>();
      h.storage.before = (operation, key, _) async {
        if (operation == 'delete' && key == FakeTokenStorage.access) {
          entered.complete();
          await release.future;
        }
      };
      final deletion = h.auth.deleteAccount();
      await entered.future;
      expect(h.session.isAuthenticated, isFalse);
      expect(h.session.user, isNull);
      expect(h.session.accessToken, isNull);
      release.complete();
      expect((await deletion).server, DeletionServerResult.confirmed);
    });
    test('Google failure cannot change confirmed deletion', () async {
      await h.login('A');
      h.googleFailures.add('signOut');
      final result = await h.auth.deleteAccount();
      expect(result.server, DeletionServerResult.confirmed);
      expect(result.google, LocalCleanupStep.unconfirmed);
      expect(h.session.isAuthenticated, isFalse);
      expect(h.auth.deletionNotice!.message('de'),
          contains('lokale Google-Abmeldung'));
      expect(h.auth.errorMessage, isNull);
    });
    test('already ended origin retains its completion context', () async {
      await h.login('A');
      final entered = Completer<void>(), release = Completer<void>();
      h.onMain = (request) async {
        entered.complete();
        await release.future;
        return h.defaultResponse(request);
      };
      final origin = h.session.generation;
      final deletion = h.auth.deleteAccount();
      await entered.future;
      h.session.endSession(origin);
      release.complete();
      final result = await deletion;
      expect(result.server, DeletionServerResult.confirmed);
      expect(result.sessionEnd, LocalSessionEnd.alreadyEnded);
      expect(result.tokens.access, LocalCleanupStep.confirmed);
      expect(h.auth.deletionNotice, isNotNull);
    });
  });
}
