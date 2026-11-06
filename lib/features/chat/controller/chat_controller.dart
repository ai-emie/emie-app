// ===============================================
// Emie • Chat Controller (Brain v2 + User-saved History)
// Pfad: lib/features/chat/controller/chat_controller.dart
// ===============================================

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../api/api_error.dart';
import '../../../core/config/env.dart';
import '../../../state/session_store.dart';
import '../../../data/chat/chat_models.dart';
import '../../../data/chat/pending_action.dart';
import '../../../data/chat/chat_repository.dart';
import '../../../data/chat/chat_session_models.dart';

class ChatController extends ChangeNotifier {
  ChatController({ChatRepository? repository, PendingActionStore? pendingStore})
      : _repository = repository ?? ChatRepository(),
        _pendingStore = pendingStore ?? const PendingActionStore(),
        _generation = SessionStore.instance.generation,
        _owner = SessionStore.instance.user == null ? null :
          (SessionStore.instance.user!.id.isNotEmpty ? SessionStore.instance.user!.id : 'email:${SessionStore.instance.user!.email}') {
    _chatSessionId = _generateSessionId();
  }

  final ChatRepository _repository;
  final PendingActionStore _pendingStore;
  final int _generation;
  final String? _owner;
  String? _pendingAction;
  String? _pendingSession;
  Future<void>? _pendingLoad;
  bool get hasPendingAction => _pendingAction != null;
  bool get _inactive => _disposed || !SessionStore.instance.isCurrent(_generation);

  Future<void> _restorePending() => _pendingLoad ??= _readPending();

  Future<void> _readPending() async {
    if (Env.localAi || Env.offline) return;
    final value = await _pendingStore.read(_owner);
    if (_inactive) return;
    _pendingAction = value?['action'];
    _pendingSession = value?['session'];
  }

  Future<void> checkPendingAction() async {
    if (_inactive || _isSending || _isOpeningChat) return;
    _isSending = true;
    notifyListeners();
    try {
      await _restorePending();
      final id = _pendingAction, session = _pendingSession;
      if (_inactive || id == null || session == null) return;
      final status = await _repository.actionStatus(id);
      if (_inactive || status['session_id'] != session) return;
      final state = status['state'];
      if (state == 'completed' || state == 'failed') {
        final messages = status['error_code'] == 'not_found' ? <ChatMessage>[] : await _repository.getMessages(session);
        if (_inactive) return;
        await _pendingStore.clear(_owner);
        if (_inactive) return;
        _pendingAction = null;
        _pendingSession = null;
        _chatSessionId = session;
        _messages..clear()..addAll(messages);
        _lastSendConfirmed = state == 'completed';
        _error = state == 'completed' ? null : _actionError(status['error_code']);
      } else {
        _error = _unconfirmedReply;
      }
    } catch (_) {
      if (!_inactive) _error = _unconfirmedReply;
    } finally {
      if (!_inactive) { _isSending = false; notifyListeners(); }
    }
  }

  String _actionError(dynamic code) => ApiError.fromDio(DioException(
    requestOptions: RequestOptions(),
    response: Response(requestOptions: RequestOptions(), statusCode: 503,
      data: {'detail': {'code': 'AI_${code.toString().toUpperCase()}'}}),
  )).message;
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
    if (_inactive) return '';
    try {
      final welcome = await _repository.getDailyWelcome();
      return _inactive ? '' : welcome;
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
    if (_inactive) return;
    final request = ++_historyRequest;
    _error = null;
    _isLoadingHistory = true;

    notifyListeners();

    try {
      if (_inactive || request != _historyRequest) return;
      final items = await _repository.listSessions();
      await _restorePending();
      if (_inactive || request != _historyRequest) return;

      _sessions
        ..clear()
        ..addAll(items);
    } on DioException catch (e) {
      if (_inactive || request != _historyRequest) return;
      _debugDio(
        'ChatController.loadSessions DioException',
        e,
      );

      _error =
          'history_load_failed';
    } catch (e) {
      if (_inactive || request != _historyRequest) return;
      _debugErrorType(
        'ChatController.loadSessions error',
        e,
      );

      _error =
          'history_load_failed';
    } finally {
      if (!_inactive && request == _historyRequest) {
        _isLoadingHistory = false;
        notifyListeners();
      }
    }
  }

  Future<void> openChat(
    String sessionId,
  ) async {
    if (_inactive || _isSending || _isDeleting) return;
    final request = ++_openRequest;

    _error = null;
    _lastSendConfirmed = false;
    _isOpeningChat = true;

    notifyListeners();

    try {
      if (_inactive || request != _openRequest) return;


      // Backend:
      // GET /v1/chat/sessions/{id}
      // → Messages inline
      final msgs =
          await _repository.getMessages(
        sessionId,
      );
      if (_inactive || request != _openRequest) return;

      if (!Env.localAi && !Env.offline) {
        final actions = await _repository.sessionActions(sessionId);
        if (_inactive || request != _openRequest) return;
        final unresolved = actions.where((a) => a['state'] == 'in_progress' || a['state'] == 'uncertain');
        if (unresolved.isNotEmpty) {
          final action = unresolved.first['id'] as String;
          await _pendingStore.save(_owner, action, sessionId);
          if (_inactive || request != _openRequest) return;
          _pendingAction = action;
          _pendingSession = sessionId;
          _error = _unconfirmedReply;
        }
      }
      _chatSessionId = sessionId;
      _messages
        ..clear()
        ..addAll(msgs.map((message) => message.role == 'assistant'
            ? ChatMessage(
                id: message.id,
                role: message.role,
                text: _sanitizeAssistantText(message.text),
                createdAt: message.createdAt,
              )
            : message));
    } on DioException catch (e) {
      if (_inactive || request != _openRequest) return;
      _debugDio(
        'ChatController.openChat DioException',
        e,
      );

      _error =
          'chat_open_failed';
    } catch (e) {
      if (_inactive || request != _openRequest) return;
      _debugErrorType(
        'ChatController.openChat error',
        e,
      );

      _error =
          'chat_open_failed';
    } finally {
      if (!_inactive && request == _openRequest) {
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
    if (_inactive || _isSending || _isDeleting) return;
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
    if (_inactive || _isSending || _isDeleting) return false;
    _openRequest++;
    _isOpeningChat = false;
    _isDeleting = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.deleteSession(sessionId);
      if (_inactive) return false;
      _sessions.removeWhere((session) => session.id == sessionId);
      if (_chatSessionId == sessionId) {
        _openRequest++;
        _isOpeningChat = false;
        _lastSendConfirmed = false;
        _messages.clear();
        _chatSessionId = _generateSessionId();
      }
      await loadSessions();
      return !_inactive;
    } catch (_) {
      if (!_inactive) _error = 'delete_unconfirmed';
      return false;
    } finally {
      if (!_inactive) { _isDeleting = false; notifyListeners(); }
    }
  }

  // ----------------------------------------------
  // SEND
  // ----------------------------------------------
  Future<void> send(
    String text,
  ) async {
    final trimmed = text.trim();

    if (_inactive || Env.offline ||
        trimmed.isEmpty ||
        _isSending || _isDeleting || isLoadingHistory) {
      return;
    }

    if (hasPendingAction) {
      await checkPendingAction();
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
      if (_inactive) return;
      if (!Env.localAi) await _restorePending();
      if (_inactive) return;
      if (hasPendingAction) {
        _messages.removeWhere((m) => m.id == typingMsg.id || m.id == userMsg.id);
        _error = _unconfirmedReply;
        return;
      }
      final action = _generateSessionId();
      if (!Env.localAi) {
        await _pendingStore.save(_owner, action, _chatSessionId);
        if (_inactive) return;
        _pendingAction = action;
        _pendingSession = _chatSessionId;
      }
      final reply = await _repository.sendUserMessage(
        text: trimmed,
        chatSessionId: _chatSessionId,
        actionId: action,
      );
      if (_inactive) return;

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

      if (!Env.localAi) await _pendingStore.clear(_owner);
      if (_inactive) return;
      _pendingAction = null;
      _pendingSession = null;
      _lastSendConfirmed = true;
      // Nach dem Senden Sessions neu laden.
      // title / updated_at kommen aus der DB.
      await loadSessions();
    } on DioException catch (e) {
      if (_inactive) return;
      _debugDio(
        'ChatController.send DioException',
        e,
      );

      final apiError =
          ApiError.fromDio(e);

      final body = e.response?.data;
      final detail = body is Map ? body['detail'] : null;
      final code = detail is Map ? detail['code'] : (body is Map ? body['code'] : null);
      const terminal = {'AI_BUDGET', 'AI_AI_DISABLED', 'AI_PRICING', 'AI_PROVIDER',
        'AI_LIMIT', 'AI_ACTION_REQUIRED', 'AI_ACTION_CONFLICT'};
      if (!Env.localAi && terminal.contains(code)) {
        try {
          await _pendingStore.clear(_owner);
          if (_inactive) return;
          _pendingAction = null;
          _pendingSession = null;
        } catch (_) { /* Keep the pending ID if durable local cleanup fails. */ }
      }
      _error =
          apiError.message;
      if ((apiError.type == ApiErrorType.network || apiError.type == ApiErrorType.timeout)) {
        _error = 'Verbindung unterbrochen oder Zeitüberschreitung. Ausgang unklar; nicht erneut senden. Historie und lokalen Status prüfen.';
      }

      _messages.removeWhere((message) => message.id == typingMsg.id);
    } catch (e) {
      if (_inactive) return;
      _debugErrorType(
        'ChatController.send unknown error',
        e,
      );

      _error =
          'Es ist ein unerwarteter Fehler aufgetreten.';

      _messages.removeWhere((message) => message.id == typingMsg.id);
    } finally {
      if (!_inactive) {
        _isSending = false;
        notifyListeners();
      }
    }
  }

  // ----------------------------------------------
  // ERROR
  // ----------------------------------------------
  void clearError() {
    if (_inactive) return;
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

    // JavaScript bitwise shifts are 32-bit; 1 << 32 becomes zero on web.
    const uint32Range = 0x100000000;

    final a =
        hex(
      rand.nextInt(uint32Range),
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
          rand.nextInt(uint32Range),
          8,
        ) +
        hex(
          rand.nextInt(1 << 16),
          4,
        );

    return '$a-$b-$c-$d-$e';
  }
}
