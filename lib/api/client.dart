// ===============================================
// Emie • API Client (Dio + Refresh + Online-Status)
// Pfad: lib/api/client.dart
// ===============================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/env.dart';
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
            debugPrint('➡️ [${options.method}] ${options.uri}');
            if (options.data != null) {
              debugPrint('   data=${options.data}');
            }
          }

          // Wir gehen erstmal davon aus, dass wir online sind, wenn ein Request rausgeht
          session.setOnline(true);

          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Erfolgreiche Antwort → wir sind online
          SessionStore.instance.setOnline(true);

          if (kDebugMode) {
            debugPrint('✅ [${response.statusCode}] ${response.requestOptions.uri}');
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          final statusCode = e.response?.statusCode;
          final req = e.requestOptions;

          if (kDebugMode) {
            debugPrint('❌ [${statusCode ?? '-'}] ${req.uri}');
            debugPrint('   type=${e.type}');
            debugPrint('   error=${e.message}');
          }

          final session = SessionStore.instance;

          // Netzwerk-/Timeout-Fehler → Offline markieren
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            session.setOnline(false);
          } else {
            // Andere Fehler → Verbindung zum Server besteht, also "online"
            session.setOnline(true);
          }

          // Wenn kein 401 → Fehler normal weitergeben
          if (statusCode != 401) {
            return handler.next(e);
          }

          // Wenn der Fehler vom Refresh-Endpunkt selbst kommt → abbrechen
          if (req.path.contains('/v1/auth/refresh')) {
            return handler.next(e);
          }

          final refreshToken = session.refreshToken;

          // Kein Refresh-Token vorhanden → User muss sich neu einloggen
          if (refreshToken == null || refreshToken.isEmpty) {
            session.clear();
            return handler.next(e);
          }

          // Wenn dieser Request schon einmal als "retry" markiert wurde → keine Schleife
          final alreadyRetried = req.extra['retry'] == true;
          if (alreadyRetried) {
            session.clear();
            return handler.next(e);
          }

          try {
            req.extra['retry'] = true;

            if (kDebugMode) {
              debugPrint('🔁 Versuche Access-Token zu erneuern…');
            }

            final refreshResponse = await _refreshDio.post(
              '/v1/auth/refresh',
              data: {
                'refresh_token': refreshToken,
              },
            );

            final data = refreshResponse.data as Map<String, dynamic>? ?? {};
            final newAccess = data['access_token'] as String?;
            final newRefresh = data['refresh_token'] as String?;

            if (newAccess == null || newAccess.isEmpty) {
              if (kDebugMode) {
                debugPrint('⚠️ Refresh-Antwort ohne access_token, Session wird gelöscht');
              }
              session.clear();
              return handler.next(e);
            }

            // Tokens aktualisieren
            session.updateTokens(
              newAccess,
              refresh: newRefresh ?? refreshToken,
            );

            // Authorization-Header des ursprünglichen Requests ersetzen
            req.headers['Authorization'] = 'Bearer $newAccess';

            if (kDebugMode) {
              debugPrint('🔁 Wiederhole Request mit neuem Access-Token…');
            }

            final cloneResponse = await _dio.fetch(req);
            return handler.resolve(cloneResponse);
          } catch (refreshError, stack) {
            if (kDebugMode) {
              debugPrint('💥 Refresh fehlgeschlagen: $refreshError');
              debugPrint(stack.toString());
            }
            session.clear();
            return handler.next(e);
          }
        },
      ),
    );
  }

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  late final Dio _refreshDio;

  Dio get dio => _dio;
}
