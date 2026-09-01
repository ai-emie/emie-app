// ===============================================
// Emie • Auth Controller
// Pfad: lib/features/auth/controller/auth_controller.dart
// ===============================================

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  //
  // Wird ausschließlich intern für die Auswahl
  // verständlicher UI-Fehlermeldungen verwendet.
  // Der Inhalt wird niemals geloggt.
  String? _extractDetail(DioException e) {
    final data = e.response?.data;

    if (data is Map) {
      final detail = data['detail'];

      if (detail is String) {
        return detail;
      }
    }

    return null;
  }

  // -------------------------------------------
  //  SICHERES DIO DEBUG-LOGGING
  // -------------------------------------------
  //
  // Ausschließlich metadata-only:
  // - HTTP Status
  // - DioExceptionType
  //
  // Niemals:
  // - Response Body
  // - Backend Detail
  // - E-Mail
  // - Passwort
  // - Access-/Refresh-Token
  // - Google-/Apple-ID-Token
  // - komplette Exception
  void _debugDio(
    String source,
    DioException error,
  ) {
    if (!kDebugMode) return;

    debugPrint(
      '$source: '
      'status=${error.response?.statusCode ?? '-'}, '
      'type=${error.type}',
    );
  }

  // -------------------------------------------
  //  SICHERES GENERISCHES DEBUG-LOGGING
  // -------------------------------------------
  //
  // Nur Exception-Klasse ausgeben.
  // Kein toString(), keine Message, kein Stacktrace.
  void _debugErrorType(
    String source,
    Object error,
  ) {
    if (!kDebugMode) return;

    debugPrint(
      '$source: ${error.runtimeType}',
    );
  }

  // -------------------------------------------
  //  LOGIN MIT E-MAIL
  // -------------------------------------------
  Future<bool> loginWithEmail(
    String email,
    String password,
  ) async {
    _setError(null);
    _setLoading(true);

    try {
      await _repo.loginWithEmail(
        email,
        password,
      );

      return true;
    } on DioException catch (e) {
      final apiError = ApiError.fromDio(e);
      final status = e.response?.statusCode ?? 0;

      final detailRaw = _extractDetail(e);
      final detail =
          detailRaw?.toLowerCase() ?? '';

      if (status == 401) {
        if (detail.contains('unknown email')) {
          _setError(
            'Diese E-Mail ist nicht registriert.',
          );
        } else if (detail.contains('wrong password')) {
          _setError(
            'Das Passwort ist falsch.',
          );
        } else if (detail.contains('not verified')) {
          _setError(
            'Bitte bestätige zuerst deine E-Mail.',
          );
        } else {
          _setError(
            'E-Mail oder Passwort ist falsch.',
          );
        }
      } else if (status >= 500) {
        _setError(
          'Serverfehler. Bitte versuch es später erneut.',
        );
      } else {
        _setError(
          apiError.message,
        );
      }

      _debugDio(
        'loginWithEmail DioException',
        e,
      );

      return false;
    } catch (e) {
      _setError(
        'Login fehlgeschlagen. '
        'Bitte versuch es später erneut.',
      );

      _debugErrorType(
        'loginWithEmail unknown error',
        e,
      );

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

      return true;
    } on DioException catch (e) {
      final apiError = ApiError.fromDio(e);
      final status = e.response?.statusCode ?? 0;

      final detailRaw = _extractDetail(e);
      final detail =
          detailRaw?.toLowerCase() ?? '';

      if (status == 400 || status == 409) {
        if (detail.contains('already registered') ||
            detail.contains('already exists') ||
            detail.contains('email taken')) {
          _setError(
            'Diese E-Mail ist bereits registriert.',
          );
        } else {
          _setError(
            apiError.message,
          );
        }
      } else if (status >= 500) {
        _setError(
          'Serverfehler. Bitte versuch es später erneut.',
        );
      } else {
        _setError(
          apiError.message,
        );
      }

      _debugDio(
        'registerWithEmail DioException',
        e,
      );

      return false;
    } catch (e) {
      _setError(
        'Registrierung fehlgeschlagen. '
        'Versuche es später erneut.',
      );

      _debugErrorType(
        'registerWithEmail unknown error',
        e,
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------------------------
  //  E-MAIL BESTÄTIGEN
  // -------------------------------------------
  Future<bool> verifyEmail(
    String token,
  ) async {
    _setError(null);
    _setLoading(true);

    try {
      await _repo.verifyEmail(token);

      return true;
    } on DioException catch (e) {
      final apiError = ApiError.fromDio(e);
      final status = e.response?.statusCode ?? 0;

      final detailRaw = _extractDetail(e);
      final detail =
          detailRaw?.toLowerCase() ?? '';

      if (status == 400 || status == 401) {
        if (detail.contains('expired') ||
            detail.contains('invalid')) {
          _setError(
            'Bestätigung fehlgeschlagen. '
            'Der Link ist ungültig oder abgelaufen.',
          );
        } else {
          _setError(
            apiError.message,
          );
        }
      } else if (status >= 500) {
        _setError(
          'Serverfehler. Bitte versuch es später erneut.',
        );
      } else {
        _setError(
          apiError.message,
        );
      }

      _debugDio(
        'verifyEmail DioException',
        e,
      );

      return false;
    } catch (e) {
      _setError(
        'Bestätigung fehlgeschlagen. '
        'Link vielleicht abgelaufen.',
      );

      _debugErrorType(
        'verifyEmail unknown error',
        e,
      );

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
      _setError(
        'Apple Login ist nur auf Apple-Geräten verfügbar.',
      );

      return false;
    }

    _setLoading(true);

    try {
      final credential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken =
          credential.identityToken;

      if (idToken == null) {
        _setError(
          'Apple Login fehlgeschlagen '
          '(kein ID-Token erhalten).',
        );

        return false;
      }

      await _repo.loginWithApple(
        idToken,
      );

      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        _setError(
          'Apple Login abgebrochen.',
        );
      } else {
        _setError(
          'Apple Login fehlgeschlagen. '
          'Versuche es später erneut.',
        );
      }

      if (kDebugMode) {
        debugPrint(
          'loginWithApple auth error: '
          'code=${e.code}',
        );
      }

      return false;
    } on DioException catch (e) {
      final apiError =
          ApiError.fromDio(e);

      _setError(
        apiError.message,
      );

      _debugDio(
        'loginWithApple DioException',
        e,
      );

      return false;
    } catch (e) {
      _setError(
        'Apple Login fehlgeschlagen. '
        'Versuche es später erneut.',
      );

      _debugErrorType(
        'loginWithApple unknown error',
        e,
      );

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
      // ---------------------------------------
      // Google Sign-In konfigurieren
      // ---------------------------------------
      //
      // Android liest die Server/Web-Client-ID
      // über google-services.json +
      // com.google.gms.google-services.
      //
      // Deshalb hier bewusst keine Client-ID
      // hart im Dart-Code hinterlegen.

      final googleSignIn = GoogleSignIn(
        scopes: const ['email'],
      );

      // ---------------------------------------
      // Google Dialog öffnen
      // ---------------------------------------

      final account =
          await googleSignIn.signIn();

      // User hat den Dialog freiwillig geschlossen.
      //
      // Das ist kein Fehler und wird deshalb
      // UI-seitig komplett lautlos behandelt.
      if (account == null) {
        return false;
      }

      // ---------------------------------------
      // Google ID-Token holen
      // ---------------------------------------

      final googleAuth =
          await account.authentication;

      final idToken =
          googleAuth.idToken;

      if (idToken == null ||
          idToken.isEmpty) {
        _setError(
          'Google-Anmeldung konnte nicht '
          'abgeschlossen werden. '
          'Bitte versuch es erneut.',
        );

        if (kDebugMode) {
          debugPrint(
            'Google Login: '
            'Google lieferte kein ID-Token.',
          );
        }

        return false;
      }

      // ---------------------------------------
      // ID-Token an Emie Backend
      // ---------------------------------------
      //
      // POST /v1/auth/google
      //
      // Das Backend verifiziert:
      // - Google-Signatur
      // - issuer
      // - audience / Web Client ID
      //
      // Danach speichert das Repository die
      // Emie Access- und Refresh-Tokens und lädt
      // den User in den SessionStore.

      await _repo.loginWithGoogle(
        idToken,
      );

      return true;
    } on PlatformException catch (e) {
      // ---------------------------------------
      // Google / Android Plugin Fehler
      // ---------------------------------------

      final code =
          e.code.toLowerCase();

      // Echter User-Cancel:
      // keine Fehlermeldung anzeigen.
      if (code ==
              GoogleSignIn.kSignInCanceledError ||
          code == 'sign_in_canceled' ||
          code == 'canceled' ||
          code == 'cancelled') {
        if (kDebugMode) {
          debugPrint(
            'Google Login vom Benutzer abgebrochen.',
          );
        }

        return false;
      }

      // Netzwerkproblem
      if (code ==
              GoogleSignIn.kNetworkError ||
          code.contains('network')) {
        _setError(
          'Keine Verbindung zu Google. '
          'Bitte prüfe deine Internetverbindung.',
        );
      } else {
        // Darunter fallen beispielsweise
        // Google-Konfigurations- oder
        // Play-Services-Probleme.
        _setError(
          'Google-Anmeldung ist gerade '
          'nicht verfügbar. '
          'Bitte versuch es erneut.',
        );
      }

      // Provider-Message bewusst nicht loggen.
      // Nur der technische Error-Code ist erlaubt.
      if (kDebugMode) {
        debugPrint(
          'Google PlatformException: '
          'code=${e.code}',
        );
      }

      return false;
    } on DioException catch (e) {
      // ---------------------------------------
      // Emie Backend / Netzwerk
      // ---------------------------------------

      final status =
          e.response?.statusCode ?? 0;

      final isConnectionError =
          e.type ==
                  DioExceptionType.connectionError ||
              e.type ==
                  DioExceptionType.connectionTimeout ||
              e.type ==
                  DioExceptionType.sendTimeout ||
              e.type ==
                  DioExceptionType.receiveTimeout;

      if (isConnectionError) {
        _setError(
          'Keine Verbindung zu Emie. '
          'Bitte prüfe deine Internetverbindung.',
        );
      } else if (status == 400 ||
          status == 401) {
        _setError(
          'Google-Anmeldung konnte nicht '
          'verifiziert werden. '
          'Bitte versuch es erneut.',
        );
      } else if (status >= 500) {
        _setError(
          'Emie ist gerade nicht erreichbar. '
          'Bitte versuch es später erneut.',
        );
      } else {
        final apiError =
            ApiError.fromDio(e);

        _setError(
          apiError.message.isNotEmpty
              ? apiError.message
              : 'Google-Anmeldung fehlgeschlagen.',
        );
      }

      _debugDio(
        'Google Backend DioException',
        e,
      );

      return false;
    } on SocketException catch (e) {
      _setError(
        'Keine Internetverbindung. '
        'Bitte prüfe deine Verbindung.',
      );

      _debugErrorType(
        'Google SocketException',
        e,
      );

      return false;
    } catch (e) {
      _setError(
        'Google-Anmeldung fehlgeschlagen. '
        'Bitte versuch es erneut.',
      );

      _debugErrorType(
        'Google Login unknown error',
        e,
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------------------------
  //  APP BOOTSTRAP / SESSION WIEDERHERSTELLEN
  // -------------------------------------------
  Future<void> bootstrapSession() async {
    final session =
        SessionStore.instance;

    session.beginBootstrap();

    try {
      // 1) Gespeicherte Tokens laden
      await session.restoreSession();

      final hasAccess =
          session.accessToken != null &&
              session.accessToken!.isNotEmpty;

      final hasRefresh =
          session.hasRefreshToken;

      // 2) Gar keine Tokens → Login
      if (!hasAccess && !hasRefresh) {
        return;
      }

      // 3) Profil laden.
      //
      // Falls der Access-Token abgelaufen ist,
      // übernimmt der Dio-Interceptor:
      //
      // 401
      // → /v1/auth/refresh
      // → neue Tokens speichern
      // → /v1/me erneut ausführen
      //
      // Falls auch Refresh fehlschlägt,
      // löscht der ApiClient Storage + Session.

      await _repo.refreshProfile();
    } on DioException catch (e) {
      _debugDio(
        'Bootstrap Session DioException',
        e,
      );
    } catch (e) {
      _debugErrorType(
        'Bootstrap Session unknown error',
        e,
      );
    } finally {
      session.finishBootstrap();
    }
  }

  // -------------------------------------------
  //  LOGOUT
  // -------------------------------------------
  Future<void> logout() async {
    // 1) Google Sign-In lokal abmelden
    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email'],
      );

      await googleSignIn.signOut();

      // Optional härter:
      // await googleSignIn.disconnect();
    } catch (e) {
      _debugErrorType(
        'Google SignOut Fehler',
        e,
      );
    }

    // 2) Emie-Session + Secure Storage löschen
    await _repo.logout();

    // 3) Fehlerstatus zurücksetzen
    _setError(null);

    notifyListeners();
  }

  // -------------------------------------------
  //  ACCOUNT LÖSCHEN
  // -------------------------------------------
  Future<bool> deleteAccount() async {
    _setError(null);
    _setLoading(true);

    try {
      // Account zuerst serverseitig löschen.
      //
      // Das Repository entfernt die lokale Session
      // erst NACH erfolgreichem DELETE /v1/me.
      await _repo.deleteAccount();

      // Google lokal best-effort abmelden.
      //
      // Ein Fehler hier ?ndert nichts daran, dass der
      // Emie-Account bereits erfolgreich gelöscht wurde.
      try {
        final googleSignIn = GoogleSignIn(
          scopes: const ['email'],
        );

        await googleSignIn.signOut();
      } catch (e) {
        _debugErrorType(
          'Google SignOut nach Account-Löschung',
          e,
        );
      }

      _setError(null);

      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;

      final isConnectionError =
          e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout;

      if (isConnectionError) {
        _setError(
          'Account konnte nicht gelöscht werden. '
          'Bitte prüfe deine Internetverbindung.',
        );
      } else if (status == 401) {
        _setError(
          'Deine Sitzung ist abgelaufen. '
          'Bitte melde dich erneut an.',
        );
      } else if (status >= 500) {
        _setError(
          'Account konnte gerade nicht gelöscht werden. '
          'Bitte versuch es später erneut.',
        );
      } else {
        _setError(
          'Account konnte nicht gelöscht werden. '
          'Bitte versuch es erneut.',
        );
      }

      _debugDio(
        'deleteAccount DioException',
        e,
      );

      return false;
    } catch (e) {
      _setError(
        'Account konnte nicht gelöscht werden. '
        'Bitte versuch es später erneut.',
      );

      _debugErrorType(
        'deleteAccount unknown error',
        e,
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // -------------------------------------------
  //  Forgot Password
  // -------------------------------------------
  Future<bool> requestPasswordReset(
    String email,
  ) async {
    _setLoading(true);
    _setError(null);

    try {
      await _repo.requestPasswordReset(
        email,
      );

      return true;
    } on DioException catch (e) {
      final apiError =
          ApiError.fromDio(e);

      _setError(
        apiError.message.isNotEmpty
            ? apiError.message
            : 'Reset aktuell nicht verfügbar.',
      );

      _debugDio(
        'requestPasswordReset DioException',
        e,
      );

      return false;
    } catch (e) {
      _setError(
        'Reset aktuell nicht verfügbar.',
      );

      _debugErrorType(
        'requestPasswordReset unknown error',
        e,
      );

      return false;
    } finally {
      _setLoading(false);
    }
  }
}
