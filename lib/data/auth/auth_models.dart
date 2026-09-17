// ===============================================
// Emie • Auth Models
// Pfad: lib/data/auth/auth_models.dart
// ===============================================

class TokenPair {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int accessExpiresMinutes;
  final int refreshExpiresDays;

  TokenPair({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    this.accessExpiresMinutes = 0,
    this.refreshExpiresDays = 0,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      accessExpiresMinutes: (json['access_expires_minutes'] as int?) ?? 0,
      refreshExpiresDays: (json['refresh_expires_days'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
        'access_expires_minutes': accessExpiresMinutes,
        'refresh_expires_days': refreshExpiresDays,
      };
}

// -------------------------------------------
//  Verify Response (Register / Verify)
// -------------------------------------------
class VerifyResponse {
  final String message;
  final String? tokenPreview; // dev-help

  VerifyResponse({
    required this.message,
    this.tokenPreview,
  });

  factory VerifyResponse.fromJson(Map<String, dynamic> json) {
    return VerifyResponse(
      message: (json['message'] ?? '') as String,
      tokenPreview: json['token_preview'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        'token_preview': tokenPreview,
      };
}

// -------------------------------------------
//  User Profile aus /v1/me
// -------------------------------------------
class UserProfile {
  final String id;
  final String email;
  final String? name;

  const UserProfile({
    required this.id,
    required this.email,
    this.name,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      // Backend kann "name" oder "display_name" schicken – wir fangen beides ab
      name: (json['name'] ?? json['display_name']) as String?,
    );
  }
}

// Tokens wie bisher
class AuthTokens {
  final String accessToken;
  final String? refreshToken;

  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'],
    );
  }
}

// Login/Register Ergebnis: Tokens + User
class AuthResult {
  final AuthTokens tokens;
  final UserProfile user;

  const AuthResult({
    required this.tokens,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      tokens: AuthTokens.fromJson(json),
      user: UserProfile.fromJson(json['user'] ?? const {}),
    );
  }
}

// These process-local IDs contain no credentials and are never sent to the API.
enum DeletionServerResult {
  confirmed,
  authenticationRejected,
  unconfirmed,
  notSent
}

enum LocalSessionEnd { ended, alreadyEnded, unchanged, differentSession }

enum LocalCleanupStep { confirmed, unconfirmed, notRequired, differentSession }

class TokenCleanupResult {
  const TokenCleanupResult(this.access, this.refresh);
  final LocalCleanupStep access;
  final LocalCleanupStep refresh;
  static const notRequired = TokenCleanupResult(
      LocalCleanupStep.notRequired, LocalCleanupStep.notRequired);
  static const differentSession = TokenCleanupResult(
      LocalCleanupStep.differentSession, LocalCleanupStep.differentSession);
}

class SessionEndContext {
  const SessionEndContext(
      this.originGeneration, this.completionGeneration, this.result);
  final int originGeneration;
  final int? completionGeneration;
  final LocalSessionEnd result;
}

/// Captured when opening the dialog. Reusing this object reuses its one request.
class AccountDeletionOperation {
  AccountDeletionOperation(this.originGeneration, this.language);
  final int originGeneration;
  final String language;
  final Object id = Object();
  Future<AccountDeletionResult>? repositoryCompletion;
  Future<AccountDeletionResult>? controllerCompletion;
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.operation,
    required this.server,
    this.sessionEnd = LocalSessionEnd.unchanged,
    this.completionGeneration,
    this.tokens = TokenCleanupResult.notRequired,
    this.google = LocalCleanupStep.notRequired,
  });
  final AccountDeletionOperation operation;
  final DeletionServerResult server;
  final LocalSessionEnd sessionEnd;
  final int? completionGeneration;
  final TokenCleanupResult tokens;
  final LocalCleanupStep google;

  AccountDeletionResult withGoogle(LocalCleanupStep value) =>
      AccountDeletionResult(
        operation: operation,
        server: server,
        sessionEnd: sessionEnd,
        completionGeneration: completionGeneration,
        tokens: tokens,
        google: value,
      );

  String message(String language) {
    final de = language == 'de';
    final lines = <String>[];
    switch (server) {
      case DeletionServerResult.confirmed:
        lines.add(de
            ? 'Die Löschung deines Kontos wurde bestätigt.\nDu bist in dieser App abgemeldet.'
            : 'Your account deletion was confirmed.\nYou are signed out of this app.');
        break;
      case DeletionServerResult.authenticationRejected:
        lines.add(de
            ? 'Bitte melde dich erneut an.\nFür diesen Löschversuch liegt keine Löschbestätigung vor.'
            : 'Please sign in again.\nThis deletion attempt has not been confirmed.');
        break;
      case DeletionServerResult.unconfirmed:
        lines.add(de
            ? 'Wir konnten nicht bestätigen, ob dein Konto gelöscht wurde.\nDer Löschvorgang wird nicht automatisch wiederholt.'
            : 'We could not confirm whether your account was deleted.\nThe deletion will not be retried automatically.');
        break;
      case DeletionServerResult.notSent:
        return '';
    }
    if (tokens.access == LocalCleanupStep.unconfirmed ||
        tokens.refresh == LocalCleanupStep.unconfirmed) {
      lines.add(de
          ? 'Die vollständige Entfernung der gespeicherten Zugangsdaten auf diesem Gerät konnte nicht bestätigt werden.'
          : 'Complete removal of the saved credentials on this device could not be confirmed.');
    }
    if (google == LocalCleanupStep.unconfirmed) {
      lines.add(de
          ? 'Die lokale Google-Abmeldung konnte nicht bestätigt werden.'
          : 'Local Google sign-out could not be confirmed.');
    }
    return lines.join('\n\n');
  }
}

/// Control flow only: never carries credentials or an HTTP response.
class StaleSessionException implements Exception {
  const StaleSessionException();
}
