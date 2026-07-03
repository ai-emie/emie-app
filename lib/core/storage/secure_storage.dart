// ===============================================
// Emie • Secure Storage Service
// Pfad: lib/core/storage/secure_storage.dart
// ===============================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _accessTokenKey = 'emie_access_token';
  static const String _refreshTokenKey = 'emie_refresh_token';

  // ------------------------------
  // TOKEN SPEICHERN
  // ------------------------------
  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  // ------------------------------
  // TOKEN LESEN
  // ------------------------------
  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  // ------------------------------
  // LOGIN STATUS
  // ------------------------------
  static Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ------------------------------
  // LOGOUT / ALLES LÖSCHEN
  // ------------------------------
  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}