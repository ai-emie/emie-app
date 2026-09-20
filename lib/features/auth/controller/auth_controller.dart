// ===============================================
// Emie • Auth Controller
// Pfad: lib/features/auth/controller/auth_controller.dart
// ===============================================

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../api/api_error.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/auth/auth_models.dart';
import '../../../data/auth/apple_confirmation_models.dart';
import '../../../data/auth/apple_confirmation_native.dart';
import '../../../state/session_store.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthRepository? repository}) : _repo = repository ?? AuthRepository() {
    _session.addListener(_sessionChanged);
  }

  final AuthRepository _repo;

  final SessionStore _session = SessionStore.instance;
  bool _disposed = false;
  bool _isLoading = false;
  String? _errorMessage;
  _AuthAction? _action;
  AccountDeletionResult? _deletionNotice;
  int? _noticeGeneration;
  Object? _dismissedNotice;
  AccountDeletionOperation? _dialogOperation;
  AppleConfirmationOperation? _appleConfirmation;

  /// Explicit, currently unconnected entry point. Does not begin a login.
  Future<AppleConfirmationResult> confirmAppleAccount() async {
    _appleConfirmation?.invalidate();
    final operation = AppleConfirmationOperation(_session.generation);
    _appleConfirmation = operation;
    bool owns() => !_disposed && identical(_appleConfirmation, operation) &&
        operation.valid && _session.isCurrent(operation.originGeneration) && _session.isAuthenticated;
    final native = AppleConfirmationNative();
    try {
      if (!owns()) return const AppleConfirmationResult(AppleConfirmationOutcome.stale);
      if (!native.isSupported) return const AppleConfirmationResult(AppleConfirmationOutcome.notAvailable);
      final beginning = await _repo.beginAppleConfirmation(operation, owns: owns);
      if (!owns()) return const AppleConfirmationResult(AppleConfirmationOutcome.stale);
      if (beginning != null) return beginning;
      final proof = await native.request(nonce: operation.nonce!, state: operation.state!, isCurrent: owns);
      if (!owns()) return const AppleConfirmationResult(AppleConfirmationOutcome.stale);
      final AppleConfirmationResult result;
      if (proof.status == AppleConfirmationNativeStatus.cancelled) {
        result = await _repo.cancelAppleConfirmation(operation, owns: owns);
      } else if (proof.status != AppleConfirmationNativeStatus.proof) {
        return const AppleConfirmationResult(AppleConfirmationOutcome.notAvailable);
      } else if (proof.identityToken?.isNotEmpty != true || proof.state == null || proof.state != operation.state) {
        return const AppleConfirmationResult(AppleConfirmationOutcome.invalidProof);
      } else {
        result = await _repo.finishAppleConfirmation(operation,
            identityToken: proof.identityToken!, state: proof.state!, owns: owns);
      }
      if (!owns()) return const AppleConfirmationResult(AppleConfirmationOutcome.stale);
      return result;
    } catch (_) {
      return AppleConfirmationResult(owns() ? AppleConfirmationOutcome.unconfirmed : AppleConfirmationOutcome.stale);
    } finally {
      operation.forgetChallenge();
    }
  }

  bool get isLoading => _isLoading && _action != null && _owns(_action!);
  String? get errorMessage => _errorMessage;
  AccountDeletionResult? get deletionNotice => _deletionNotice;

  bool _owns(_AuthAction action) => !_disposed && identical(_action, action) &&
      _session.canFinish(action.origin);

  _AuthAction _beginAction({bool login = false, bool bootstrap = false, bool loading = true}) {
    final origin = login ? _session.beginSession() :
        bootstrap ? _session.beginBootstrap() : _session.generation;
    final action = _AuthAction(origin);
    if (!_session.isCurrent(origin)) return action;
    _action = action;
    _errorMessage = null;
    _isLoading = loading;
    if (!_disposed) notifyListeners();
    return action;
  }

  void _setActionError(_AuthAction action, String? message) {
    if (!_owns(action)) return;
    _errorMessage = message;
    notifyListeners();
  }

  void _finishAction(_AuthAction action) {
    if (!_owns(action)) return;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_disposed) return;
    if (_appleConfirmation != null && !_session.isCurrent(_appleConfirmation!.originGeneration)) {
      _appleConfirmation!.invalidate();
      _appleConfirmation = null;
    }
    if (_action != null && !_session.canFinish(_action!.origin)) {
      _action = null;
      _errorMessage = null;
      _isLoading = false;
    }
    if (_noticeGeneration != null && !_session.isCurrent(_noticeGeneration!)) {
      _deletionNotice = null;
      _noticeGeneration = null;
    }
    notifyListeners();
  }

  void dismissDeletionNotice() {
    _dismissedNotice = _deletionNotice?.operation.id;
    _deletionNotice = null;
    _noticeGeneration = null;
    if (!_disposed) notifyListeners();
  }

  void _showDeletionResult(_AuthAction action, AccountDeletionResult result) {
    final visibleGeneration = result.completionGeneration ?? result.operation.originGeneration;
    if (!_owns(action) || !_session.isCurrent(visibleGeneration) ||
        result.server == DeletionServerResult.notSent ||
        result.sessionEnd == LocalSessionEnd.differentSession ||
        identical(_dismissedNotice, result.operation.id)) {
      return;
    }
    _deletionNotice = result;
    _noticeGeneration = visibleGeneration;
    notifyListeners();
  }

  // Only Google plugin calls share this queue. No HTTP request holds its lock.
  static Future<void>? _googleTail;
  static Future<T?> _orderedGoogle<T>(bool Function() isCurrent, Future<T> Function() action) {
    final previous = _googleTail;
    final released = Completer<void>();
    _googleTail = released.future;
    return () async {
      if (previous != null) await previous;
      try {
        if (!isCurrent()) return null;
        return await action();
      } finally {
        if (identical(_googleTail, released.future)) _googleTail = null;
        released.complete();
      }
    }();
  }

  Future<LocalCleanupStep> _googleSignOut(int completion) async {
    try {
      final ran = await _orderedGoogle<bool>(() => _session.isCurrent(completion), () async {
        await GoogleSignIn(scopes: const ['email']).signOut();
        return true;
      });
      return ran == true ? LocalCleanupStep.confirmed : LocalCleanupStep.differentSession;
    } catch (_) {
      return LocalCleanupStep.unconfirmed;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _appleConfirmation?.invalidate();
    _session.removeListener(_sessionChanged);
    super.dispose();
  }

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
    final action = _beginAction(login: true);
    _setActionError(action, null);


    try {
      await _repo.loginWithEmail(
        email,
        password,
        generation: action.origin,
      );

      return _owns(action) && _session.isCurrent(action.origin);
    } on DioException catch (e) {
      final apiError = ApiError.fromDio(e);
      final status = e.response?.statusCode ?? 0;

      final detailRaw = _extractDetail(e);
      final detail =
          detailRaw?.toLowerCase() ?? '';

      if (status == 401) {
        if (detail.contains('unknown email')) {
          _setActionError(action,
            'Diese E-Mail ist nicht registriert.',
          );
        } else if (detail.contains('wrong password')) {
          _setActionError(action,
            'Das Passwort ist falsch.',
          );
        } else if (detail.contains('not verified')) {
          _setActionError(action,
            'Bitte bestätige zuerst deine E-Mail.',
          );
        } else {
          _setActionError(action,
            'E-Mail oder Passwort ist falsch.',
          );
        }
      } else if (status >= 500) {
        _setActionError(action,
          'Serverfehler. Bitte versuch es später erneut.',
        );
      } else {
        _setActionError(action,
          apiError.message,
        );
      }

      _debugDio(
        'loginWithEmail DioException',
        e,
      );

      return false;
    } catch (e) {
      _setActionError(action,
        'Login fehlgeschlagen. '
        'Bitte versuch es später erneut.',
      );

      _debugErrorType(
        'loginWithEmail unknown error',
        e,
      );

      return false;
    } finally {
      _finishAction(action);
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
    final action = _beginAction();
    _setActionError(action, null);


    try {
      await _repo.registerWithEmail(
        name: name,
        email: email,
        password: password,
        generation: action.origin,
      );

      return _owns(action) && _session.isCurrent(action.origin);
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
          _setActionError(action,
            'Diese E-Mail ist bereits registriert.',
          );
        } else {
          _setActionError(action,
            apiError.message,
          );
        }
      } else if (status >= 500) {
        _setActionError(action,
          'Serverfehler. Bitte versuch es später erneut.',
        );
      } else {
        _setActionError(action,
          apiError.message,
        );
      }

      _debugDio(
        'registerWithEmail DioException',
        e,
      );

      return false;
    } catch (e) {
      _setActionError(action,
        'Registrierung fehlgeschlagen. '
        'Versuche es später erneut.',
      );

      _debugErrorType(
        'registerWithEmail unknown error',
        e,
      );

      return false;
    } finally {
      _finishAction(action);
    }
  }

  // -------------------------------------------
  //  E-MAIL BESTÄTIGEN
  // -------------------------------------------
  Future<bool> verifyEmail(
    String token,
  ) async {
    final action = _beginAction();
    _setActionError(action, null);


    try {
      await _repo.verifyEmail(token, generation: action.origin);

      return _owns(action) && _session.isCurrent(action.origin);
    } on DioException catch (e) {
      final apiError = ApiError.fromDio(e);
      final status = e.response?.statusCode ?? 0;

      final detailRaw = _extractDetail(e);
      final detail =
          detailRaw?.toLowerCase() ?? '';

      if (status == 400 || status == 401) {
        if (detail.contains('expired') ||
            detail.contains('invalid')) {
          _setActionError(action,
            'Bestätigung fehlgeschlagen. '
            'Der Link ist ungültig oder abgelaufen.',
          );
        } else {
          _setActionError(action,
            apiError.message,
          );
        }
      } else if (status >= 500) {
        _setActionError(action,
          'Serverfehler. Bitte versuch es später erneut.',
        );
      } else {
        _setActionError(action,
          apiError.message,
        );
      }

      _debugDio(
        'verifyEmail DioException',
        e,
      );

      return false;
    } catch (e) {
      _setActionError(action,
        'Bestätigung fehlgeschlagen. '
        'Link vielleicht abgelaufen.',
      );

      _debugErrorType(
        'verifyEmail unknown error',
        e,
      );

      return false;
    } finally {
      _finishAction(action);
    }
  }

  // -------------------------------------------
  //  APPLE LOGIN (native, iOS/macOS)
  // -------------------------------------------
  Future<bool> loginWithApple() async {
    final action = _beginAction(login: true);
    _setActionError(action, null);

    if (!Platform.isIOS && !Platform.isMacOS) {
      _setActionError(action,
        'Apple Login ist nur auf Apple-Geräten verfügbar.',
      );

      _finishAction(action);
      return false;
    }



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
        _setActionError(action,
          'Apple Login fehlgeschlagen '
          '(kein ID-Token erhalten).',
        );

        return false;
      }

      await _repo.loginWithApple(
        idToken,
        generation: action.origin,
      );

      return _owns(action) && _session.isCurrent(action.origin);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        _setActionError(action,
          'Apple Login abgebrochen.',
        );
      } else {
        _setActionError(action,
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

      _setActionError(action,
        apiError.message,
      );

      _debugDio(
        'loginWithApple DioException',
        e,
      );

      return false;
    } catch (e) {
      _setActionError(action,
        'Apple Login fehlgeschlagen. '
        'Versuche es später erneut.',
      );

      _debugErrorType(
        'loginWithApple unknown error',
        e,
      );

      return false;
    } finally {
      _finishAction(action);
    }
  }

  // -------------------------------------------
  //  GOOGLE LOGIN (Android / iOS)
  // -------------------------------------------
  Future<bool> loginWithGoogle() async {
    final action = _beginAction(login: true);
    _setActionError(action, null);


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

      final credential = await _orderedGoogle<({bool canceled, String? token})>(
        () => _session.isCurrent(action.origin), () async {
          final account = await GoogleSignIn(scopes: const ['email']).signIn();
          if (account == null) return (canceled: true, token: null);
          if (!_session.isCurrent(action.origin)) return (canceled: true, token: null);
          final authentication = await account.authentication;
          return (canceled: false, token: authentication.idToken);
        });
      if (credential == null || credential.canceled || !_session.isCurrent(action.origin)) return false;
      final idToken = credential.token;

      if (idToken == null ||
          idToken.isEmpty) {
        _setActionError(action,
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
        generation: action.origin,
      );

      return _owns(action) && _session.isCurrent(action.origin);
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
        _setActionError(action,
          'Keine Verbindung zu Google. '
          'Bitte prüfe deine Internetverbindung.',
        );
      } else {
        // Darunter fallen beispielsweise
        // Google-Konfigurations- oder
        // Play-Services-Probleme.
        _setActionError(action,
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
        _setActionError(action,
          'Keine Verbindung zu Emie. '
          'Bitte prüfe deine Internetverbindung.',
        );
      } else if (status == 400 ||
          status == 401) {
        _setActionError(action,
          'Google-Anmeldung konnte nicht '
          'verifiziert werden. '
          'Bitte versuch es erneut.',
        );
      } else if (status >= 500) {
        _setActionError(action,
          'Emie ist gerade nicht erreichbar. '
          'Bitte versuch es später erneut.',
        );
      } else {
        final apiError =
            ApiError.fromDio(e);

        _setActionError(action,
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
      _setActionError(action,
        'Keine Internetverbindung. '
        'Bitte prüfe deine Verbindung.',
      );

      _debugErrorType(
        'Google SocketException',
        e,
      );

      return false;
    } catch (e) {
      _setActionError(action,
        'Google-Anmeldung fehlgeschlagen. '
        'Bitte versuch es erneut.',
      );

      _debugErrorType(
        'Google Login unknown error',
        e,
      );

      return false;
    } finally {
      _finishAction(action);
    }
  }

  // -------------------------------------------
  //  APP BOOTSTRAP / SESSION WIEDERHERSTELLEN
  // -------------------------------------------
  Future<void> bootstrapSession() async {
    final action = _beginAction(bootstrap: true, loading: false);
    final origin = action.origin;
    try {
      await _session.restoreSession(generation: origin);
      if (!_session.isCurrent(origin)) return;
      if (_session.accessToken?.isNotEmpty != true && !_session.hasRefreshToken) return;
      await _repo.refreshProfile(generation: origin);
    } catch (_) {
      // A cold start has no cached user. An inconclusive check cannot authenticate.
      if (_session.isCurrent(origin)) _session.endSession(origin);
    } finally {
      _session.finishBootstrap(generation: origin);
      _finishAction(action);
    }
  }

  // -------------------------------------------
  //  LOGOUT
  // -------------------------------------------
  Future<void> logout() async {
    final action = _beginAction();
    try {
      final ended = await _repo.logout(generation: action.origin);
      if (ended.completionGeneration != null) await _googleSignOut(ended.completionGeneration!);
      _setActionError(action, null);
    } finally {
      _finishAction(action);
    }
  }

  // -------------------------------------------
  //  ACCOUNT LÖSCHEN
  // -------------------------------------------
  AccountDeletionOperation prepareAccountDeletion() {
    final existing = _dialogOperation;
    if (existing != null && _session.isCurrent(existing.originGeneration) &&
        existing.controllerCompletion == null) {
      return existing;
    }
    return _dialogOperation = AccountDeletionOperation(_session.generation, _session.language);
  }

  void cancelAccountDeletion(AccountDeletionOperation operation) {
    if (identical(_dialogOperation, operation)) _dialogOperation = null;
  }

  Future<AccountDeletionResult> deleteAccount([AccountDeletionOperation? operation]) {
    final request = operation ?? prepareAccountDeletion();
    return request.controllerCompletion ??= _deleteAccount(request);
  }

  Future<AccountDeletionResult> _deleteAccount(AccountDeletionOperation request) async {
    if (!_session.isCurrent(request.originGeneration) || !_session.isAuthenticated) {
      return AccountDeletionResult(operation: request, server: DeletionServerResult.notSent,
        sessionEnd: LocalSessionEnd.differentSession, tokens: TokenCleanupResult.differentSession,
        google: LocalCleanupStep.differentSession);
    }
    final action = _beginAction();
    try {
      var result = await _repo.deleteAccount(request);
      _showDeletionResult(action, result);
      if (result.completionGeneration != null) {
        result = result.withGoogle(await _googleSignOut(result.completionGeneration!));
        _showDeletionResult(action, result);
      }
      return result;
    } finally {
      _finishAction(action);
    }
  }

  // -------------------------------------------
  //  Forgot Password
  // -------------------------------------------
  Future<bool> requestPasswordReset(
    String email,
  ) async {
    final action = _beginAction();

    _setActionError(action, null);

    try {
      await _repo.requestPasswordReset(email, generation: action.origin);

      return _owns(action) && _session.isCurrent(action.origin);
    } on DioException catch (e) {
      final apiError =
          ApiError.fromDio(e);

      _setActionError(action,
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
      _setActionError(action,
        'Reset aktuell nicht verfügbar.',
      );

      _debugErrorType(
        'requestPasswordReset unknown error',
        e,
      );

      return false;
    } finally {
      _finishAction(action);
    }
  }
}

class _AuthAction {
  _AuthAction(this.origin);
  final int origin;
}
