// ===============================================
// Emie • Chat Controller (Brain v2 + User-saved History)
// Pfad: lib/features/chat/controller/chat_controller.dart
// ===============================================

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../api/api_error.dart';
import '../../../data/chat/chat_models.dart';
import '../../../data/chat/chat_repository.dart';
import '../../../data/chat/chat_session_models.dart';

class ChatController extends ChangeNotifier {
  ChatController({ChatRepository? repository})
      : _repository = repository ?? ChatRepository() {
    _chatSessionId = _generateSessionId();
  }

  final ChatRepository _repository;

  // ----------------------------------------------
  // State: Sessions + Messages
  // ----------------------------------------------
  final List<ChatSession> _sessions = [];
  final List<ChatMessage> _messages = [];

  bool _isSending = false;
  bool _isLoadingHistory = false;
  String? _error;

  late String _chatSessionId;

  // ----------------------------------------------
  // Getters
  // ----------------------------------------------
  String get chatSessionId => _chatSessionId;

  List<ChatSession> get sessions =>
      List.unmodifiable(_sessions);

  List<ChatMessage> get messages =>
      List.unmodifiable(_messages);

  bool get isSending => _isSending;

  bool get isLoadingHistory =>
      _isLoadingHistory;

  String? get error => _error;

  // ----------------------------------------------
  // Sicheres Dio Debug-Logging
  // ----------------------------------------------
  //
  // Niemals komplette DioExceptions loggen.
  // Darin könnten Request-Daten, Chat-Inhalte,
  // Header oder andere Nutzerdaten enthalten sein.
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

  // ----------------------------------------------
  // Sicheres generisches Debug-Logging
  // ----------------------------------------------
  //
  // Nur Exception-Typ.
  // Kein toString() und kein Stacktrace.
  void _debugErrorType(
    String source,
    Object error,
  ) {
    if (!kDebugMode) return;

    debugPrint(
      '$source: ${error.runtimeType}',
    );
  }

  // ----------------------------------------------
  // DAILY WELCOME
  // ----------------------------------------------
  Future<String> getDailyWelcome() async {
    try {
      return await _repository.getDailyWelcome();
    } catch (_) {
      // Kein scheinbar personalisierter Fallback.
      // Leerer String wird im HomeScreen als
      // neutraler Empty State dargestellt.
      return '';
    }
  }

  // ----------------------------------------------
  // INIT / LOAD
  // ----------------------------------------------
  Future<void> loadSessions() async {
    _error = null;
    _isLoadingHistory = true;

    notifyListeners();

    try {
      final items =
          await _repository.listSessions();

      _sessions
        ..clear()
        ..addAll(items);
    } on DioException catch (e) {
      _debugDio(
        'ChatController.loadSessions DioException',
        e,
      );

      _error =
          ApiError.fromDio(e).message;
    } catch (e) {
      _debugErrorType(
        'ChatController.loadSessions error',
        e,
      );

      _error =
          'Konnte Chats nicht laden.';
    } finally {
      _isLoadingHistory = false;

      notifyListeners();
    }
  }

  Future<void> openChat(
    String sessionId,
  ) async {
    if (_isSending) return;

    _error = null;
    _isLoadingHistory = true;

    notifyListeners();

    try {
      _chatSessionId = sessionId;

      // Backend:
      // GET /v1/chat/sessions/{id}
      // → Messages inline
      final msgs =
          await _repository.getMessages(
        sessionId,
      );

      _messages
        ..clear()
        ..addAll(msgs);
    } on DioException catch (e) {
      _debugDio(
        'ChatController.openChat DioException',
        e,
      );

      _error =
          ApiError.fromDio(e).message;
    } catch (e) {
      _debugErrorType(
        'ChatController.openChat error',
        e,
      );

      _error =
          'Konnte Chat nicht öffnen.';
    } finally {
      _isLoadingHistory = false;

      notifyListeners();
    }
  }

  // ----------------------------------------------
  // NEW CHAT (LOCAL ONLY)
  //
  // WICHTIG:
  // Kein POST /sessions im Backend.
  //
  // Die Session entsteht automatisch im Backend,
  // sobald send() mit chat_session_id aufgerufen wird.
  // ----------------------------------------------
  void newChat() {
    if (_isSending) return;

    _error = null;

    _messages.clear();

    _chatSessionId =
        _generateSessionId();

    notifyListeners();
  }

  // ----------------------------------------------
  // DELETE CHAT
  // ----------------------------------------------
  Future<void> deleteChat(
    String sessionId,
  ) async {
    if (_isSending) return;

    try {
      await _repository.deleteSession(
        sessionId,
      );

      // Wenn aktueller Chat gelöscht wurde,
      // auf einen neuen lokalen Chat wechseln.
      if (_chatSessionId == sessionId) {
        _messages.clear();

        _chatSessionId =
            _generateSessionId();
      }

      await loadSessions();
    } on DioException catch (e) {
      // Soft-Fail bleibt bestehen.
      // Debug-Logging aber nur metadata-only.
      _debugDio(
        'ChatController.deleteChat DioException',
        e,
      );
    } catch (e) {
      _debugErrorType(
        'ChatController.deleteChat error',
        e,
      );
    } finally {
      notifyListeners();
    }
  }

  // ----------------------------------------------
  // SEND
  // ----------------------------------------------
  Future<void> send(
    String text,
  ) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty ||
        _isSending) {
      return;
    }

    _error = null;
    _isSending = true;

    // Safety:
    // Falls aus irgendeinem Grund keine
    // Session-ID vorhanden ist.
    if (_chatSessionId.trim().isEmpty) {
      _chatSessionId =
          _generateSessionId();
    }

    final userMsg = ChatMessage(
      id: UniqueKey().toString(),
      role: 'user',
      text: trimmed,
      createdAt: DateTime.now(),
    );

    _messages.add(userMsg);

    final typingMsg = ChatMessage(
      id: UniqueKey().toString(),
      role: 'assistant',
      text: '…',
      createdAt: DateTime.now(),
    );

    _messages.add(typingMsg);

    notifyListeners();

    try {
      final reply =
          await _repository.sendUserMessage(
        text: trimmed,
        chatSessionId: _chatSessionId,
      );

      final cleanText =
          _sanitizeAssistantText(
        reply.text,
      );

      final cleanReply = ChatMessage(
        id: reply.id,
        role: reply.role,
        text: cleanText,
        createdAt: reply.createdAt,
      );

      final idx =
          _messages.indexWhere(
        (message) =>
            message.id == typingMsg.id,
      );

      if (idx >= 0) {
        _messages[idx] =
            cleanReply;
      } else {
        _messages.add(
          cleanReply,
        );
      }

      // Nach dem Senden Sessions neu laden.
      // title / updated_at kommen aus der DB.
      await loadSessions();
    } on DioException catch (e) {
      _debugDio(
        'ChatController.send DioException',
        e,
      );

      final apiError =
          ApiError.fromDio(e);

      _error =
          apiError.message;

      _replaceTypingWithFallback(
        typingMsg.id,
        'Entschuldigung, ich hatte gerade '
        'ein Verbindungsproblem. '
        'Versuch es bitte nochmal.',
      );
    } catch (e) {
      _debugErrorType(
        'ChatController.send unknown error',
        e,
      );

      _error =
          'Es ist ein unerwarteter Fehler aufgetreten.';

      _replaceTypingWithFallback(
        typingMsg.id,
        'Entschuldigung, da ist intern '
        'etwas schiefgelaufen. '
        'Versuch es bitte nochmal.',
      );
    } finally {
      _isSending = false;

      notifyListeners();
    }
  }

  // ----------------------------------------------
  // TYPING → FALLBACK
  // ----------------------------------------------
  void _replaceTypingWithFallback(
    String typingId,
    String message,
  ) {
    final idx =
        _messages.indexWhere(
      (item) =>
          item.id == typingId,
    );

    final fallback = ChatMessage(
      id: UniqueKey().toString(),
      role: 'assistant',
      text: message,
      createdAt: DateTime.now(),
    );

    if (idx >= 0) {
      _messages[idx] =
          fallback;
    } else {
      _messages.add(
        fallback,
      );
    }
  }

  // ----------------------------------------------
  // ERROR
  // ----------------------------------------------
  void clearError() {
    _error = null;

    notifyListeners();
  }

  // ----------------------------------------------
  // OUTPUT FILTER
  // ----------------------------------------------
  String _sanitizeAssistantText(
    String raw,
  ) {
    var text = raw;

    text = text.replaceAll(
      RegExp(
        r'ID:\s*CLARIFY:[A-Za-z0-9+/=_-]+',
      ),
      '',
    );

    text = text.replaceAll(
      RegExp(
        r'^ID:\s*.*$',
        multiLine: true,
      ),
      '',
    );

    text = text.replaceAll(
      RegExp(
        r'^.*antworte.*zahl.*$',
        multiLine: true,
        caseSensitive: false,
      ),
      '',
    );

    text = text.replaceAllMapped(
      RegExp(
        r'^Welche\s+Variante\s+passt\?\s*[\s\S]*$',
        multiLine: true,
        caseSensitive: false,
      ),
      (_) => '',
    );

    text = text.replaceAll(
      RegExp(r'\n{3,}'),
      '\n\n',
    );

    return text.trim();
  }

  // ----------------------------------------------
  // UUID v4 (no extra package)
  // ----------------------------------------------
  String _generateSessionId() {
    final rand =
        Random.secure();

    String hex(
      int value,
      int width,
    ) =>
        value
            .toRadixString(16)
            .padLeft(width, '0');

    final a =
        hex(
      rand.nextInt(1 << 32),
      8,
    );

    final b =
        hex(
      rand.nextInt(1 << 16),
      4,
    );

    final c =
        hex(
      0x4000 |
          rand.nextInt(1 << 12),
      4,
    );

    final d =
        hex(
      0x8000 |
          rand.nextInt(1 << 14),
      4,
    );

    final e =
        hex(
          rand.nextInt(1 << 32),
          8,
        ) +
        hex(
          rand.nextInt(1 << 16),
          4,
        );

    return '$a-$b-$c-$d-$e';
  }
}