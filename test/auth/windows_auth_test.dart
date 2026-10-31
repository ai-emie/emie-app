import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:emie/api/client.dart';
import 'package:emie/app.dart';
import 'package:emie/core/config/env.dart';
import 'package:emie/core/storage/secure_storage.dart';
import 'package:emie/features/auth/controller/auth_controller.dart';
import 'package:emie/features/auth/navigation/recovery_link_controller.dart';
import 'package:emie/features/auth/presentation/screens/auth_screen.dart';
import 'package:emie/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:emie/features/auth/presentation/widgets/windows_auth_status.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Live IO forbidden');
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

ResponseBody _reply(int status, Object body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final session = SessionStore.instance;
  final client = ApiClient();
  const proof = 'abcdefghijklmnopqrstuvwxyz123456';
  late AuthController auth;
  late HttpClientAdapter oldMain, oldRefresh;
  late HttpOverrides? oldHttp;
  late List<RequestOptions> requests;
  late Future<ResponseBody> Function(RequestOptions) respond;
  setUp(() {
    session.clear();
    FlutterSecureStorage.setMockInitialValues({});
    SecureStorageService.useStorageForTesting(const FlutterSecureStorage());
    oldHttp = HttpOverrides.current;
    HttpOverrides.global = _NoNetwork();
    oldMain = client.dio.httpClientAdapter;
    oldRefresh = client.refreshDio.httpClientAdapter;
    requests = [];
    respond = (_) async => _reply(200, {'message': 'E-Mail verifiziert.'});
    client.dio.httpClientAdapter = _Transport((request) {
      requests.add(request);
      if (request.path == '/v1/local/mode') {
        return Future.value(
            _reply(200, {'mode': 'P4', 'mail': 'local-only', 'ai': false}));
      }
      return respond(request);
    });
    client.refreshDio.httpClientAdapter =
        _Transport((_) async => throw StateError('No auth replay'));
    auth = AuthController();
  });
  tearDown(() {
    auth.dispose();
    client.dio.httpClientAdapter = oldMain;
    client.refreshDio.httpClientAdapter = oldRefresh;
    HttpOverrides.global = oldHttp;
    session.clear();
  });
  Widget host(Widget child) => MultiProvider(providers: [
        ChangeNotifierProvider<SessionStore>.value(value: session),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ], child: MaterialApp(home: child));

  test('P4 is explicit offline Android; P1/P3 disabled', () {
    expect(Env.p4, isTrue);
    expect(Env.offline, isTrue);
    expect(Env.localAi, isFalse);
    expect(Env.apiBaseUrl, 'http://10.0.2.2:8011');
  });
  test('verification links share strict origin, proof and session ownership',
      () {
    final links = RecoveryLinkController(initialRoute: '/');
    addTearDown(links.dispose);
    expect(
        links.acceptRoute('http://10.0.2.2:8011/v1/auth/verify?token=$proof'),
        isTrue);
    expect(links.isVerification, isTrue);
    expect(links.token, proof);
    for (final route in [
      'http://10.0.2.2:8012/v1/auth/verify?token=$proof',
      'http://foreign.invalid/v1/auth/verify?token=$proof',
      '/v1/auth/verify?token=$proof&token=$proof',
      '/v1/auth/verify?token=$proof#fragment',
      '/v1/auth/verify?token=short',
    ]) {
      links.acceptRoute(route);
      expect(links.token, isNull);
    }
    links.acceptRoute('/v1/auth/verify?token=$proof');
    session.beginSession();
    expect(links.hasPending, isFalse);
  });
  testWidgets(
      'opening confirmation performs no POST; explicit confirm is single and never logs in',
      (tester) async {
    final pending = Completer<ResponseBody>();
    respond = (_) => pending.future;
    await tester
        .pumpWidget(host(VerifyEmailScreen(token: proof, onDone: () {})));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.textContaining(proof), findsNothing);
    await tester.tap(find.byKey(const ValueKey('verify-confirm')));
    await tester.tap(find.byKey(const ValueKey('verify-confirm')));
    for (var i = 0; i < 10 && requests.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(requests, hasLength(1));
    expect(requests.single.path, '/v1/auth/verify');
    expect(requests.single.data, {'token': proof});
    pending.complete(_reply(200, {'message': 'E-Mail verifiziert.'}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('verify-success')), findsOneWidget);
    expect(session.isAuthenticated, isFalse);
    expect(await SecureStorageService.getAccessToken(), isNull);
  });
  testWidgets(
      'invalid and expired proofs have safe recoverable UI, no false success',
      (tester) async {
    for (final detail in [
      'Der Link ist abgelaufen. PRIVATE',
      'ungueltig oder verwendet PRIVATE'
    ]) {
      respond = (_) async => _reply(400, {'detail': detail});
      await tester.pumpWidget(host(VerifyEmailScreen(
          key: ValueKey(detail), token: proof, onDone: () {})));
      await tester.tap(find.byKey(const ValueKey('verify-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('verify-success')), findsNothing);
      expect(find.byKey(const ValueKey('verify-error')), findsOneWidget);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(find.byKey(const ValueKey('verify-resend')), findsOneWidget);
    }
  });
  test('malformed registration and verification acknowledgements fail closed',
      () async {
    respond = (_) async => _reply(201, {});
    expect(
        await auth.registerWithEmail(
            'Synthetic', 'synthetic@example.com', 'synthetic-password'),
        isFalse);
    respond = (_) async => _reply(200, {});
    expect(await auth.verifyEmail(proof), isFalse);
    expect(session.isAuthenticated, isFalse);
  });
  test('registration double send is blocked until its acknowledgement',
      () async {
    final pending = Completer<ResponseBody>();
    respond = (_) => pending.future;
    final first = auth.registerWithEmail(
        'Synthetic', 'synthetic@example.com', 'synthetic-password');
    expect(
        await auth.registerWithEmail(
            'Synthetic', 'synthetic@example.com', 'synthetic-password'),
        isFalse);
    pending
        .complete(_reply(201, {'message': 'Neutral registration requested'}));
    expect(await first, isTrue);
    expect(requests, hasLength(1));
  });
  test('German unverified login response requests confirmation', () async {
    respond =
        (_) async => _reply(401, {'detail': 'E-Mail noch nicht verifiziert.'});
    expect(
        await auth.loginWithEmail(
            'synthetic@example.com', 'synthetic-password'),
        isFalse);
    expect(auth.errorMessage, contains('bestätige zuerst'));
    expect(session.isAuthenticated, isFalse);
  });
  testWidgets(
      'cold confirmation link stays out of Navigator names and returns login',
      (tester) async {
    session.beginBootstrap();
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/v1/auth/verify?token=$proof';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(const EmieApp());
    await tester.pumpAndSettle();
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(
        ModalRoute.of(tester.element(find.byType(VerifyEmailScreen)))
            ?.settings
            .name,
        '/');
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('verify-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('verify-return')));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('local auth banner does not claim connectivity after stop',
      (tester) async {
    var online = true;
    final dio = Dio()
      ..httpClientAdapter = _Transport((request) async {
        if (!online) {
          throw DioException(
              requestOptions: request, type: DioExceptionType.connectionError);
        }
        return _reply(200, {'mode': 'P4', 'mail': 'local-only', 'ai': false});
      });
    await tester.pumpWidget(MaterialApp(home: WindowsAuthStatus(dio: dio)));
    await tester.pumpAndSettle();
    expect(find.textContaining('nur lokale Mailablage'), findsOneWidget);
    online = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('nicht verbunden'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    dio.close();
  });
  testWidgets('explicit Resend mode labels emulator links without claiming delivery',
      (tester) async {
    final dio = Dio()
      ..httpClientAdapter = _Transport((request) async =>
          _reply(200, {'mode': 'P5', 'mail': 'resend-emulator', 'ai': false}));
    await tester.pumpWidget(MaterialApp(home: WindowsAuthStatus(dio: dio)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Resend · Links nur Pixel_9'), findsOneWidget);
    expect(find.textContaining('nur lokale Mailablage'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    dio.close();
  });
}
