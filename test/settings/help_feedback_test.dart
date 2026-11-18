import 'dart:async';

import 'package:dio/dio.dart';
import 'package:emie/core/localization/app_localizations.dart';
import 'package:emie/data/auth/auth_api.dart';
import 'package:emie/data/auth/auth_models.dart';
import 'package:emie/data/auth/auth_repository.dart';
import 'package:emie/features/auth/controller/auth_controller.dart';
import 'package:emie/features/settings/presentation/screens/help_feedback_screen.dart';
import 'package:emie/features/settings/presentation/screens/settings_screen.dart';
import 'package:emie/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class _TestSession extends SessionStore {
  _TestSession(this.code) : super.forTesting();
  final String code;
  @override
  String get language => code;
}

const _templates = {
  'de': 'Appversion / Buildnummer: 2.4.6 (321)\n\n'
      'Was wollte ich tun?\n\nWas ist passiert?\n\n'
      'Was hätte passieren sollen?\n\nWelche Schritte führen zum Problem?',
  'en': 'App version / build number: 2.4.6 (321)\n\n'
      'What was I trying to do?\n\nWhat happened?\n\n'
      'What should have happened?\n\nWhat steps reproduce the problem?',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const mailChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> mailCalls;
  late List<String> copied;
  late Future<bool> Function() launchResult;
  var copyFails = false;

  setUp(() {
    mailCalls = [];
    copied = [];
    copyFails = false;
    launchResult = () async => true;
    PackageInfo.setMockInitialValues(
      appName: 'DO_NOT_EXPORT_APP_METADATA',
      packageName: 'DO_NOT_EXPORT_PACKAGE',
      version: '2.4.6',
      buildNumber: '321',
      buildSignature: 'DO_NOT_EXPORT_SIGNATURE',
      installerStore: 'DO_NOT_EXPORT_INSTALLER',
    );
    messenger.setMockMethodCallHandler(mailChannel, (call) async {
      mailCalls.add(call);
      expect(call.method, 'launch');
      return launchResult();
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (copyFails) {
          throw PlatformException(code: 'synthetic-copy-failure');
        }
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(mailChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> mount(
    WidgetTester tester,
    String language, {
    Widget home = const HelpFeedbackScreen(),
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(MaterialApp(
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD37F),
          brightness: brightness,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  void expectDraft(String language) {
    expect(mailCalls, hasLength(1));
    final args = mailCalls.single.arguments as Map;
    final uri = Uri.parse(args['url'] as String);
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'emiso.emie@gmail.com');
    expect(uri.hasFragment, isFalse);
    expect(uri.queryParameters, {
      'subject': language == 'de'
          ? 'Emie Beta – Hilfe & Feedback'
          : 'Emie Beta – Help & feedback',
      'body': _templates[language],
    });
    expect(uri.toString(), isNot(contains('+')));
    expect(args['headers'], isEmpty);
    expect(args['useSafariVC'], isFalse);
    expect(args['useWebView'], isFalse);
  }

  for (final language in ['de', 'en']) {
    final de = language == 'de';
    final title = de ? 'Hilfe & Feedback' : 'Help & feedback';
    final prepare = de ? 'E-Mail vorbereiten' : 'Prepare email';
    final copyAddress = de ? 'Kontaktadresse kopieren' : 'Copy contact address';
    final copyTemplate = de ? 'Vorlage kopieren' : 'Copy template';

    testWidgets('$language settings entry opens a private-data-free draft',
        (tester) async {
      final session = _TestSession(language)
        ..updateUser(const UserProfile(
          id: 'DO_NOT_EXPORT_ACCOUNT_ID',
          email: 'private-account@example.invalid',
          name: 'DO_NOT_EXPORT_NAME',
        ))
        ..updateTokens('DO_NOT_EXPORT_ACCESS',
            refresh: 'DO_NOT_EXPORT_REFRESH');
      final dio = Dio();
      var requests = 0;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
        requests++;
        handler.reject(DioException(requestOptions: request));
      }));
      final auth =
          AuthController(repository: AuthRepository(api: AuthApi(dio: dio)));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        auth.dispose();
        session.dispose();
        dio.close();
      });
      await mount(tester, language,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SessionStore>.value(value: session),
              ChangeNotifierProvider<AuthController>.value(value: auth),
            ],
            child: const SettingsScreen(),
          ));
      await tester.scrollUntilVisible(find.text(title), 250);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      await tapText(tester, title);
      expect(find.byType(HelpFeedbackScreen), findsOneWidget);
      expect(mailCalls, isEmpty);
      expect(copied, isEmpty);
      expect(find.text('emiso.emie@gmail.com'), findsOneWidget);
      expect(find.text(_templates[language]!), findsOneWidget);
      expect(
          find.textContaining(de
              ? 'Bitte keine Passwörter'
              : 'Please do not include passwords'),
          findsOneWidget);
      expect(find.textContaining(de ? 'sendest selbst' : 'send it yourself'),
          findsOneWidget);
      await tapText(tester, prepare);
      expectDraft(language);
      expect(
          find.textContaining(
              de ? 'Mailprogramm aufgerufen' : 'Mail app opened'),
          findsOneWidget);
      expect(find.textContaining(de ? 'Nachricht gesendet' : 'Message sent'),
          findsNothing);
      expect(requests, 0);
      await tester.ensureVisible(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton).hitTestable(), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final throws in [false, true]) {
      testWidgets(
          '$language mail client ${throws ? 'throws' : 'missing'} keeps copy fallback usable',
          (tester) async {
        launchResult = () async {
          if (throws) {
            throw PlatformException(code: 'synthetic-no-client');
          }
          return false;
        };
        await mount(tester, language);
        await tapText(tester, prepare);
        expect(
            find.textContaining(
                de ? 'Es konnte kein Mailprogramm' : 'No mail app could'),
            findsOneWidget);
        expect(
            find.textContaining(
                de ? 'Mailprogramm aufgerufen' : 'Mail app opened'),
            findsNothing);
        await tapText(tester, copyAddress);
        expect(copied.single, 'emiso.emie@gmail.com');
        expect(
            find.text(
                de ? 'Kontaktadresse kopiert.' : 'Contact address copied.'),
            findsOneWidget);
        await tapText(tester, copyTemplate);
        expect(copied.last, _templates[language]);
        expect(find.text(de ? 'Vorlage kopiert.' : 'Template copied.'),
            findsOneWidget);
        expect(mailCalls, hasLength(1));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        '$language clipboard failure leaves selectable text and honest status',
        (tester) async {
      copyFails = true;
      await mount(tester, language);
      await tapText(tester, copyTemplate);
      expect(
          find.textContaining(de ? 'Kopieren nicht möglich' : 'Could not copy'),
          findsOneWidget);
      expect(find.text(de ? 'Vorlage kopiert.' : 'Template copied.'),
          findsNothing);
      expect(find.byType(SelectableText), findsNWidgets(2));
      expect(copied, isEmpty);
      expect(mailCalls, isEmpty);
    });

    for (final fails in [false, true]) {
      testWidgets(
          '$language ${fails ? 'unavailable' : 'empty'} installed version stays manual',
          (tester) async {
        await mount(tester, language, home: HelpFeedbackScreen(
          packageInfoLoader: () async {
            if (fails) {
              throw PlatformException(code: 'synthetic-version-unavailable');
            }
            return PackageInfo(
                appName: '', packageName: '', version: '', buildNumber: '');
          },
        ));
        await tapText(tester, prepare);
        final draft =
            Uri.parse((mailCalls.single.arguments as Map)['url'] as String);
        final body = draft.queryParameters['body']!;
        expect(
            body,
            _templates[language]!.replaceFirst('2.4.6 (321)',
                de ? '[bitte selbst ergänzen]' : '[please fill in]'));
        expect(tester.takeException(), isNull);
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets(
          '$language $brightness small viewport with large text scrolls without overflow',
          (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(tester, language, scale: 2.5, brightness: brightness);
        expect(tester.takeException(), isNull);
        for (final label in [copyAddress, prepare, copyTemplate]) {
          await tapText(tester, label);
          expect(tester.takeException(), isNull);
        }
        expect(copied, ['emiso.emie@gmail.com', _templates[language]]);
        expectDraft(language);
      });
    }
  }

  testWidgets('a pending mail launch cannot open duplicate drafts',
      (tester) async {
    final completion = Completer<bool>();
    launchResult = () => completion.future;
    await mount(tester, 'de');
    await tester.ensureVisible(find.text('E-Mail vorbereiten'));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(mailCalls, hasLength(1));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    completion.complete(true);
    await tester.pumpAndSettle();
    expectDraft('de');
  });
}
