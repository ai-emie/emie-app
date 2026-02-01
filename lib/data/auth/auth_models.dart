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
      accessExpiresMinutes:
          (json['access_expires_minutes'] as int?) ?? 0,
      refreshExpiresDays:
          (json['refresh_expires_days'] as int?) ?? 0,
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
