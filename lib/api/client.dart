// ===============================================
// Emie • API Client (Dio + Refresh + Online-Status)
// Pfad: lib/api/client.dart
// ===============================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/env.dart';
import '../core/storage/secure_storage.dart';
import '../state/session_store.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
      ),
    );

    // ===========================================================
    //  • DEBUG: Aktive Umgebung
    // ===========================================================
    //
    // Ausschließlich im Debug-Build.
    // Keine Tokens, Header, Payloads oder Query-Parameter.
    if (kDebugMode) {
      debugPrint(
        '🌐 EMIE_ENV=${Env.current} baseUrl=${Env.apiBaseUrl}',
      );
    }

    _refreshDio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        // =======================================================
        //  • REQUEST
        // =======================================================
        onRequest: (options, handler) async {
          final session = SessionStore.instance;

          final token = session.accessToken;

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          options.headers['Content-Type'] = 'application/json';
          options.headers['Accept'] = 'application/json';

          // -----------------------------------------------------
          // Sicheres Debug-Logging
          // -----------------------------------------------------
          //
          // Niemals loggen:
          // - Authorization Header
          // - Access-/Refresh-Token
          // - Passwörter
          // - Google-/Apple-ID-Tokens
          // - Request Body
          // - Query-Parameter
          if (kDebugMode) {
            if (_isSensitiveAuthRequest(options)) {
              debugPrint(
                '➡️ [${options.method}] '
                '${_safePath(options)} '
                '[Auth-Daten ausgeblendet]',
              );
            } else {
              debugPrint(
                '➡️ [${options.method}] ${_safePath(options)}',
              );
            }
          }

          // Wir gehen erstmal davon aus, dass wir online sind,
          // wenn ein Request rausgeht.
          session.setOnline(true);

          return handler.next(options);
        },

        // =======================================================
        //  • RESPONSE
        // =======================================================
        onResponse: (response, handler) {
          // Erfolgreiche Antwort → wir sind online.
          SessionStore.instance.setOnline(true);

          if (kDebugMode) {
            final req = response.requestOptions;

            debugPrint(
              '✅ [${response.statusCode}] ${_safePath(req)}',
            );
          }

          return handler.next(response);
        },

        // =======================================================
        //  • ERROR
        // =======================================================
        onError: (DioException e, handler) async {
          final statusCode = e.response?.statusCode;
          final req = e.requestOptions;

          if (kDebugMode) {
            debugPrint(
              '❌ [${statusCode ?? '-'}] ${_safePath(req)}',
            );

            // Nur Fehlertyp loggen.
            // Keine komplette Dio-Fehlermeldung, da deren Inhalt
            // von der Bibliothek abhängt und später Request-Daten
            // enthalten könnte.
            debugPrint(
              '   type=${e.type}',
            );
          }

          final session = SessionStore.instance;

          // -----------------------------------------------------
          // Netzwerk-/Timeout-Fehler → Offline markieren
          // -----------------------------------------------------
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            session.setOnline(false);
          } else {
            // Andere Fehler → Server ist grundsätzlich erreichbar.
            session.setOnline(true);
          }

          // Kein 401 → Fehler normal weitergeben.
          if (statusCode != 401) {
            return handler.next(e);
          }

          // =====================================================
          //  • DIREKTER REFRESH-ENDPUNKT IST FEHLGESCHLAGEN
          // =====================================================
          if (req.path.contains('/v1/auth/refresh')) {
            await _clearInvalidAuth(session);
            return handler.next(e);
          }

          final refreshToken = session.refreshToken;

          // =====================================================
          //  • KEIN REFRESH-TOKEN MEHR VORHANDEN
          // =====================================================
          if (refreshToken == null || refreshToken.isEmpty) {
            await _clearInvalidAuth(session);
            return handler.next(e);
          }

          // =====================================================
          //  • REQUEST WURDE BEREITS EINMAL WIEDERHOLT
          // =====================================================
          //
          // Verhindert eine Endlosschleife bei dauerhaftem 401.
          final alreadyRetried = req.extra['retry'] == true;

          if (alreadyRetried) {
            await _clearInvalidAuth(session);
            return handler.next(e);
          }

          try {
            req.extra['retry'] = true;

            if (kDebugMode) {
              debugPrint(
                '🔁 Versuche Access-Token zu erneuern…',
              );
            }

            // Separates Dio ohne den normalen Interceptor,
            // damit der Refresh selbst keine Refresh-Schleife auslöst.
            final refreshResponse = await _refreshDio.post(
              '/v1/auth/refresh',
              data: {
                'refresh_token': refreshToken,
              },
            );

            final data =
                refreshResponse.data as Map<String, dynamic>? ?? {};

            final newAccess = data['access_token'] as String?;
            final newRefresh = data['refresh_token'] as String?;

            // ===================================================
            //  • UNBRAUCHBARE REFRESH-ANTWORT
            // ===================================================
            if (newAccess == null || newAccess.isEmpty) {
              if (kDebugMode) {
                debugPrint(
                  '⚠️ Refresh-Antwort ohne access_token, '
                  'Auth wird vollständig gelöscht.',
                );
              }

              await _clearInvalidAuth(session);

              return handler.next(e);
            }

            // ===================================================
            //  • NEUE TOKENS ÜBERNEHMEN + DAUERHAFT SPEICHERN
            // ===================================================
            final finalRefreshToken =
                newRefresh ?? refreshToken;

            session.updateTokens(
              newAccess,
              refresh: finalRefreshToken,
            );

            await SecureStorageService.saveTokens(
              accessToken: newAccess,
              refreshToken: finalRefreshToken,
            );

            // Authorization-Header des ursprünglichen Requests
            // durch den neuen Access-Token ersetzen.
            req.headers['Authorization'] =
                'Bearer $newAccess';

            if (kDebugMode) {
              debugPrint(
                '🔁 Wiederhole Request mit neuem Access-Token…',
              );
            }

            final cloneResponse =
                await _dio.fetch(req);

            return handler.resolve(cloneResponse);
          } catch (refreshError) {
            if (kDebugMode) {
              // Nur den Error-Typ ausgeben.
              // Keine Exception-Details oder Stacktraces.
              debugPrint(
                '💥 Refresh fehlgeschlagen '
                '(${refreshError.runtimeType}).',
              );
            }

            // Refresh fehlgeschlagen:
            // tote Tokens aus RAM UND Secure Storage entfernen.
            await _clearInvalidAuth(session);

            return handler.next(e);
          }
        },
      ),
    );
  }

  // ===========================================================
  //  • SENSIBLE AUTH-REQUESTS ERKENNEN
  // ===========================================================
  bool _isSensitiveAuthRequest(
    RequestOptions options,
  ) {
    return options.path.startsWith('/v1/auth/');
  }

  // ===========================================================
  //  • SICHERER LOG-PFAD
  // ===========================================================
  //
  // Bewusst nur der URL-Pfad.
  // Query-Parameter werden niemals ins Log geschrieben.
  String _safePath(
    RequestOptions options,
  ) {
    final path = options.uri.path;

    if (path.isNotEmpty) {
      return path;
    }

    return options.path;
  }

  // ===========================================================
  //  • UNGÜLTIGE AUTH-DATEN VOLLSTÄNDIG LÖSCHEN
  // ===========================================================
  Future<void> _clearInvalidAuth(
    SessionStore session,
  ) async {
    try {
      await SecureStorageService.clearTokens();
    } finally {
      // Session wird auch dann geleert, wenn der Storage-Wipe
      // unerwartet selbst einen Fehler wirft.
      session.clear();
    }

    if (kDebugMode) {
      debugPrint(
        '🧹 Ungültige Auth-Tokens aus Session und '
        'Secure Storage gelöscht.',
      );
    }
  }

  static final ApiClient _instance =
      ApiClient._internal();

  factory ApiClient() => _instance;

  late final Dio _dio;
  late final Dio _refreshDio;

  Dio get dio => _dio;
}