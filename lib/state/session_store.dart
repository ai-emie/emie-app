// ===============================================
// Emie • Session Store (Globaler App-Status)
// Pfad: lib/state/session_store.dart
// ===============================================

import 'dart:convert';
import 'package:flutter/material.dart';

import '../core/storage/secure_storage.dart';
import '../data/auth/auth_models.dart';

/// App-weite Theme-Optionen für Emie.
enum EmieThemeMode {
  system,
  light,
  dark,
}

/// Gesprächsstil / Ton von Emie.
enum EmieTone {
  friendly,
  neutral,
  focused,
}

class SessionStore extends ChangeNotifier {
  SessionStore._internal();
  @visibleForTesting
  SessionStore.forTesting();

  static final SessionStore instance = SessionStore._internal();

  // ===========================================
  // APP BOOTSTRAP
  // ===========================================

  int _generation = 0;
  int? _endedOrigin;
  int get generation => _generation;
  bool isCurrent(int generation) => _generation == generation;
  bool canFinish(int origin) => isCurrent(origin) || _endedOrigin == origin;

  /// Reserve a new identity before starting login/restore, including same-user
  /// and concurrent login attempts. Token rotation never calls this method.
  int beginSession({bool bootstrap = false}) {
    final reserved = ++_generation;
    _endedOrigin = null;
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _isBootstrapping = bootstrap;
    notifyListeners();
    return reserved;
  }

  SessionEndContext endSession(int origin) {
    if (isCurrent(origin)) {
      // A listener may synchronously begin B while clear() notifies. Preserve
      // the post-state belonging to this end operation, not B's newer ID.
      final completion = _generation + 1;
      clear();
      return SessionEndContext(origin, completion, LocalSessionEnd.ended);
    }
    if (_endedOrigin == origin) {
      return SessionEndContext(
          origin, _generation, LocalSessionEnd.alreadyEnded);
    }
    return SessionEndContext(origin, null, LocalSessionEnd.differentSession);
  }

  bool _isBootstrapping = true;

  bool get isBootstrapping => _isBootstrapping;

  int beginBootstrap() => beginSession(bootstrap: true);

  void finishBootstrap({int? generation}) {
    if (generation != null && !isCurrent(generation)) return;
    _isBootstrapping = false;
    notifyListeners();
  }

  // ===========================================
  // ONLINE / OFFLINE
  // ===========================================

  bool _isOnline = true;

  bool get isOnline => _isOnline;

  void setOnline(bool value) {
    if (_isOnline == value) return;

    _isOnline = value;

    notifyListeners();
  }

  // ===========================================
  // AUTH / TOKENS / USER
  // ===========================================

  String? _accessToken;
  String? _refreshToken;

  UserProfile? _user;

  String? get accessToken => _accessToken;

  String? get refreshToken => _refreshToken;

  UserProfile? get user => _user;

  bool get isAuthenticated {
    return _accessToken != null && _accessToken!.isNotEmpty && _user != null;
  }

  bool get hasRefreshToken {
    return _refreshToken != null && _refreshToken!.isNotEmpty;
  }

  void updateTokens(
    String access, {
    String? refresh,
    int? generation,
  }) {
    if (generation != null && !isCurrent(generation)) return;
    _accessToken = access;

    if (refresh != null && refresh.isNotEmpty) {
      _refreshToken = refresh;
    }

    notifyListeners();
  }

  void updateUser(UserProfile user, {int? generation}) {
    if (generation != null && !isCurrent(generation)) return;
    _user = user;

    notifyListeners();
  }

  // ===========================================
  // RESTORE SESSION / APP START
  // ===========================================

  Future<void> restoreSession({int? generation}) async {
    final origin = generation ?? _generation;
    final tokens = await SecureStorageService.readTokens(
      isCurrent: () => isCurrent(origin),
    );
    if (tokens == null || !isCurrent(origin)) return;
    _accessToken = tokens.access;
    _refreshToken = tokens.refresh;
    notifyListeners();
  }

  // ===========================================
  // LOGOUT / RESET
  // ===========================================

  void clear() {
    _endedOrigin = _generation;
    _generation++;
    _isBootstrapping = false;
    _accessToken = null;
    _refreshToken = null;
    _user = null;

    _tone = EmieTone.friendly;
    _isOnline = true;

    notifyListeners();
  }

  // ===========================================
  // USER PREFERENCES
  // ===========================================

  EmieThemeMode _themeMode = EmieThemeMode.dark;

  EmieTone _tone = EmieTone.friendly;

  String _language = 'de';

  bool preferencesFailed = false;
  bool preferencesSaving = false;
  int _preferenceRevision = 0;
  Future<void> loadPreferences() async {
    final revision = _preferenceRevision;
    try {
      final raw = await SecureStorageService.readPreferences();
      if (revision != _preferenceRevision) return;
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _themeMode = EmieThemeMode.values.firstWhere((mode) => mode.name == data['theme']);
        if (data['language'] != 'de' && data['language'] != 'en') throw const FormatException();
        _language = data['language'] as String;
      } else {
        _themeMode = EmieThemeMode.dark;
        _language = 'de';
      }
      preferencesFailed = false;
    } catch (_) { if (revision == _preferenceRevision) preferencesFailed = true; }
    notifyListeners();
  }

  Future<void> persistPreferences() async {
    final revision = ++_preferenceRevision;
    final value = jsonEncode({'theme': _themeMode.name, 'language': _language});
    preferencesSaving = true;
    preferencesFailed = false;
    notifyListeners();
    try { await SecureStorageService.writePreferences(value); }
    catch (_) { if (revision == _preferenceRevision) preferencesFailed = true; }
    finally {
      if (revision == _preferenceRevision) { preferencesSaving = false; notifyListeners(); }
    }
  }

  EmieThemeMode get themeMode => _themeMode;

  EmieTone get tone => _tone;

  String get language => _language;

  // ===========================================
  // FLUTTER THEME MODE
  // ===========================================

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case EmieThemeMode.system:
        return ThemeMode.system;

      case EmieThemeMode.light:
        return ThemeMode.light;

      case EmieThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  // ===========================================
  // LOCALE
  // ===========================================

  Locale get locale => Locale(_language);

  // ===========================================
  // SETTERS
  // ===========================================

  Future<void> setThemeMode(EmieThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    await persistPreferences();
  }

  void setTone(EmieTone value) {
    if (_tone == value) return;

    _tone = value;

    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    final normalized = (code == 'de') ? 'de' : 'en';

    if (_language == normalized) return;

    _language = normalized;
    await persistPreferences();
  }

  // ===========================================
  // DISPLAY NAME
  // ===========================================

  String get displayName {
    final user = _user;

    if (user == null) {
      return 'Emie Nutzer';
    }

    final name = (user.name ?? '').trim();

    if (name.isNotEmpty) {
      return name;
    }

    final mail = user.email.trim();

    if (mail.contains('@')) {
      return mail.split('@').first;
    }

    return 'Emie Nutzer';
  }

  // ===========================================
  // DISPLAY INITIAL
  // ===========================================

  String get displayInitial {
    final n = displayName.trim();

    if (n.isEmpty) {
      return 'E';
    }

    return n.characters.first.toUpperCase();
  }
}
