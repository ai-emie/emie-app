// ===============================================
// Emie • Session Store (Globaler App-Status)
// Pfad: lib/state/session_store.dart
// ===============================================

import 'package:flutter/material.dart';

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
  static final SessionStore instance = SessionStore._internal();

  // -------------------------------------------
  //  Online / Offline
  // -------------------------------------------
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void setOnline(bool value) {
    if (_isOnline == value) return;
    _isOnline = value;
    notifyListeners();
  }

  // -------------------------------------------
  //  Auth / Tokens / User
  // -------------------------------------------
  String? _accessToken;
  String? _refreshToken;
  UserProfile? _user;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  UserProfile? get user => _user;

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  bool get hasRefreshToken => _refreshToken != null && _refreshToken!.isNotEmpty;

  void updateTokens(
    String access, {
    String? refresh,
  }) {
    _accessToken = access;
    if (refresh != null && refresh.isNotEmpty) {
      _refreshToken = refresh;
    }
    notifyListeners();
  }

  void updateUser(UserProfile user) {
    _user = user;
    notifyListeners();
  }

  /// Session komplett leeren (Logout)
  void clear() {
    _accessToken = null;
    _refreshToken = null;
    _user = null;

    // Defaults zurücksetzen
    _themeMode = EmieThemeMode.dark;
    _tone = EmieTone.friendly;
    _language = 'de';
    _isOnline = true;

    notifyListeners();
  }

  // -------------------------------------------
  //  User Preferences (Theme, Sprache, Ton)
  // -------------------------------------------
  EmieThemeMode _themeMode = EmieThemeMode.dark;
  EmieTone _tone = EmieTone.friendly;
  String _language = 'de'; // 'de' oder 'en'

  EmieThemeMode get themeMode => _themeMode;
  EmieTone get tone => _tone;
  String get language => _language;

  /// Für `MaterialApp.themeMode`
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

  /// Für `MaterialApp.locale`
  Locale get locale => Locale(_language);

  void setThemeMode(EmieThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setTone(EmieTone value) {
    if (_tone == value) return;
    _tone = value;
    notifyListeners();
  }

  void setLanguage(String code) {
    final normalized = (code == 'de') ? 'de' : 'en';
    if (_language == normalized) return;
    _language = normalized;
    notifyListeners();
  }

  // -------------------------------------------
  //  Helper: Anzeigename für Profil
  // -------------------------------------------
  String get displayName {
    final user = _user;
    if (user == null) return 'Emie Nutzer';

    final name = (user.name ?? '').trim();
    if (name.isNotEmpty) return name;

    final mail = user.email.trim();
    if (mail.contains('@')) return mail.split('@').first;

    return 'Emie Nutzer';
  }

  /// Erster Buchstabe für den runden Avatar.
  String get displayInitial {
    final n = displayName.trim();
    if (n.isEmpty) return 'E';
    return n.characters.first.toUpperCase();
  }
}
