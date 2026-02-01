// ===============================================
// Emie • Environment Config
// Pfad: lib/core/config/env.dart
// ===============================================

import 'package:flutter/foundation.dart';

enum EmieEnv { dev, prod }

class Env {
  // ===========================================================
  //  • BACKEND URLs
  // ===========================================================

  static const String _devBaseUrl = "http://10.0.2.2:8000";
  static const String _prodBaseUrl = "https://emie-backend-production.up.railway.app";

  /// Compile-time override:
  /// flutter run/build --dart-define=EMIE_ENV=prod
  static const String _envRaw = String.fromEnvironment('EMIE_ENV', defaultValue: '');

  /// Default behavior:
  /// - Release builds => PROD
  /// - Debug/Profile => DEV
  static EmieEnv get current {
    final v = _envRaw.trim().toLowerCase();
    if (v == 'prod' || v == 'production') return EmieEnv.prod;
    if (v == 'dev' || v == 'debug') return EmieEnv.dev;

    // Kein define gesetzt:
    return kReleaseMode ? EmieEnv.prod : EmieEnv.dev;
  }

  static String get apiBaseUrl =>
      current == EmieEnv.prod ? _prodBaseUrl : _devBaseUrl;

  // ===========================================================
  //  • GOOGLE LOGIN
  // ===========================================================

  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  // ===========================================================
  //  • APPLE LOGIN
  // ===========================================================

  static const String appleServiceId = String.fromEnvironment(
    'APPLE_CLIENT_ID',
    defaultValue: '',
  );
}

