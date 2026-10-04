import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:emie/api/client.dart';
import 'package:emie/app.dart';
import 'package:emie/core/storage/secure_storage.dart';
import 'package:emie/data/auth/auth_models.dart';
import 'package:emie/data/auth/auth_repository.dart';
import 'package:emie/features/auth/controller/auth_controller.dart';
import 'package:emie/features/auth/navigation/recovery_link_controller.dart';
import 'package:emie/features/auth/presentation/screens/auth_screen.dart';
import 'package:emie/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:emie/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:emie/features/auth/presentation/screens/verification_recovery_screen.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Real HTTP prohibited in B1 tests');
}

class _Transport implements HttpClientAdapter {
  _Transport(this.handle);
  final Future<ResponseBody> Function(RequestOptions) handle;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
          Future<void>? cancelFuture) =>
      handle(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody reply([int status = 200, Object body = const {'status': 'ok'}]) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final session = SessionStore.instance;
  final client = ApiClient();
  const proof = 'synthetic_b1_reset_token_abcdefghijklmnopqrstuvwxyz';
  late AuthController auth;
  late AuthRepository repository;
  late HttpClientAdapter oldMain;
  late HttpClientAdapter oldRefresh;
  late HttpOverrides? oldHttp;
  late Future<ResponseBody> Function(RequestOptions) respond;
  late List<RequestOptions> requests;

  setUp(() {
    session.clear();
    FlutterSecureStorage.setMockInitialValues({});
    SecureStorageService.useStorageForTesting(const FlutterSecureStorage());
    oldHttp = HttpOverrides.current;
    HttpOverrides.global = _NoNetwork();
    oldMain = client.dio.httpClientAdapter;
    oldRefresh = client.refreshDio.httpClientAdapter;
    requests = [];
    respond = (_) async => reply();
    client.dio.httpClientAdapter = _Transport((request) {
      requests.add(request);
      return respond(request);
    });
    client.refreshDio.httpClientAdapter = _Transport(
        (_) async => throw StateError('Recovery must never refresh'));
    repository = AuthRepository();
    auth = AuthController(repository: repository);
  });

  tearDown(() {
    auth.dispose();
    client.dio.httpClientAdapter = oldMain;
    client.refreshDio.httpClientAdapter = oldRefresh;
    HttpOverrides.global = oldHttp;
    session.clear();
  });

  Widget host(Widget screen) => MultiProvider(providers: [
        ChangeNotifierProvider<SessionStore>.value(value: session),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ], child: MaterialApp(home: screen));

  Future<void> fillReset(WidgetTester tester,
      {String password = 'new-password', String? confirmation}) async {
    await tester.enterText(
        find.byKey(const ValueKey('reset-password')), password);
    await tester.enterText(find.byKey(const ValueKey('reset-confirmation')),
        confirmation ?? password);
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('B1 forgot validates email and displays neutral acknowledgement',
      (tester) async {
    await tester.pumpWidget(host(const ForgotPasswordScreen()));
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.text('Bitte eine gültige E-Mail-Adresse eingeben.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextFormField), ' UnKnOwN@Example.com ');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(requests.single.path, '/v1/auth/password/reset/start');
    expect(requests.single.data, {'email': 'unknown@example.com'});
    expect(find.textContaining('Wenn ein Account existiert'), findsOneWidget);
  });

  testWidgets('B1 forgot network error uses safe text', (tester) async {
    respond = (request) async => throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
        error: 'SENSITIVE_MARKER');
    await tester.pumpWidget(host(const ForgotPasswordScreen()));
    await tester.enterText(find.byType(TextFormField), 'owner@example.com');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Prüfe deine Verbindung'), findsOneWidget);
    expect(find.textContaining('SENSITIVE_MARKER'), findsNothing);
  });

  testWidgets('B1 reset mismatch and minimum length send no request',
      (tester) async {
    await tester
        .pumpWidget(host(ResetPasswordScreen(token: proof, onDone: () {})));
    await fillReset(tester,
        password: 'new-password', confirmation: 'different');
    expect(find.text('Passwörter stimmen nicht überein.'), findsOneWidget);
    await fillReset(tester, password: 'short');
    expect(find.text('Mindestens 6 Zeichen.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('B1 reset finish sends exact proof and password then returns',
      (tester) async {
    var returned = false;
    await tester.pumpWidget(
        host(ResetPasswordScreen(token: proof, onDone: () => returned = true)));
    await fillReset(tester, password: ' new-password ');
    expect(requests.single.path, '/v1/auth/password/reset/finish');
    expect(requests.single.data,
        {'token': proof, 'new_password': ' new-password '});
    expect(requests.single.extra[ApiClient.noRefreshKey], isTrue);
    expect(find.byKey(const ValueKey('reset-success')), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-password')), findsNothing);
    await tester.tap(find.text('Zurück zum Login'));
    expect(returned, isTrue);
    expect(session.isAuthenticated, isFalse);
    expect(await SecureStorageService.getAccessToken(), isNull);
  });

  for (final reason in ['invalid', 'expired', 'used']) {
    testWidgets('B1 reset $reason proof is understandable', (tester) async {
      respond = (_) async => reply(400, {'detail': 'SENSITIVE_MARKER-$reason'});
      await tester
          .pumpWidget(host(ResetPasswordScreen(token: proof, onDone: () {})));
      await fillReset(tester);
      expect(find.textContaining('ungültig, abgelaufen oder bereits verwendet'),
          findsOneWidget);
      expect(find.textContaining('SENSITIVE_MARKER'), findsNothing);
      expect(find.byKey(const ValueKey('reset-success')), findsNothing);
    });
  }

  for (final status in [422, 429, 500]) {
    testWidgets('B1 reset HTTP $status does not expose server details',
        (tester) async {
      respond = (_) async => reply(status, {'detail': 'SENSITIVE_MARKER'});
      await tester
          .pumpWidget(host(ResetPasswordScreen(token: proof, onDone: () {})));
      await fillReset(tester);
      expect(find.byKey(const ValueKey('reset-error')), findsOneWidget);
      expect(find.textContaining('SENSITIVE_MARKER'), findsNothing);
      expect(find.byKey(const ValueKey('reset-success')), findsNothing);
    });
  }

  testWidgets('B1 reset loading prevents duplicate submission', (tester) async {
    final pending = Completer<ResponseBody>();
    respond = (_) => pending.future;
    await tester
        .pumpWidget(host(ResetPasswordScreen(token: proof, onDone: () {})));
    await tester.enterText(
        find.byKey(const ValueKey('reset-password')), 'new-password');
    await tester.enterText(
        find.byKey(const ValueKey('reset-confirmation')), 'new-password');
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('reset-submit')))
            .onPressed,
        isNull);
    pending.complete(reply());
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(find.byKey(const ValueKey('reset-success')), findsOneWidget);
  });

  testWidgets('B1 reset missing proof offers a new request', (tester) async {
    await tester
        .pumpWidget(host(ResetPasswordScreen(token: null, onDone: () {})));
    expect(find.byKey(const ValueKey('reset-invalid-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-submit')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reset-request-again')));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('B1 verification recovery is reachable from login',
      (tester) async {
    await tester.pumpWidget(host(const AuthScreen()));
    final link = find.byKey(const ValueKey('verification-recovery-link'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byType(VerificationRecoveryScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('verification-return')));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('B1 resend validates input and reports neutral success',
      (tester) async {
    await tester.pumpWidget(host(const VerificationRecoveryScreen()));
    await tester.tap(find.byKey(const ValueKey('verification-submit')));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('verification-email')),
        ' Other@Example.com ');
    await tester.tap(find.byKey(const ValueKey('verification-submit')));
    await tester.pumpAndSettle();
    expect(requests.single.path, '/v1/auth/verify/resend');
    expect(requests.single.data, {'email': 'other@example.com'});
    expect(
        find.byKey(const ValueKey('verification-requested')), findsOneWidget);
  });

  testWidgets('B1 resend loading then safe network error', (tester) async {
    final pending = Completer<ResponseBody>();
    respond = (_) => pending.future;
    await tester.pumpWidget(host(
        const VerificationRecoveryScreen(initialEmail: 'owner@example.com')));
    await tester.tap(find.byKey(const ValueKey('verification-submit')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('verification-submit')))
            .onPressed,
        isNull);
    pending.completeError(DioException(
        requestOptions: requests.single,
        type: DioExceptionType.connectionError,
        error: 'SENSITIVE_MARKER'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('verification-error')), findsOneWidget);
    expect(find.textContaining('SENSITIVE_MARKER'), findsNothing);
    expect(find.byKey(const ValueKey('verification-requested')), findsNothing);
  });

  for (final operation in ['reset-start', 'reset-finish', 'resend']) {
    for (final rejected in [false, true]) {
      test(
          'B1 late $operation response $rejected cannot damage another session',
          () async {
        final pending = Completer<ResponseBody>();
        final dispatched = Completer<void>();
        respond = (_) {
          dispatched.complete();
          return pending.future;
        };
        final future = switch (operation) {
          'reset-start' => auth.requestPasswordReset('owner@example.com'),
          'reset-finish' => auth.finishPasswordReset(proof, 'new-password'),
          _ => auth.requestVerificationResend('owner@example.com'),
        };
        await dispatched.future;
        final current = session.beginSession();
        session.updateTokens('synthetic-B',
            refresh: 'synthetic-refresh-B', generation: current);
        session.updateUser(const UserProfile(id: 'B', email: 'b@example.com'),
            generation: current);
        await SecureStorageService.saveTokens(
            accessToken: 'synthetic-B', refreshToken: 'synthetic-refresh-B');
        pending.complete(
            rejected ? reply(401, {'detail': 'SENSITIVE_MARKER'}) : reply());
        expect(await future, isFalse);
        expect(session.generation, current);
        expect(session.user?.id, 'B');
        expect(session.accessToken, 'synthetic-B');
        expect(await SecureStorageService.getAccessToken(), 'synthetic-B');
        expect(auth.errorMessage, isNull);
        expect(requests, hasLength(1));
      });
    }
  }

  testWidgets('B1 reset network error stays on the form', (tester) async {
    respond = (request) async => throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
        error: 'SENSITIVE_MARKER');
    await tester
        .pumpWidget(host(ResetPasswordScreen(token: proof, onDone: () {})));
    await fillReset(tester);
    expect(find.textContaining('Prüfe deine Verbindung'), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-success')), findsNothing);
    expect(find.textContaining('SENSITIVE_MARKER'), findsNothing);
  });

  testWidgets('B1 registration opens verification recovery with the email',
      (tester) async {
    respond = (_) async =>
        reply(201, {'message': 'Neutral registration acknowledgement'});
    await tester.pumpWidget(host(const AuthScreen()));
    final toggle = find.text('Noch kein Account? Registrieren');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Synthetic Person');
    await tester.enterText(fields.at(1), 'new@example.com');
    await tester.enterText(fields.at(2), 'new-password');
    await tester.enterText(fields.at(3), 'new-password');
    final button = find.widgetWithText(ElevatedButton, 'Registrieren');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(requests.single.path, '/v1/auth/register');
    expect(find.byType(VerificationRecoveryScreen), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('verification-email')))
            .controller
            ?.text,
        'new@example.com');
    expect(session.isAuthenticated, isFalse);
  });

  testWidgets('B1 resend server failure does not claim delivery',
      (tester) async {
    respond = (_) async => reply(503, {'detail': 'SENSITIVE_MARKER'});
    await tester.pumpWidget(host(
        const VerificationRecoveryScreen(initialEmail: 'owner@example.com')));
    await tester.tap(find.byKey(const ValueKey('verification-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('verification-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('verification-requested')), findsNothing);
    expect(find.textContaining('SENSITIVE_MARKER'), findsNothing);
  });

  test('B1 recovery completion preserves a currently signed-in account',
      () async {
    final origin = session.beginSession();
    session.updateTokens('synthetic-B',
        refresh: 'synthetic-refresh-B', generation: origin);
    session.updateUser(const UserProfile(id: 'B', email: 'b@example.com'),
        generation: origin);
    await SecureStorageService.saveTokens(
        accessToken: 'synthetic-B', refreshToken: 'synthetic-refresh-B');
    expect(await auth.finishPasswordReset(proof, 'new-password'), isTrue);
    expect(session.generation, origin);
    expect(session.user?.id, 'B');
    expect(await SecureStorageService.getAccessToken(), 'synthetic-B');
    expect(await SecureStorageService.getRefreshToken(), 'synthetic-refresh-B');
  });


  testWidgets('B1 login preserves the exact password after reset', (tester) async {
    respond = (request) async => request.path == '/v1/auth/login'
        ? reply(200, {'access_token': 'synthetic-access', 'refresh_token': 'synthetic-refresh'})
        : reply(200, {'id': 'owner', 'email': 'owner@example.com'});
    await tester.pumpWidget(host(const AuthScreen()));
    await tester.enterText(find.byType(TextFormField).at(0), 'owner@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), ' new-password ');
    final submit = find.widgetWithText(ElevatedButton, 'Einloggen');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(requests.first.path, '/v1/auth/login');
    expect(requests.first.data['password'], ' new-password ');
    expect(session.user?.id, 'owner');
  });

  test('B1 verification confirmation consumes POST with a body, never GET', () async {
    respond = (_) async => reply(200, {'message': 'E-Mail verifiziert.'});
    expect(await auth.verifyEmail(proof), isTrue);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/v1/auth/verify');
    expect(requests.single.queryParameters, isEmpty);
    expect(requests.single.data, {'token': proof});
    expect(requests.single.extra[ApiClient.noRefreshKey], isTrue);
    expect(session.isAuthenticated, isFalse);
    expect(await SecureStorageService.getAccessToken(), isNull);
  });

  test('B1 verification POST failure never retries as GET or refresh', () async {
    respond = (_) async => reply(400, {'detail': 'Token ungültig.'});
    expect(await auth.verifyEmail(proof), isFalse);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(session.isAuthenticated, isFalse);
    expect(await SecureStorageService.getRefreshToken(), isNull);
  });

  test('B1 recovery rejects malformed acknowledgements', () async {
    respond = (_) async => reply(200, {'unexpected': 'body'});
    expect(await auth.finishPasswordReset(proof, 'new-password'), isFalse);
    expect(auth.errorMessage, contains('nicht bestätigt'));
  });

  test('B1 URI validates duplicate tokens, schemes and unsupported routes', () {
    final links = RecoveryLinkController(initialRoute: '/');
    addTearDown(links.dispose);
    expect(links.acceptRoute('/other?token=$proof'), isFalse);
    for (final path in [
      '/reset-password',
      '/reset-password?token=$proof&token=$proof',
      'http://example.invalid/reset-password?token=$proof',
      '/reset-password?token=$proof#fragment',
    ]) {
      expect(links.acceptRoute(path), isTrue);
      expect(links.token, isNull);
    }
    expect(
        links
            .acceptRoute('https://example.invalid/reset-password?token=$proof'),
        isTrue);
    expect(links.token, isNull); // Unconfigured external origins are not trusted.
    expect(links.acceptRoute('/reset-password?token=$proof'), isTrue);
    expect(links.token, proof);
    session.beginSession();
    expect(links.hasPending, isFalse);
    expect(links.token, isNull);
  });

  testWidgets('B1 cold link survives bootstrap and finish returns actual login',
      (tester) async {
    session.beginBootstrap();
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/reset-password?token=$proof';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(const EmieApp());
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    final context = tester.element(find.byType(ResetPasswordScreen));
    expect(ModalRoute.of(context)?.settings.name, '/');
    await fillReset(tester);
    await tester.tap(find.byKey(const ValueKey('recovery-return')));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('B1 warm native route reaches reset without navigation token',
      (tester) async {
    await tester.pumpWidget(const EmieApp());
    await tester.pumpAndSettle();
    await tester.binding.handlePushRoute('/reset-password?token=$proof');
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(
        ModalRoute.of(tester.element(find.byType(ResetPasswordScreen)))
            ?.settings
            .name,
        '/');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
