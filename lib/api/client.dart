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
    //  • DEBUG: Welche Base-URL nutzt die App wirklich?
    // ===========================================================
    if (kDebugMode) {
      debugPrint('🌐 EMIE_ENV=${Env.current} baseUrl=${Env.apiBaseUrl}');
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
        onRequest: (options, handler) async {
          final session = SessionStore.instance;

          final token = session.accessToken;

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          options.headers['Content-Type'] = 'application/json';
          options.headers['Accept'] = 'application/json';

          if (kDebugMode) {
            if (_isSensitiveAuthRequest(options)) {
              // Bei Auth-Endpunkten niemals Body oder Query-Parameter loggen.
              debugPrint(
                '➡️ [${options.method}] ${options.path} [Auth-Daten ausgeblendet]',
              );
            } else {
              debugPrint('➡️ [${options.method}] ${options.uri}');

              if (options.data != null) {
                debugPrint('   data=${options.data}');
              }
            }
          }

          // Wir gehen erstmal davon aus, dass wir online sind,
          // wenn ein Request rausgeht.
          session.setOnline(true);

          return handler.next(options);
        },

        onResponse: (response, handler) {
          // Erfolgreiche Antwort → wir sind online.
          SessionStore.instance.setOnline(true);

          if (kDebugMode) {
            final req = response.requestOptions;

            if (_isSensitiveAuthRequest(req)) {
              debugPrint(
                '✅ [${response.statusCode}] ${req.path}',
              );
            } else {
              debugPrint(
                '✅ [${response.statusCode}] ${req.uri}',
              );
            }
          }

          return handler.next(response);
        },

        onError: (DioException e, handler) async {
          final statusCode = e.response?.statusCode;
          final req = e.requestOptions;

          if (kDebugMode) {
            if (_isSensitiveAuthRequest(req)) {
              debugPrint(
                '❌ [${statusCode ?? '-'}] ${req.path}',
              );
            } else {
              debugPrint(
                '❌ [${statusCode ?? '-'}] ${req.uri}',
              );
            }

            debugPrint('   type=${e.type}');
            debugPrint('   error=${e.message}');
          }

          final session = SessionStore.instance;

          // Netzwerk-/Timeout-Fehler → Offline markieren.
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            session.setOnline(false);
          } else {
            // Andere Fehler → Server ist erreichbar.
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
          final alreadyRetried = req.extra['retry'] == true;

          if (alreadyRetried) {
            await _clearInvalidAuth(session);
            return handler.next(e);
          }

          try {
            req.extra['retry'] = true;

            if (kDebugMode) {
              debugPrint('🔁 Versuche Access-Token zu erneuern…');
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
            final finalRefreshToken = newRefresh ?? refreshToken;

            session.updateTokens(
              newAccess,
              refresh: finalRefreshToken,
            );

            await SecureStorageService.saveTokens(
              accessToken: newAccess,
              refreshToken: finalRefreshToken,
            );

            // Authorization-Header des ursprünglichen Requests ersetzen.
            req.headers['Authorization'] = 'Bearer $newAccess';

            if (kDebugMode) {
              debugPrint(
                '🔁 Wiederhole Request mit neuem Access-Token…',
              );
            }

            final cloneResponse = await _dio.fetch(req);

            return handler.resolve(cloneResponse);
          } catch (refreshError, stack) {
            if (kDebugMode) {
              debugPrint('💥 Refresh fehlgeschlagen: $refreshError');
              debugPrint(stack.toString());
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
  bool _isSensitiveAuthRequest(RequestOptions options) {
    return options.path.startsWith('/v1/auth/');
  }

  // ===========================================================
  //  • UNGÜLTIGE AUTH-DATEN VOLLSTÄNDIG LÖSCHEN
  // ===========================================================
  Future<void> _clearInvalidAuth(SessionStore session) async {
    try {
      await SecureStorageService.clearTokens();
    } finally {
      // Session wird auch dann geleert, wenn der Storage-Wipe
      // unerwartet selbst einen Fehler wirft.
      session.clear();
    }

    if (kDebugMode) {
      debugPrint(
        '🧹 Ungültige Auth-Tokens aus Session und Secure Storage gelöscht.',
      );
    }
  }

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  late final Dio _dio;
  late final Dio _refreshDio;

  Dio get dio => _dio;
}