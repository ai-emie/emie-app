import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:emie/features/profile/presentation/screens/profile_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/account_deletion_session_test.dart' show Kl5Harness;
import 'product_widgets_test.dart' show host;

// Bodies captured from real owned-PG HTTP responses; no prefilled session user.
// Export fixture pseudonymizes identities consistently without inventing fields.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Kl5Harness h;
  late Map<String, dynamic> f;
  setUp(() async {
    f = jsonDecode(File(Platform.environment['B3_R1_PROFILE_FIXTURE'] ??
            'test/fixtures/b3_r1_profile_responses.json')
        .readAsStringSync());
    if (f.containsKey('me')) f = {'A': f};
    h = Kl5Harness();
    await h.session.setLanguage('de');
    h.onMain = (request) async {
      final owner = Kl5Harness.owner(request) == 'B' ? 'R1B' : 'A';
      if (request.path == '/v1/me') return Kl5Harness.json(f[owner]['me']);
      if (request.path == '/v1/profile') {
        return Kl5Harness.json(f[owner]['profile']);
      }
      return h.defaultResponse(request);
    };
  });
  tearDown(() => h.dispose());

  testWidgets('B3 R1 actual login body feeds parser session and editor',
      (tester) async {
    await tester.runAsync(() => h.login('A'));
    final origin = h.session.generation;
    // Compare booleans to avoid putting complete server IDs into failure logs.
    expect(h.session.user?.id.isNotEmpty, isTrue);
    expect(h.session.user?.id == f['A']['profile']['id'], isTrue);
    await tester.pumpWidget(host(const ProfileEditor()));
    await tester.pumpAndSettle();
    expect(find.text('Profil konnte nicht geladen werden.'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(h.session.generation, origin);
    expect(h.session.user?.id == f['A']['me']['id'], isTrue);
    expect(h.requests.any((r) => r.startsWith('POST /v1/auth/login')), isTrue);
    expect(h.requests.any((r) => r.startsWith('GET /v1/me')), isTrue);
  });

  testWidgets(
      'B3 R1 actual me response also supplies restored session identity',
      (tester) async {
    await tester.runAsync(() => h.login('A'));
    h.session
        .clear(); // Secure-storage pair remains; no synthetic profile injection.
    await tester.runAsync(h.auth.bootstrapSession);
    expect(h.session.isAuthenticated, isTrue);
    expect(h.session.user?.id == f['A']['profile']['id'], isTrue);
    await tester.pumpWidget(host(const ProfileEditor()));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets(
      'B3 R1 foreign profile still fails identity check and retry recovers',
      (tester) async {
    await tester.runAsync(() => h.login('A'));
    final normal = h.onMain!;
    var foreign = true;
    h.onMain = (r) async => r.path == '/v1/profile' && foreign
        ? Kl5Harness.json(f['R1B']['profile'])
        : await normal(r);
    await tester.pumpWidget(host(const ProfileEditor()));
    await tester.pumpAndSettle();
    expect(find.text('Profil konnte nicht geladen werden.'), findsOneWidget);
    expect(h.session.user?.id == f['A']['me']['id'], isTrue);
    foreign = false;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('B3 R1 delayed A profile cannot change a new B session',
      (tester) async {
    await tester.runAsync(() => h.login('A'));
    final normal = h.onMain!;
    final release = Completer<void>();
    h.onMain = (r) async {
      if (r.path == '/v1/profile') {
        await release.future;
        return Kl5Harness.json(f['A']['profile']);
      }
      return normal(r);
    };
    await tester.pumpWidget(host(const ProfileEditor()));
    await tester.pump();
    await tester.runAsync(() => h.login('B'));
    final origin = h.session.generation;
    release.complete();
    await tester.pumpAndSettle();
    expect(h.session.generation, origin);
    expect(h.session.user?.id == f['R1B']['me']['id'], isTrue);
  });
  testWidgets(
      'B3 R1 first edit keeps the same input focus when dirty notice appears',
      (tester) async {
    await tester.runAsync(() => h.login('A'));
    await tester.pumpWidget(host(const ProfileEditor()));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.showKeyboard(fields.first);
    tester.testTextInput.enterText('R');
    await tester.pump();
    final first = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(first.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    tester.testTextInput.enterText('R1 complete native name');
    await tester.pump();
    expect(first.controller.text, 'R1 complete native name');
  });
}
