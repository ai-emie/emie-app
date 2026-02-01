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
  //   - GET    /v1/chat/sessions/{chat_session_id}   (inkl. messages)
  //   - DELETE /v1/chat/sessions/{chat_session_id}
  //
  //  WICHTIG:
  //   - Es gibt KEIN POST /v1/chat/sessions
  //   - Session wird im Backend automatisch angelegt,
  //     sobald du /v1/chat/respond mit chat_session_id sendest.
  // ==========================================================

  /// GET /v1/chat/sessions
  Future<List<ChatSession>> listSessions() async {
    final res = await _dio.get('/v1/chat/sessions');
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
  /// Backend liefert:
  /// {
  ///   "id": "...",
  ///   "title": "...",
  ///   "messages": [
  ///     {"id":"..","role":"user","content":"..","created_at":".."},
  ///     ...
  ///   ]
  /// }
  ///
  /// Client ChatMessage erwartet i.d.R. "text" statt "content" → wir mappen das.
  Future<List<ChatMessage>> getSessionMessages(String sessionId) async {
    final res = await _dio.get('/v1/chat/sessions/$sessionId');
    final data = (res.data as Map<String, dynamic>? ?? {});

    final rawMessages = (data['messages'] as List<dynamic>? ?? []);

    final items = rawMessages
        .whereType<Map<String, dynamic>>()
        .map((m) {
          // content -> text (Client-Model)
          final mapped = <String, dynamic>{
            'id': (m['id'] ?? '').toString(),
            'role': (m['role'] ?? 'assistant').toString(),
            'text': (m['content'] ?? '').toString(),
            'created_at': (m['created_at'] ?? '').toString(),
          };
          return ChatMessage.fromJson(mapped);
        })
        .toList();

    return items;
  }

  /// DELETE /v1/chat/sessions/{id}
  Future<void> deleteSession(String sessionId) async {
    await _dio.delete('/v1/chat/sessions/$sessionId');
  }

  // ==========================================================
  //  BRAIN v2: SEND_MESSAGE → POST /v1/chat/respond
  // ==========================================================
  Future<ChatMessage> sendMessage({
    required String text,
    required String chatSessionId,
    String provider = 'openai',
    int maxTokens = 400,
    double temperature = 0.3,
  }) async {
    final trimmed = text.trim();

    // HARDENED: prevent empty messages
    if (trimmed.isEmpty) {
      final mapped = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'role': 'assistant',
        'text': 'Schreib mir bitte eine Nachricht, dann antworte ich dir.',
        'created_at': DateTime.now().toIso8601String(),
      };
      return ChatMessage.fromJson(mapped);
    }

    try {
      final res = await _dio.post(
        '/v1/chat/respond',
        data: {
          'message': trimmed,
          'provider': provider,
          'max_tokens': maxTokens,
          'temperature': temperature,

          // A1.5 Persistenz
          'chat_session_id': chatSessionId,
        },
      );

      final data = res.data as Map<String, dynamic>? ?? {};
      final replyText = (data['reply'] ?? '').toString().trim();

      // HARDENED: niemals leer
      final safeReply = replyText.isNotEmpty
          ? replyText
          : 'Ich bin da. Gerade kam keine saubere Antwort zurück. Schreib mir bitte nochmal kurz, was du brauchst.';

      final mapped = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'role': 'assistant',
        'text': safeReply,
        'created_at': DateTime.now().toIso8601String(),
      };

      return ChatMessage.fromJson(mapped);
    } catch (e, st) {
      // ignore: avoid_print
      print("ChatApi Brain error: $e\n$st");
      rethrow;
    }
  }
}
