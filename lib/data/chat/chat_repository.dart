// ===============================================
// Emie • Chat Repository (Brain v2 + User-saved History)
// Pfad: lib/data/chat/chat_repository.dart
// ===============================================

import 'chat_api.dart';
import 'chat_models.dart';
import 'chat_session_models.dart';

class ChatRepository {
  ChatRepository({ChatApi? api}) : _api = api ?? ChatApi();

  final ChatApi _api;

  // ------------------------------
  // Brain v2
  // ------------------------------
  Future<ChatMessage> sendUserMessage({
    required String text,
    required String chatSessionId,
    String provider = 'openai',
    int maxTokens = 400,
    double temperature = 0.3,
  }) {
    return _api.sendMessage(
      text: text,
      chatSessionId: chatSessionId,
      provider: provider,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  // ------------------------------
  // History (User saved)
  // Backend:
  //  - GET    /v1/chat/sessions
  //  - GET    /v1/chat/sessions/{id}  (inkl. messages)
  //  - DELETE /v1/chat/sessions/{id}
  //
  // Wichtig:
  //  - KEIN createSession() im Backend
  //  - Session entsteht automatisch, sobald sendUserMessage()
  //    mit chatSessionId aufgerufen wird.
  // ------------------------------
  Future<List<ChatSession>> listSessions() => _api.listSessions();

  Future<void> deleteSession(String sessionId) => _api.deleteSession(sessionId);

  /// Lädt Messages einer Session über:
  /// GET /v1/chat/sessions/{id}  (Backend liefert messages inline)
  Future<List<ChatMessage>> getMessages(String sessionId) =>
      _api.getSessionMessages(sessionId);
}
