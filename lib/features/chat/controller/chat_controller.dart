// ===============================================
// Emie • Chat Controller (Brain v2 + User-saved History)
// Pfad: lib/features/chat/controller/chat_controller.dart
// ===============================================

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../api/api_error.dart';
import '../../../state/session_store.dart';
import '../../../data/chat/chat_models.dart';
import '../../../data/chat/chat_repository.dart';
import '../../../data/chat/chat_session_models.dart';

class ChatController extends ChangeNotifier {
  ChatController({ChatRepository? repository})
      : _repository = repository ?? ChatRepository() {
    _chatSessionId = _generateSessionId();
  }

  final ChatRepository _repository;
  String get _unconfirmedReply => SessionStore.instance.language == 'de'
      ? 'Antwort nicht bestätigt. Bitte prüfe die Historie, bevor du erneut sendest.'
      : 'Response unconfirmed. Please check history before sending again.';
  // Requests may finish after the authenticated subtree has been removed.
  // Every async result belongs only to this controller's lifetime.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _messages.clear();
    _sessions.clear();
    _chatSessionId = '';
    _isSending = false;
    _isLoadingHistory = false;
    _isOpeningChat = false;
    _isDeleting = false;
    _lastSendConfirmed = false;
    _error = null;
    super.dispose();
  }

  // ----------------------------------------------
  // State: Sessions + Messages
  // ----------------------------------------------
  final List<ChatSession> _sessions = [];
  final List<ChatMessage> _messages = [];

  bool _isSending = false;
  bool _isDeleting = false;
  bool _isOpeningChat = false;
  bool _lastSendConfirmed = false;
  bool get lastSendConfirmed => _lastSendConfirmed;
  bool get isDeleting => _isDeleting;
  int _historyRequest = 0;
  int _openRequest = 0;
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
      _isLoadingHistory || _isOpeningChat;

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
  Future<String> getDailyWelcome({bool reportErrors = false}) async {
    if (_disposed) return '';
    try {
      final welcome = await _repository.getDailyWelcome();
      return _disposed ? '' : welcome;
    } catch (_) {
      if (reportErrors && !_disposed) rethrow;
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
    if (_disposed) return;
    final request = ++_historyRequest;
    _error = null;
    _isLoadingHistory = true;

    notifyListeners();

    try {
      if (_disposed || request != _historyRequest) return;
      final items =
          await _repository.listSessions();
      if (_disposed || request != _historyRequest) return;

      _sessions
        ..clear()
        ..addAll(items);
    } on DioException catch (e) {
      if (_disposed || request != _historyRequest) return;
      _debugDio(
        'ChatController.loadSessions DioException',
        e,
      );

      _error =
          'history_load_failed';
    } catch (e) {
      if (_disposed || request != _historyRequest) return;
      _debugErrorType(
        'ChatController.loadSessions error',
        e,
      );

      _error =
          'history_load_failed';
    } finally {
      if (!_disposed && request == _historyRequest) {
        _isLoadingHistory = false;
        notifyListeners();
      }
    }
  }

  Future<void> openChat(
    String sessionId,
  ) async {
    if (_disposed || _isSending || _isDeleting) return;
    final request = ++_openRequest;

    _error = null;
    _lastSendConfirmed = false;
    _isOpeningChat = true;

    notifyListeners();

    try {
      if (_disposed || request != _openRequest) return;


      // Backend:
      // GET /v1/chat/sessions/{id}
      // → Messages inline
      final msgs =
          await _repository.getMessages(
        sessionId,
      );
      if (_disposed || request != _openRequest) return;

      _chatSessionId = sessionId;
      _messages
        ..clear()
        ..addAll(msgs);
    } on DioException catch (e) {
      if (_disposed || request != _openRequest) return;
      _debugDio(
        'ChatController.openChat DioException',
        e,
      );

      _error =
          'chat_open_failed';
    } catch (e) {
      if (_disposed || request != _openRequest) return;
      _debugErrorType(
        'ChatController.openChat error',
        e,
      );

      _error =
          'chat_open_failed';
    } finally {
      if (!_disposed && request == _openRequest) {
        _isOpeningChat = false;
        notifyListeners();
      }
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
    if (_disposed || _isSending || _isDeleting) return;
    _openRequest++;
    _isOpeningChat = false;
    _lastSendConfirmed = false;

    _error = null;

    _messages.clear();

    _chatSessionId =
        _generateSessionId();

    notifyListeners();
  }

  // ----------------------------------------------
  // DELETE CHAT
  // ----------------------------------------------
  Future<bool> deleteChat(String sessionId) async {
    if (_disposed || _isSending || _isDeleting) return false;
    _openRequest++;
    _isOpeningChat = false;
    _isDeleting = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.deleteSession(sessionId);
      if (_disposed) return false;
      _sessions.removeWhere((session) => session.id == sessionId);
      if (_chatSessionId == sessionId) {
        _openRequest++;
        _isOpeningChat = false;
        _lastSendConfirmed = false;
        _messages.clear();
        _chatSessionId = _generateSessionId();
      }
      await loadSessions();
      return !_disposed;
    } catch (_) {
      if (!_disposed) _error = 'delete_unconfirmed';
      return false;
    } finally {
      if (!_disposed) { _isDeleting = false; notifyListeners(); }
    }
  }

  // ----------------------------------------------
  // SEND
  // ----------------------------------------------
  Future<void> send(
    String text,
  ) async {
    final trimmed = text.trim();

    if (_disposed ||
        trimmed.isEmpty ||
        _isSending || _isDeleting || isLoadingHistory) {
      return;
    }

    _error = null;
    _isSending = true;
    _lastSendConfirmed = false;

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
      if (_disposed) return;
      final reply =
          await _repository.sendUserMessage(
        text: trimmed,
        chatSessionId: _chatSessionId,
      );
      if (_disposed) return;

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

      _lastSendConfirmed = true;
      // Nach dem Senden Sessions neu laden.
      // title / updated_at kommen aus der DB.
      await loadSessions();
    } on DioException catch (e) {
      if (_disposed) return;
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
        _unconfirmedReply,
      );
    } catch (e) {
      if (_disposed) return;
      _debugErrorType(
        'ChatController.send unknown error',
        e,
      );

      _error =
          'Es ist ein unerwarteter Fehler aufgetreten.';

      _replaceTypingWithFallback(
        typingMsg.id,
        _unconfirmedReply,
      );
    } finally {
      if (!_disposed) {
        _isSending = false;
        notifyListeners();
      }
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
    if (_disposed) return;
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
