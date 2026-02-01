// ===============================================
// Emie • Auth Repository
// Pfad: lib/data/auth/auth_repository.dart
// ===============================================

import '../../state/session_store.dart';
import 'auth_api.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository({AuthApi? api}) : _api = api ?? AuthApi();

  final AuthApi _api;
  final SessionStore _session = SessionStore.instance;

  // -------------------------------------------
  // • Login via E-Mail & Passwort
  //    - Holt Tokens
  //    - Speichert Tokens im SessionStore
  //    - Lädt /v1/me und speichert User
  // -------------------------------------------
  Future<UserProfile> loginWithEmail(
    String email,
    String password,
  ) async {
    // 1) Tokens holen
    final tokens = await _api.login(
      email: email,
      password: password,
    );

    // 2) Tokens im SessionStore speichern
    _session.updateTokens(
      tokens.accessToken,
      refresh: tokens.refreshToken,
    );

    // 3) Profil holen
    final user = await _api.me();
    _session.updateUser(user);
    return user;
  }

  // -------------------------------------------
  // • Registrierung (ohne Auto-Login)
  //    Backend: POST /v1/auth/register
  //    Response: VerifyResponse (z.B. "Check deine Mail")
  // -------------------------------------------
  Future<VerifyResponse> registerWithEmail({
    required String name, // aktuell nur im Frontend genutzt
    required String email,
    required String password,
  }) async {
    // Name schicken wir später über /profile, aktuell egal.
    final res = await _api.register(
      email: email,
      password: password,
    );
    return res;
  }

  // -------------------------------------------
  // • E-Mail-Bestätigung (Verify-Link aus Mail)
  //    Backend: GET /v1/auth/verify?token=...
  // -------------------------------------------
  Future<VerifyResponse> verifyEmail(String token) async {
    final res = await _api.verifyEmail(token: token);
    return res;
  }

  // -------------------------------------------
  // • Profil neu laden
  // -------------------------------------------
  Future<UserProfile> refreshProfile() async {
    final user = await _api.me();
    _session.updateUser(user);
    return user;
  }

  // -------------------------------------------
  // • Google Login (Stub / später für 1.1)
  // -------------------------------------------
  Future<UserProfile> loginWithGoogle(String idToken) async {
    final tokens = await _api.loginWithGoogle(idToken: idToken);
    _session.updateTokens(tokens.accessToken, refresh: tokens.refreshToken);

    final user = await _api.me();
    _session.updateUser(user);
    return user;
  }

  // -------------------------------------------
  // • Apple Login (Stub / später für 1.1)
  // -------------------------------------------
  Future<UserProfile> loginWithApple(String identityToken) async {
    final tokens = await _api.loginWithApple(identityToken: identityToken);
    _session.updateTokens(tokens.accessToken, refresh: tokens.refreshToken);

    final user = await _api.me();
    _session.updateUser(user);
    return user;
  }

  // -------------------------------------------
  // • Logout
  // -------------------------------------------
  void logout() {
    _session.clear();
  }

  // -------------------------------------------
  // • Forgot Password (Reset via Mail)
  // -------------------------------------------
  Future<void> requestPasswordReset(String email) async {
    await _api.requestPasswordReset(email: email);
  }

}
