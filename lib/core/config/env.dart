// ===============================================
// Emie • Environment Config
// Pfad: lib/core/config/env.dart
// ===============================================

import 'package:flutter/foundation.dart';
import 'local_debug_target.dart';
import 'public_target.dart';

enum EmieEnv { dev, prod }

class Env {
  static const String publicApiOrigin = String.fromEnvironment('EMIE_API_ORIGIN');
  static bool get publicRequested =>
      const bool.fromEnvironment('EMIE_PUBLIC') ||
      publicApiOrigin.isNotEmpty ||
      const ['prod', 'production'].contains(_envRaw.trim().toLowerCase()) ||
      current == EmieEnv.prod;
  static PublicTarget? get publicTarget => publicRequested
      ? resolvePublicTarget(
          apiOrigin: publicApiOrigin,
          recoveryOrigin: recoveryOrigin,
          environment: _envRaw.trim().toLowerCase(),
          localMode: localRequested ||
              const bool.fromEnvironment('EMIE_LOCAL_DEVICE') ||
              const String.fromEnvironment('EMIE_LOCAL_DEVICE_HOST').isNotEmpty ||
              const bool.fromEnvironment('EMIE_OFFLINE') ||
              const bool.fromEnvironment('EMIE_P1') ||
              const bool.fromEnvironment('EMIE_P3') ||
              const bool.fromEnvironment('EMIE_P4'))
      : null;
  static bool get offline =>
      localDebug && const bool.fromEnvironment('EMIE_OFFLINE');
  static bool get p1 => localDebug && const bool.fromEnvironment('EMIE_P1');
  static bool get p3 {
    if (!const bool.fromEnvironment('EMIE_P3')) return false;
    if (!localDebug || kIsWeb || defaultTargetPlatform != TargetPlatform.android ||
        localHost != '10.0.2.2' || localPort != 8011 ||
        const bool.fromEnvironment('EMIE_P1') ||
        const bool.fromEnvironment('EMIE_OFFLINE')) {
      throw StateError('P3 requires exclusive Android debug mode at 10.0.2.2:8011');
    }
    return true;
  }
  static bool get localAi => p3 || p1;

  static bool get p4 {
    if (!const bool.fromEnvironment('EMIE_P4')) return false;
    if (!localDebug || kIsWeb || defaultTargetPlatform != TargetPlatform.android ||
        localHost != '10.0.2.2' || localPort != 8011 || !offline ||
        const bool.fromEnvironment('EMIE_P1') || const bool.fromEnvironment('EMIE_P3')) {
      throw StateError('P4 requires exclusive offline Android auth at 10.0.2.2:8011');
    }
    return true;
  }

  static const bool localRequested = bool.fromEnvironment('EMIE_LOCAL');
  static bool get localDebug {
    // Validate an explicit device target even if EMIE_LOCAL was accidentally omitted.
    localHost;
    return kDebugMode && localRequested;
  }
  static String get localHost => resolveLocalDebugHost(
      web: kIsWeb,
      debug: kDebugMode,
      ios: defaultTargetPlatform == TargetPlatform.iOS,
      local: localRequested,
      device: const bool.fromEnvironment('EMIE_LOCAL_DEVICE'),
      host: const String.fromEnvironment('EMIE_LOCAL_DEVICE_HOST'));

  static const int _localPort =
      int.fromEnvironment('EMIE_LOCAL_PORT', defaultValue: 8010);
  static int get localPort {
    if (_localPort < 8010 || _localPort > 8019) {
      throw StateError('Unsupported local backend port');
    }
    return _localPort;
  }

  // Public origin must be supplied only after the actual domain is confirmed.
  static const String recoveryOrigin =
      String.fromEnvironment('EMIE_RECOVERY_ORIGIN');

  static bool allowsRecoveryOrigin(Uri uri) {
    final public = publicTarget;
    if (!uri.hasScheme && !uri.hasAuthority) return true;
    if (localDebug) {
      return uri.scheme == 'http' &&
          uri.host == localHost &&
          uri.port == localPort;
    }
    final allowed = Uri.tryParse(public?.recoveryOrigin ?? recoveryOrigin);
    return allowed != null &&
        allowed.scheme == 'https' &&
        allowed.host.isNotEmpty &&
        allowed.userInfo.isEmpty &&
        !allowed.hasQuery &&
        !allowed.hasFragment &&
        (allowed.path.isEmpty || allowed.path == '/') &&
        uri.scheme == 'https' &&
        uri.host == allowed.host &&
        uri.port == allowed.port;
  }
  // ===========================================================
  //  • BACKEND URLs
  // ===========================================================

  static const String _devBaseUrl = "http://10.0.2.2:8000";

  /// Compile-time override:
  /// flutter run/build --dart-define=EMIE_ENV=prod
  static const String _envRaw =
      String.fromEnvironment('EMIE_ENV', defaultValue: '');

  /// Default behavior:
  /// - Release builds => PROD
  /// - Debug => DEV, Profile/Release => PROD
  static EmieEnv get current {
    if (kReleaseMode || kProfileMode) return EmieEnv.prod;
    if (localDebug) return EmieEnv.dev;
    final v = _envRaw.trim().toLowerCase();
    if (v == 'prod' || v == 'production') return EmieEnv.prod;
    if (v == 'dev' || v == 'debug') return EmieEnv.dev;

    // Kein define gesetzt:
    return kReleaseMode ? EmieEnv.prod : EmieEnv.dev;
  }

  static String get apiBaseUrl {
    final public = publicTarget;
    p4;
    p3; // Reject inconsistent P3 targets before any HTTP client is constructed.
    if (public != null) return public.apiOrigin;
    return localDebug
      ? 'http://$localHost:$localPort'
      : _devBaseUrl;
  }

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
