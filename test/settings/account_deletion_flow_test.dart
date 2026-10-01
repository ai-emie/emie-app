import 'dart:async';

import 'package:dio/dio.dart';
import 'package:emie/app.dart';
import 'package:emie/data/auth/auth_models.dart';
import 'package:emie/features/auth/controller/auth_controller.dart';
import 'package:emie/features/auth/presentation/screens/auth_screen.dart';
import 'package:emie/features/chat/controller/chat_controller.dart';
import 'package:emie/features/home/presentation/screens/home_screen.dart';
import 'package:emie/features/main/presentation/screens/main_shell.dart';
import 'package:emie/features/memory/presentation/screens/memory_screen.dart';
import 'package:emie/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../auth/account_deletion_session_test.dart'
    show Kl5Harness, FakeTokenStorage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Kl5Harness h;
  setUp(() async {
    h = Kl5Harness();
    await h.session.loadPreferences();
  });
  tearDown(() {
    h.dispose();
  });

  Future<void> pumpUntil(WidgetTester tester, Completer<void> signal) async {
    for (var frame = 0; frame < 50 && !signal.isCompleted; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(signal.isCompleted, isTrue,
        reason:
            'Controlled IO barrier must be reached; requests=${h.requests}');
  }

  Future<AuthController> mount(WidgetTester tester, {bool login = true}) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EmieApp());
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    final auth =
        tester.element(find.byType(MaterialApp)).read<AuthController>();
    if (login) {
      expect(
          await tester.runAsync(() =>
              auth.loginWithEmail('a@example.invalid', 'synthetic-password')),
          isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(MainShell), findsOneWidget);
    }
    return auth;
  }

  Future<void> openDialog(WidgetTester tester, {bool english = false}) async {
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    final entry = find.text(english ? 'Delete account' : 'Konto löschen');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  Future<void> confirm(WidgetTester tester, {bool english = false}) async {
    final button = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(
            TextButton, english ? 'Delete account' : 'Konto löschen'));
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('KL5 real settings dialog cancel sends no DELETE',
      (tester) async {
    await mount(tester);
    await openDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();
    expect(h.requests.where((r) => r.startsWith('DELETE')), isEmpty);
    expect(find.byType(SettingsScreen), findsOneWidget);
    h.expectOwner('A');
  });

  testWidgets(
      'KL5 confirmed deletion disposes real scopes and keeps cleanup warnings visible',
      (tester) async {
    final auth = await mount(tester);
    final oldHome = tester.state(find.byType(HomeScreen));
    final oldMemory =
        tester.state(find.byType(MemoryScreen, skipOffstage: false));
    final oldChat =
        tester.element(find.byType(HomeScreen)).read<ChatController>();
    h.storage.failures.add('delete:refresh');
    h.googleFailures.add('signOut');
    await openDialog(tester);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(oldHome.mounted, isFalse);
    expect(oldMemory.mounted, isFalse);
    expect(oldChat.messages, isEmpty);
    expect(oldChat.sessions, isEmpty);
    expect(oldChat.chatSessionId, isEmpty);
    expect(find.textContaining('Die Löschung deines Kontos wurde bestätigt.'),
        findsOneWidget);
    expect(find.textContaining('gespeicherten Zugangsdaten'), findsOneWidget);
    expect(find.textContaining('lokale Google-Abmeldung'), findsOneWidget);
    expect(auth.deletionNotice!.server, DeletionServerResult.confirmed);
    expect(h.requests.where((r) => r.startsWith('DELETE')).length, 1);
    // Visibility has no timer: another frame/time advance must not dismiss it.
    await tester.pump(const Duration(minutes: 1));
    expect(
        find.byKey(const ValueKey('account-deletion-notice')), findsOneWidget);
    // Both cleanup warnings and the explicit close action fit a phone viewport.
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('gespeicherten Zugangsdaten'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('close-account-deletion-notice')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-deletion-notice')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'KL5 double activation of the real confirmation button sends one DELETE',
      (tester) async {
    await mount(tester);
    await openDialog(tester);
    final button = tester.widget<TextButton>(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Konto löschen')));
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(h.requests.where((r) => r.startsWith('DELETE')).length, 1);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'KL5 dismissed notice stays closed when Google completion arrives later',
      (tester) async {
    await mount(tester);
    final entered = Completer<void>(), release = Completer<void>();
    h.googleFailures.add('signOut');
    h.beforeGoogle = (method) async {
      if (method == 'signOut') {
        entered.complete();
        await release.future;
      }
    };
    await openDialog(tester);
    await confirm(tester);
    await pumpUntil(tester, entered);
    await tester.pump();
    expect(
        find.byKey(const ValueKey('account-deletion-notice')), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('close-account-deletion-notice')));
    release.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-deletion-notice')), findsNothing);
  });

  for (final status in [200, 401]) {
    testWidgets('KL5 late Memory $status cannot populate or reset B',
        (tester) async {
      final auth = await mount(tester);
      final oldMemory =
          tester.state(find.byType(MemoryScreen, skipOffstage: false));
      // Enter before delaying the explicit refresh: tab entry now reloads too.
      await tester.tap(find.byIcon(Icons.psychology_alt_outlined));
      await tester.pumpAndSettle();
      final entered = Completer<void>(), release = Completer<void>();
      h.onMain = (request) async {
        if (request.path == '/v1/memory/list') {
          final owner = Kl5Harness.owner(request);
          if (owner == 'A') {
            entered.complete();
            await release.future;
            return Kl5Harness.json({
              'total_items': 1, 'offset': 0, 'limit': 20, 'page': 1,
              'items': [
                {'id': 'A-item', 'content': 'A delayed memory'}
              ]
            }, status: status);
          }
          return Kl5Harness.json({
            'total_items': 1, 'offset': 0, 'limit': 20, 'page': 1,
            'items': [
              {'id': 'B-item', 'content': 'B current memory'}
            ]
          });
        }
        return h.defaultResponse(request);
      };
      await tester.tap(find.byTooltip('Aktualisieren'));
      await pumpUntil(tester, entered);
      final deletion = auth.deleteAccount();
      await tester.pumpAndSettle();
      expect((await deletion).server, DeletionServerResult.confirmed);
      expect(oldMemory.mounted, isFalse);
      expect(
          await tester.runAsync(() =>
              auth.loginWithEmail('b@example.invalid', 'synthetic-password')),
          isTrue);
      await tester.pumpAndSettle();
      final bMemory =
          tester.state(find.byType(MemoryScreen, skipOffstage: false));
      release.complete();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(MemoryScreen, skipOffstage: false)),
          same(bMemory));
      await tester.tap(find.byIcon(Icons.psychology_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.text('A delayed memory'), findsNothing);
      expect(find.text('B current memory'), findsOneWidget);
      h.expectOwner('B');
      expect(h.refreshRequests, isEmpty);
      expect(auth.errorMessage, isNull);
    });
  }

  testWidgets(
      'KL5 unconfirmed response stays in current settings without retry',
      (tester) async {
    await mount(tester);
    h.onMain = (request) async => request.method == 'DELETE'
        ? Kl5Harness.json({'status': 'ok'})
        : h.defaultResponse(request);
    await openDialog(tester);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
        find.textContaining(
            'Wir konnten nicht bestätigen, ob dein Konto gelöscht wurde.'),
        findsOneWidget);
    expect(
        find.textContaining(
            'Der Löschvorgang wird nicht automatisch wiederholt.'),
        findsOneWidget);
    h.expectOwner('A');
    await tester.pump(const Duration(seconds: 30));
    expect(h.requests.where((r) => r.startsWith('DELETE')).length, 1);
    expect(h.refreshRequests, isEmpty);
  });

  testWidgets(
      'KL5 deletion 401 shows reauthentication without claiming deletion',
      (tester) async {
    await mount(tester);
    h.onMain = (request) async => request.method == 'DELETE'
        ? Kl5Harness.json({}, status: 401)
        : h.defaultResponse(request);
    await openDialog(tester);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(
        find.textContaining(
            'Für diesen Löschversuch liegt keine Löschbestätigung vor.'),
        findsOneWidget);
    expect(find.textContaining('Die Löschung deines Kontos wurde bestätigt.'),
        findsNothing);
    expect(h.refreshRequests, isEmpty);
  });

  testWidgets(
      'KL5 account switch while dialog is open removes its confirmation',
      (tester) async {
    final auth = await mount(tester);
    await openDialog(tester);
    expect(
        await tester.runAsync(() =>
            auth.loginWithEmail('b@example.invalid', 'synthetic-password')),
        isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(h.requests.where((r) => r.startsWith('DELETE')), isEmpty);
    h.expectOwner('B');
  });

  for (final outcome in [200, 401, 500, 0]) {
    testWidgets(
        'KL5 late A result $outcome cannot change B navigation or notice',
        (tester) async {
      final auth = await mount(tester);
      final entered = Completer<void>(), release = Completer<void>();
      h.onMain = (request) async {
        if (request.method != 'DELETE') {
          return h.defaultResponse(request);
        }
        entered.complete();
        await release.future;
        if (outcome == 0) {
          throw DioException(
              requestOptions: request, type: DioExceptionType.receiveTimeout);
        }
        return Kl5Harness.json({'status': 'deleted'}, status: outcome);
      };
      await openDialog(tester);
      await confirm(tester);
      await pumpUntil(tester, entered);
      expect(
          await tester.runAsync(() =>
              auth.loginWithEmail('b@example.invalid', 'synthetic-password')),
          isTrue);
      await tester.pumpAndSettle();
      final bHome = tester.state(find.byType(HomeScreen));
      release.complete();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(HomeScreen)), same(bHome));
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(AuthScreen), findsNothing);
      expect(
          find.byKey(const ValueKey('account-deletion-notice')), findsNothing);
      expect(auth.isLoading, isFalse);
      expect(auth.errorMessage, isNull);
      h.expectOwner('B');
      expect(h.googleEvents, isEmpty);
      expect(h.refreshRequests, isEmpty);
    });
  }

  testWidgets('KL5 notice vanishes at new login start before its response',
      (tester) async {
    final auth = await mount(tester);
    await openDialog(tester);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('account-deletion-notice')), findsOneWidget);
    final entered = Completer<void>(), release = Completer<void>();
    h.onMain = (request) async {
      if (request.path == '/v1/auth/login') {
        entered.complete();
        await release.future;
      }
      return h.defaultResponse(request);
    };
    final login =
        auth.loginWithEmail('b@example.invalid', 'synthetic-password');
    await tester.pump();
    await pumpUntil(tester, entered);
    expect(find.byKey(const ValueKey('account-deletion-notice')), findsNothing);
    release.complete();
    await tester.pumpAndSettle();
    expect(await login, isTrue);
    h.expectOwner('B');
  });

  testWidgets(
      'KL5 same-account relogin replaces scopes while token rotation preserves them',
      (tester) async {
    final auth = await mount(tester);
    final home = tester.state(find.byType(HomeScreen));
    final chat = tester.element(find.byType(HomeScreen)).read<ChatController>();
    h.session.updateTokens('synthetic-A-rotated',
        refresh: 'synthetic-refresh-A-rotated',
        generation: h.session.generation);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(HomeScreen)), same(home));
    expect(tester.element(find.byType(HomeScreen)).read<ChatController>(),
        same(chat));
    expect(
        await tester.runAsync(() =>
            auth.loginWithEmail('a@example.invalid', 'synthetic-password')),
        isTrue);
    await tester.pumpAndSettle();
    expect(home.mounted, isFalse);
    expect(tester.element(find.byType(HomeScreen)).read<ChatController>(),
        isNot(same(chat)));
    expect(chat.messages, isEmpty);
  });

  testWidgets(
      'KL5 English dialog and result survive local session language reset',
      (tester) async {
    await mount(tester);
    h.session.setLanguage('en');
    await tester.pumpAndSettle();
    await openDialog(tester, english: true);
    await confirm(tester, english: true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Your account deletion was confirmed.'),
        findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);
    expect(
        find.textContaining('You are signed out of this app.'), findsOneWidget);
  });

  for (final retained in ['both', 'access', 'refresh']) {
    testWidgets(
        'KL5 new bootstrap with retained $retained credentials has no deletion receipt',
        (tester) async {
      if (retained != 'refresh') {
        h.storage.values[FakeTokenStorage.access] = 'synthetic-A';
      }
      if (retained != 'access') {
        h.storage.values[FakeTokenStorage.refresh] = 'synthetic-refresh-A';
      }
      h.storage.failures.addAll(['delete:access', 'delete:refresh']);
      h.onMain = (request) async => request.path == '/v1/me'
          ? Kl5Harness.json({}, status: 401)
          : h.defaultResponse(request);
      h.onRefresh = (_) async => Kl5Harness.json({}, status: 401);
      await mount(tester, login: false);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      expect(
          find.byKey(const ValueKey('account-deletion-notice')), findsNothing);
      expect(h.session.isAuthenticated, isFalse);
      expect(h.requests.where((r) => r.startsWith('DELETE')), isEmpty);
      expect(h.storage.events.where((e) => e.startsWith('read:')).toList(),
          ['read:preferences:start', 'read:access:start', 'read:refresh:start']);
    });
  }

  for (final failure in ['network', 'read:access', 'read:refresh']) {
    testWidgets(
        'KL5 cold bootstrap $failure cannot display old authenticated content',
        (tester) async {
      h.storage.values.addAll({
        FakeTokenStorage.access: 'synthetic-A',
        FakeTokenStorage.refresh: 'synthetic-refresh-A'
      });
      if (failure == 'network') {
        h.onMain = (request) async => throw DioException(
            requestOptions: request, type: DioExceptionType.connectionError);
      } else {
        h.storage.failures.add(failure);
      }
      await mount(tester, login: false);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      expect(h.session.user, isNull);
      expect(
          find.byKey(const ValueKey('account-deletion-notice')), findsNothing);
    });
  }

  for (final switchToB in [false, true]) {
    testWidgets(
        'KL5 pending bootstrap validates profile before display; switchB=$switchToB',
        (tester) async {
      h.storage.values.addAll({
        FakeTokenStorage.access: 'synthetic-A',
        FakeTokenStorage.refresh: 'synthetic-refresh-A'
      });
      final entered = Completer<void>(), release = Completer<void>();
      h.onMain = (request) async {
        if (request.path == '/v1/me' && Kl5Harness.owner(request) == 'A') {
          entered.complete();
          await release.future;
        }
        return h.defaultResponse(request);
      };
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const EmieApp());
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pump();
      await pumpUntil(tester, entered);
      expect(find.byType(MainShell), findsNothing);
      expect(h.session.isAuthenticated, isFalse);
      final auth =
          tester.element(find.byType(MaterialApp)).read<AuthController>();
      if (switchToB) {
        expect(
            await tester.runAsync(() =>
                auth.loginWithEmail('b@example.invalid', 'synthetic-password')),
            isTrue);
        await tester.pumpAndSettle();
      }
      release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(MainShell), findsOneWidget);
      h.expectOwner(switchToB ? 'B' : 'A');
    });
  }

  testWidgets(
      'KL5 simulated restart retains fake storage but replaces volatile app state',
      (tester) async {
    await mount(tester);
    h.storage.failures.add('delete:refresh');
    await openDialog(tester);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('account-deletion-notice')), findsOneWidget);
    expect(h.storage.values.keys.toList(), [FakeTokenStorage.refresh]);
    await tester.pumpWidget(const SizedBox.shrink());
    h.session
        .clear(); // New volatile auth state; fake plugin data deliberately retained.
    h.onMain = (request) async => request.path == '/v1/me'
        ? Kl5Harness.json({}, status: 401)
        : h.defaultResponse(request);
    h.onRefresh = (_) async => Kl5Harness.json({}, status: 401);
    await tester.pumpWidget(const EmieApp());
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('account-deletion-notice')), findsNothing);
    expect(h.requests.where((r) => r.startsWith('DELETE')).length, 1);
    expect(tester.takeException(), isNull);
  });
}
