// ===============================================
// Emie • Chat API (Brain v2 + User-saved History)
// Pfad: lib/data/chat/chat_api.dart
// ===============================================

import 'package:dio/dio.dart';

import '../../api/client.dart';
import 'chat_models.dart';
import 'chat_session_models.dart';

class ChatApi {
  ChatApi({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  // ==========================================================
  //  HISTORY: Sessions (User scoped via Bearer Token)
  //  Backend:
  //   - GET    /v1/chat/sessions
  //   - GET    /v1/chat/sessions/{chat_session_id}
  //   - DELETE /v1/chat/sessions/{chat_session_id}
  //
  //  WICHTIG:
  //   - Es gibt KEIN POST /v1/chat/sessions
  //   - Session wird im Backend automatisch angelegt,
  //     sobald /v1/chat/respond mit chat_session_id gesendet wird.
  // ==========================================================

  /// GET /v1/chat/sessions
  Future<List<ChatSession>> listSessions() async {
    final res = await _dio.get(
      '/v1/chat/sessions',
    );

    final data = res.data;

    final list = (data is Map<String, dynamic>)
        ? (data['items'] ?? data['sessions'] ?? [])
        : data;

    final items = (list as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ChatSession.fromJson)
        .toList();

    return items;
  }

  /// GET /v1/chat/sessions/{id}
  ///
  /// Backend liefert:
  /// {
  ///   "id": "...",
  ///   "title": "...",
  ///   "messages": [
  ///     {
  ///       "id": "...",
  ///       "role": "user",
  ///       "content": "...",
  ///       "created_at": "..."
  ///     }
  ///   ]
  /// }
  ///
  /// Client ChatMessage erwartet "text" statt "content".
  /// Deshalb wird die Backend-Antwort hier gemappt.
  Future<List<ChatMessage>> getSessionMessages(
    String sessionId,
  ) async {
    final res = await _dio.get(
      '/v1/chat/sessions/$sessionId',
    );

    final data =
        res.data as Map<String, dynamic>? ?? {};

    final rawMessages =
        data['messages'] as List<dynamic>? ?? [];

    final items = rawMessages
        .whereType<Map<String, dynamic>>()
        .map((message) {
          final mapped = <String, dynamic>{
            'id': (message['id'] ?? '').toString(),
            'role':
                (message['role'] ?? 'assistant').toString(),
            'text':
                (message['content'] ?? '').toString(),
            'created_at':
                (message['created_at'] ?? '').toString(),
          };

          return ChatMessage.fromJson(mapped);
        })
        .toList();

    return items;
  }

  /// DELETE /v1/chat/sessions/{id}
  Future<void> deleteSession(
    String sessionId,
  ) async {
    await _dio.delete(
      '/v1/chat/sessions/$sessionId',
    );
  }

  // ==========================================================
  //  DAILY WELCOME → GET /v1/get-daily-welcome
  // ==========================================================
  //
  // Wichtig für Beta:
  //
  // Hier niemals einen scheinbar personalisierten Demo-Text
  // erzeugen, wenn das Backend nichts liefert oder fehlschlägt.
  //
  // Leerer String bedeutet:
  // "Aktuell ist kein echter Daily Welcome verfügbar."
  //
  // Der HomeScreen stellt diesen Zustand als neutralen
  // Empty State dar.
  Future<String> getDailyWelcome() async {
    try {
      final res = await _dio.get(
        '/v1/get-daily-welcome',
      );

      final data =
          res.data as Map<String, dynamic>? ?? {};

      final message =
          (data['message'] ?? '').toString().trim();

      if (message.isNotEmpty) {
        return message;
      }

      return '';
    } catch (_) {
      // Kein lokales Error-Dumping.
      //
      // Der zentrale ApiClient protokolliert HTTP-Fehler
      // im Debug-Build bereits metadata-only.
      //
      // Kein Fake-Fallback:
      // Home zeigt stattdessen seinen Empty State.
      return '';
    }
  }

  // ==========================================================
  //  BRAIN v2: SEND MESSAGE → POST /v1/chat/respond
  // ==========================================================
  Future<ChatMessage> sendMessage({
    required String text,
    required String chatSessionId,
    String provider = 'openai',
    int maxTokens = 400,
    double temperature = 0.3,
  }) async {
    final trimmed = text.trim();

    // Leere Nachrichten niemals ans Backend senden.
    if (trimmed.isEmpty) {
      final mapped = <String, dynamic>{
        'id':
            DateTime.now().millisecondsSinceEpoch.toString(),
        'role': 'assistant',
        'text':
            'Schreib mir bitte eine Nachricht, dann antworte ich dir.',
        'created_at':
            DateTime.now().toIso8601String(),
      };

      return ChatMessage.fromJson(mapped);
    }

    final res = await _dio.post(
      '/v1/chat/respond',
      data: {
        'message': trimmed,
        'provider': provider,
        'max_tokens': maxTokens,
        'temperature': temperature,
        'chat_session_id': chatSessionId,
      },
    );

    final data =
        res.data as Map<String, dynamic>? ?? {};

    final replyText =
        (data['reply'] ?? '').toString().trim();

    // Niemals eine leere Assistant-Nachricht darstellen.
    //
    // Das ist ein technischer UX-Fallback und keine
    // erfundene personenbezogene Information.
    final safeReply = replyText.isNotEmpty
        ? replyText
        : 'Ich bin da. Gerade kam keine saubere Antwort zurück. '
            'Schreib mir bitte nochmal kurz, was du brauchst.';

    final mapped = <String, dynamic>{
      'id':
          DateTime.now().millisecondsSinceEpoch.toString(),
      'role': 'assistant',
      'text': safeReply,
      'created_at':
          DateTime.now().toIso8601String(),
    };

    return ChatMessage.fromJson(mapped);
  }
}