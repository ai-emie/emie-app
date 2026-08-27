// ===============================================
// Emie • Auth Controller
// Pfad: lib/features/auth/controller/auth_controller.dart
// ===============================================

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../api/api_error.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../state/session_store.dart';

class AuthController extends ChangeNotifier {
  AuthController() : _repo = AuthRepository();

  final AuthRepository _repo;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() => _setError(null);

  // -------------------------------------------
  //  Hilfsfunktion: Detail aus Dio-Error holen
  // -------------------------------------------
  String? _extractDetail(DioException e) {
    final data = e.response?.data;

    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
    }

    return null;
  }

  // -------------------------------------------
  //  LOGIN MIT E-MAIL (spezifische Fehlertexte)
  // -------------------------------------------
  Future<bool> loginWithEmail(String email, String password) async {
    _setError(null);
    _setLoading(true);

    try {
      await _repo.loginWithEmail(email, password);
      return true;
    } on DioException catch (e) {
      final apiError = ApiError.fromDio(e);
      final status = e.response?.statusCode ?? 0;
      final detailRaw = _extractDetail(e);
      final detail = detailRaw?.toLowerCase() ?? '';

      // 401 = Auth-Fehler → eigene Texte, niemals generischer "nicht eingeloggt"-Text
      if (status == 401) {
        if (detail.contains('unknown email')) {
          _setError('Diese E-Mail ist nicht registriert.');
        } else if (detail.contains('wrong password')) {
          _setError('Das Passwort ist falsch.');
        } else if (detail.contains('not verified')) {
          _setError('Bitte bestätige zuerst deine E-Mail.');
        } else {
          _setError('E-Mail oder Passwort ist falsch.');
        }
      } else if (status >= 500) {
        _setError('Serverfehler. Bitte versuch es später erneut.');
      } else {
        _setError(apiError.message);
      }

      if (kDebugMode) {
        // ignore: avoid_print
        print(
            'loginWithEmail DioException: status=$status, detail=$detailRaw, apiError=${apiError.message}');
      }
      return false;
    } catch (e) {
      _setError('Login fehlgeschlagen. Bitte versuch es später erneut.');
      if (kDebugMode) {
        // ignore: avoid_print
        print('loginWithEmail unknown error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------------------------
  //  REGISTRIERUNG (ohne Auto-Login)
  // -------------------------------------------
  Future<bool> registerWithEmail(
    String name,
    String email,
    String password,
  ) async {
    _setError(null);
    _setLoading(true);

    try {
      await _repo.registerWithEmail(
        name: name,
        email: email,
        password: password,
      );

      // Erfolg: UI zeigt SnackBar + wechselt auf Login-Modus
      return true;
    } on DioException catch (e) {
      final apiError = ApiError.fromDio(e);
      final status = e.response?.statusCode ?? 0;
      final detailRaw = _extractDetail(e);
      final detail = detailRaw?.toLowerCase() ?? '';

      if (status == 400 || status == 409) {
        if (detail.contains('already registered') ||
            detail.contains('already exists') ||
            detail.contains('email taken')) {
          _setError('Diese E-Mail ist bereits registriert.');
        } else {
          _setError(apiError.message);
        }
      } else if (status >= 500) {
        _setError('Serverfehler. Bitte versuch es später erneut.');
      } else {
        _setError(apiError.message);
      }

      if (kDebugMode) {
        // ignore: avoid_print
        print(
            'registerWithEmail DioException: status=$status, detail=$detailRaw, apiError=${apiError.message}');
      }
      return false;
    } catch (e) {
      _setError(
        'Registrierung fehlgeschlagen. Versuche es später erneut.',
      );
      if (kDebugMode) {
        // ignore: avoid_print
        print('registerWithEmail unknown error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------------------------
  //  E-MAIL BESTÄTIGEN (Verify-Link)
  // -------------------------------------------
  Future<bool> verifyEmail(String token) async {
    _setError(null);
    _setLoading(true);

    try {
      await _repo.verifyEmail(token);
      return true;
    } on DioException catch (e) {
      final apiError = ApiError.fromDio(e);
      final status = e.response?.statusCode ?? 0;
      final detailRaw = _extractDetail(e);
      final detail = detailRaw?.toLowerCase() ?? '';

      if (status == 400 || status == 401) {
        if (detail.contains('expired') || detail.contains('invalid')) {
          _setError(
            'Bestätigung fehlgeschlagen. Der Link ist ungültig oder abgelaufen.',
          );
        } else {
          _setError(apiError.message);
        }
      } else if (status >= 500) {
        _setError('Serverfehler. Bitte versuch es später erneut.');
      } else {
        _setError(apiError.message);
      }

      if (kDebugMode) {
        // ignore: avoid_print
        print(
            'verifyEmail DioException: status=$status, detail=$detailRaw, apiError=${apiError.message}');
      }
      return false;
    } catch (e) {
      _setError('Bestätigung fehlgeschlagen. Link vielleicht abgelaufen.');
      if (kDebugMode) {
        // ignore: avoid_print
        print('verifyEmail unknown error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------------------------
  //  APPLE LOGIN (native, iOS/macOS)
  // -------------------------------------------
  Future<bool> loginWithApple() async {
    _setError(null);

    if (!Platform.isIOS && !Platform.isMacOS) {
      _setError('Apple Login ist nur auf Apple-Geräten verfügbar.');
      return false;
    }

    _setLoading(true);

    try {
      // Apple-Dialog öffnen
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        _setError('Apple Login fehlgeschlagen (kein ID-Token erhalten).');
        return false;
      }

      await _repo.loginWithApple(idToken);
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        _setError('Apple Login abgebrochen.');
      } else {
        _setError('Apple Login fehlgeschlagen. Versuche es später erneut.');
      }
      if (kDebugMode) {
        // ignore: avoid_print
        print('loginWithApple auth error: $e');
      }
      return false;
    } on DioException catch (e) {
      final apiError = ApiError.fromDio(e);
      _setError(apiError.message);
      if (kDebugMode) {
        // ignore: avoid_print
        print('loginWithApple DioException: ${apiError.message}');
      }
      return false;
    } catch (e) {
      _setError('Apple Login fehlgeschlagen. Versuche es später erneut.');
      if (kDebugMode) {
        // ignore: avoid_print
        print('loginWithApple unknown error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------------------------
  //  GOOGLE LOGIN (Android / iOS)
  // -------------------------------------------
  Future<bool> loginWithGoogle() async {
  _setError(null);
  _setLoading(true);

  try {
    // Google Sign-In konfigurieren
    final googleSignIn = GoogleSignIn(
      scopes: const ['email'],
    );


    // Login anstoßen
    final account = await googleSignIn.signIn();
    if (account == null) {
      _setError('Google Login abgebrochen.');
      return false;
    }

    // Tokens holen
    final auth = await account.authentication;
    final idToken = auth.idToken;

    if (idToken == null) {
      _setError('Google Login fehlgeschlagen (kein ID-Token).');
      return false;
    }

    // An Backend schicken → /v1/auth/google
    await _repo.loginWithGoogle(idToken);

    return true;

  } catch (e, st) {
    debugPrint('Google Login Error: $e\n$st');
    _setError('Google Login fehlgeschlagen.');
    return false;
  } finally {
    _setLoading(false);
  }
}

  // -------------------------------------------
  //  APP BOOTSTRAP / SESSION WIEDERHERSTELLEN
  // -------------------------------------------
  Future<void> bootstrapSession() async {
    final session = SessionStore.instance;

    session.beginBootstrap();

    try {
      // 1) Gespeicherte Tokens aus Secure Storage laden
      await session.restoreSession();

      final hasAccess =
          session.accessToken != null && session.accessToken!.isNotEmpty;

      final hasRefresh = session.hasRefreshToken;

      // 2) Gar keine Tokens vorhanden → Login
      if (!hasAccess && !hasRefresh) {
        return;
      }

      // 3) Profil laden.
      //
      // Falls der Access-Token abgelaufen ist, übernimmt unser
      // Dio-Interceptor automatisch:
      //
      // 401
      // → /v1/auth/refresh
      // → neue Tokens speichern
      // → /v1/me erneut ausführen
      //
      // Falls auch der Refresh fehlschlägt, löscht Step 8
      // Secure Storage + Session vollständig.
      await _repo.refreshProfile();
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Bootstrap Session fehlgeschlagen: '
          'status=${e.response?.statusCode}, error=${e.message}',
        );
      }

      // Bei 401 wurde die tote Session bereits zentral
      // vom Auth-Interceptor vollständig gelöscht.
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Bootstrap Session unbekannter Fehler: $e');
      }
    } finally {
      // Egal wie der Check endet:
      // Die App darf danach Loading verlassen.
      session.finishBootstrap();
    }
  }

// -------------------------------------------
//  LOGOUT
// -------------------------------------------
Future<void> logout() async {
  // 1) Google Sign-In abmelden (falls genutzt)
  try {
    final googleSignIn = GoogleSignIn(
      scopes: const ['email'],
    );

    await googleSignIn.signOut();

    // Optional härter, falls Google lokal hängen bleibt:
    // await googleSignIn.disconnect();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Google SignOut Fehler: $e');
    }
  }

  // 2) Emie-Session + Secure Storage löschen
  await _repo.logout();

  // 3) Fehlerstatus zurücksetzen + UI informieren
  _setError(null);
  notifyListeners();
}

  // -------------------------------------------
  //  Forgot Password (Reset via Mail)
  // -------------------------------------------
  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);
    _setError(null);

    try {
      await _repo.requestPasswordReset(email);
      return true;
    } on DioException catch (e) {
      final apiError = ApiError.fromDio(e);

      // Wichtig: keine Info-Leaks. Immer generisch bleiben.
      _setError(apiError.message.isNotEmpty
          ? apiError.message
          : 'Reset aktuell nicht verfügbar.');
      return false;
    } catch (_) {
      _setError('Reset aktuell nicht verfügbar.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

}
