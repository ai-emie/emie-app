// ===============================================
// Emie • API Error Mapping
// Pfad: lib/api/api_error.dart
// ===============================================

import 'package:dio/dio.dart';

enum ApiErrorType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  server,
  cancelled,
  unknown,
}

class ApiError implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;

  const ApiError({
    required this.type,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'ApiError($type, $message, status=$statusCode)';

  factory ApiError.fromDio(DioException e) {
    final status = e.response?.statusCode;

    final data = e.response?.data;
    final detail = data is Map ? data['detail'] : null;
    final code = detail is Map ? detail['code'] : null;
    const localMessages = <String, String>{
      'P1_BUDGET': 'Lokales Entwicklungskontingent erreicht. Keine automatische Erhöhung.',
      'P1_AUTH': 'OpenAI-Schlüssel abgelehnt oder Berechtigung fehlt. Lokalen Status prüfen.',
      'P1_MODEL': 'Das OpenAI-Modell ist für diesen Schlüssel nicht verfügbar.',
      'P1_UNCERTAIN': 'Anbieterausgang unklar. Nicht erneut senden; lokalen Status prüfen.',
      'P1_NETWORK': 'Anbieterverbindung fehlgeschlagen. Nicht automatisch erneut senden.',
      'P1_RESPONSE': 'Keine vollständige Anbieterantwort. Lokalen Status prüfen.',
      'P1_UNAVAILABLE': 'Antwort-Engine nicht verfügbar. Keine KI-Antwort bestätigt.',
      'P1_PRICE': 'Die lokale Preisfreigabe muss erneut geprüft werden.',
      'P1_POLICY': 'Lokale Sicherheits- oder Budgetprüfung hat den Aufruf gesperrt.',
      'P1_PROTECTED': 'Historischer Nachweis: Bitte einen neuen Chat öffnen.',
      'P1_SCOPE': 'Diese Aktion gehört nicht zum lokalen Textchat-Modus.',
      'P1_BUSY': 'Eine Nachricht wird noch verarbeitet. Bitte kurz warten.',
    };
    if (code is String && localMessages.containsKey(code)) {
      return ApiError(type: ApiErrorType.server, message: localMessages[code]!, statusCode: status);
    }

    // Netzwerk/Timeout
    if (e.type == DioExceptionType.connectionError) {
      return const ApiError(
        type: ApiErrorType.network,
        message: 'Keine Verbindung. Bitte prüfe dein Internet.',
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const ApiError(
        type: ApiErrorType.timeout,
        message: 'Zeitüberschreitung. Versuch es später nochmal.',
      );
    }
    if (e.type == DioExceptionType.cancel) {
      return const ApiError(
        type: ApiErrorType.cancelled,
        message: 'Anfrage abgebrochen.',
      );
    }

    // HTTP-Statuscodes
    if (status != null) {
      if (status == 401) {
        return const ApiError(
          type: ApiErrorType.unauthorized,
          message: 'Du bist nicht eingeloggt. Bitte melde dich neu an.',
          statusCode: 401,
        );
      }
      if (status == 403) {
        return const ApiError(
          type: ApiErrorType.forbidden,
          message: 'Du hast keine Berechtigung für diese Aktion.',
          statusCode: 403,
        );
      }
      if (status == 404) {
        return const ApiError(
          type: ApiErrorType.notFound,
          message: 'Die angefragte Ressource wurde nicht gefunden.',
          statusCode: 404,
        );
      }
      if (status >= 500) {
        return ApiError(
          type: ApiErrorType.server,
          message: 'Serverfehler (${status}). Bitte versuch es später erneut.',
          statusCode: status,
        );
      }
    }

    // Fallback
    return ApiError(
      type: ApiErrorType.unknown,
      message: 'Vorgang nicht bestätigt. Bitte die Historie prüfen.',
      statusCode: status,
    );
  }
}
