// ===============================================
// Emie • Auth Repository
// Pfad: lib/data/auth/auth_repository.dart
// ===============================================

import '../../core/storage/secure_storage.dart';
import '../../state/session_store.dart';
import 'auth_api.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository({AuthApi? api}) : _api = api ?? AuthApi();

  final AuthApi _api;
  final SessionStore _session = SessionStore.instance;

  // -------------------------------------------
  // • Login via E-Mail & Passwort
  // -------------------------------------------
  Future<UserProfile> loginWithEmail(
    String email,
    String password,
  ) async {
    final tokens = await _api.login(
      email: email,
      password: password,
    );

    _session.updateTokens(
      tokens.accessToken,
      refresh: tokens.refreshToken,
    );

    await SecureStorageService.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    final user = await _api.me();
    _session.updateUser(user);

    return user;
  }

  // -------------------------------------------
  // • Registrierung (ohne Auto-Login)
  // -------------------------------------------
  Future<VerifyResponse> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _api.register(
      name: name,
      email: email,
      password: password,
    );

    return res;
  }

  // -------------------------------------------
  // • E-Mail-Bestätigung
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
  // • Google Login
  // -------------------------------------------
  Future<UserProfile> loginWithGoogle(String idToken) async {
    final tokens = await _api.loginWithGoogle(
      idToken: idToken,
    );

    _session.updateTokens(
      tokens.accessToken,
      refresh: tokens.refreshToken,
    );

    await SecureStorageService.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    final user = await _api.me();
    _session.updateUser(user);

    return user;
  }

  // -------------------------------------------
  // • Apple Login
  // -------------------------------------------
  Future<UserProfile> loginWithApple(String identityToken) async {
    final tokens = await _api.loginWithApple(
      identityToken: identityToken,
    );

    _session.updateTokens(
      tokens.accessToken,
      refresh: tokens.refreshToken,
    );

    await SecureStorageService.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    final user = await _api.me();
    _session.updateUser(user);

    return user;
  }

  // -------------------------------------------
  // • Token Refresh
  // -------------------------------------------
  Future<void> refreshTokens() async {
    final refreshToken = _session.refreshToken;

    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('Kein Refresh-Token vorhanden.');
    }

    final tokens = await _api.refresh(
      refreshToken: refreshToken,
    );

    _session.updateTokens(
      tokens.accessToken,
      refresh: tokens.refreshToken,
    );

    await SecureStorageService.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }

  // -------------------------------------------
  // • Logout
  // -------------------------------------------
  Future<void> logout() async {
    final refreshToken = _session.refreshToken;

    try {
      // Refresh-Token zuerst serverseitig widerrufen.
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _api.logout(
          refreshToken: refreshToken,
        );
      }
    } catch (_) {
      // Backend-/Netzwerkfehler dürfen den lokalen Logout
      // niemals verhindern.
    } finally {
      // Lokale Tokens und Session werden garantiert gelöscht.
      await SecureStorageService.clearTokens();
      _session.clear();
    }
  }

  // -------------------------------------------
  // • Forgot Password
  // -------------------------------------------
  Future<void> requestPasswordReset(String email) async {
    await _api.requestPasswordReset(
      email: email,
    );
  }
}