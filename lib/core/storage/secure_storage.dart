import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

import '../../data/auth/auth_models.dart';

class SecureStorageService {
  SecureStorageService._();
  static FlutterSecureStorage _storage = const FlutterSecureStorage();
  @visibleForTesting
  static void useStorageForTesting(FlutterSecureStorage storage) {
    _storage = storage;
  }

  static const String _accessTokenKey = 'emie_access_token';
  static const String _refreshTokenKey = 'emie_refresh_token';

  // All access to these two keys shares this queue, including reads. A failed
  // operation releases it. A pair cannot interleave with another session's pair.
  static Future<void>? _tail;
  static Future<T> _ordered<T>(Future<T> Function() action) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return () async {
      if (previous != null) await previous;
      try {
        return await action();
      } finally {
        if (identical(_tail, released.future)) _tail = null;
        released.complete();
      }
    }();
  }

  static Future<bool> saveTokens({
    required String accessToken,
    String? refreshToken,
    bool Function()? isCurrent,
  }) =>
      _ordered(() async {
        if (isCurrent != null && !isCurrent()) return false;
        await _storage.write(key: _accessTokenKey, value: accessToken);
        if (isCurrent != null && !isCurrent()) return false;
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _storage.write(key: _refreshTokenKey, value: refreshToken);
        }
        return isCurrent == null || isCurrent();
      });

  static Future<({String? access, String? refresh})?> readTokens({
    required bool Function() isCurrent,
  }) =>
      _ordered(() async {
        if (!isCurrent()) return null;
        final access = await _storage.read(key: _accessTokenKey);
        final refresh = await _storage.read(key: _refreshTokenKey);
        if (!isCurrent()) return null;
        return (access: access, refresh: refresh);
      });

  static Future<String?> getAccessToken() =>
      _ordered(() => _storage.read(key: _accessTokenKey));
  static Future<String?> getRefreshToken() =>
      _ordered(() => _storage.read(key: _refreshTokenKey));
  static Future<bool> hasAccessToken() async =>
      (await getAccessToken())?.isNotEmpty == true;

  static Future<TokenCleanupResult> clearTokens({
    bool Function()? isCurrent,
  }) =>
      _ordered(() async {
        if (isCurrent != null && !isCurrent()) {
          return TokenCleanupResult.differentSession;
        }
        // Once this pair has started, finish both attempts before any new writes.
        // A new login may begin meanwhile, but its persisted pair is still queued.
        Future<LocalCleanupStep> remove(String key) async {
          try {
            await _storage.delete(key: key);
            return LocalCleanupStep.confirmed;
          } catch (_) {
            return LocalCleanupStep.unconfirmed;
          }
        }

        final access = await remove(_accessTokenKey);
        final refresh = await remove(_refreshTokenKey);
        return TokenCleanupResult(access, refresh);
      });
}
