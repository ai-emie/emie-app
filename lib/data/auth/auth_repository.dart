import 'package:dio/dio.dart';

import '../../core/storage/secure_storage.dart';
import '../../state/session_store.dart';
import 'auth_api.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository({AuthApi? api}) : _api = api ?? AuthApi();
  final AuthApi _api;
  final SessionStore _session = SessionStore.instance;

  void _requireCurrent(int generation) {
    if (!_session.isCurrent(generation)) {
      throw const StaleSessionException();
    }
  }

  Future<UserProfile> _login(
      Future<TokenPair> Function(int) request, int? generation) async {
    final origin = generation ?? _session.beginSession();
    _requireCurrent(origin);
    try {
      final tokens = await request(origin);
      _requireCurrent(origin);
      _session.updateTokens(tokens.accessToken,
          refresh: tokens.refreshToken, generation: origin);
      await SecureStorageService.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          isCurrent: () => _session.isCurrent(origin));
      _requireCurrent(origin);
      return await refreshProfile(generation: origin);
    } catch (_) {
      if (_session.isCurrent(origin)) {
        final ended = _session.endSession(origin);
        await SecureStorageService.clearTokens(
            isCurrent: () => _session.isCurrent(ended.completionGeneration!));
      }
      rethrow;
    }
  }

  Future<UserProfile> loginWithEmail(String email, String password,
          {int? generation}) =>
      _login(
          (origin) =>
              _api.login(email: email, password: password, generation: origin),
          generation);

  Future<UserProfile> loginWithGoogle(String idToken, {int? generation}) =>
      _login(
          (origin) =>
              _api.loginWithGoogle(idToken: idToken, generation: origin),
          generation);

  Future<UserProfile> loginWithApple(String identityToken, {int? generation}) =>
      _login(
          (origin) => _api.loginWithApple(
              identityToken: identityToken, generation: origin),
          generation);

  Future<VerifyResponse> registerWithEmail(
          {required String name,
          required String email,
          required String password,
          int? generation}) =>
      _api.register(
          name: name,
          email: email,
          password: password,
          generation: generation ?? _session.generation);

  Future<VerifyResponse> verifyEmail(String token, {int? generation}) => _api
      .verifyEmail(token: token, generation: generation ?? _session.generation);

  Future<UserProfile> refreshProfile({int? generation}) async {
    final origin = generation ?? _session.generation;
    _requireCurrent(origin);
    final user = await _api.me(generation: origin);
    _requireCurrent(origin);
    _session.updateUser(user, generation: origin);
    return user;
  }

  Future<void> refreshTokens() async {
    final origin = _session.generation;
    final refresh = _session.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      throw StateError('No refresh token');
    }
    final TokenPair tokens;
    try {
      tokens = await _api.refresh(refreshToken: refresh, generation: origin);
    } on DioException catch (error) {
      // This direct entry owns its 401 completion; the client never replays it.
      if (error.response?.statusCode == 401 && _session.isCurrent(origin)) {
        final ended = _session.endSession(origin);
        await SecureStorageService.clearTokens(
            isCurrent: () => _session.isCurrent(ended.completionGeneration!));
      }
      rethrow;
    }
    _requireCurrent(origin);
    _session.updateTokens(tokens.accessToken,
        refresh: tokens.refreshToken, generation: origin);
    await SecureStorageService.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        isCurrent: () => _session.isCurrent(origin));
    _requireCurrent(origin);
  }

  Future<SessionEndContext> logout({int? generation}) async {
    final origin = generation ?? _session.generation;
    if (!_session.isCurrent(origin)) {
      return _session.endSession(origin);
    }
    final refresh = _session.refreshToken;
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _api.logout(refreshToken: refresh, generation: origin);
      }
    } catch (_) {
      // An unavailable backend does not prevent ending this local session.
    }
    final ended = _session.endSession(origin);
    if (ended.completionGeneration != null) {
      await SecureStorageService.clearTokens(
          isCurrent: () => _session.isCurrent(ended.completionGeneration!));
    }
    return ended;
  }

  Future<AccountDeletionResult> deleteAccount(
      [AccountDeletionOperation? operation]) {
    final request = operation ??
        AccountDeletionOperation(_session.generation, _session.language);
    return request.repositoryCompletion ??= _deleteAccount(request);
  }

  Future<AccountDeletionResult> _deleteAccount(
      AccountDeletionOperation operation) async {
    final origin = operation.originGeneration;
    if (!_session.isCurrent(origin) || !_session.isAuthenticated) {
      return AccountDeletionResult(
          operation: operation,
          server: DeletionServerResult.notSent,
          sessionEnd: LocalSessionEnd.differentSession,
          tokens: TokenCleanupResult.differentSession,
          google: LocalCleanupStep.differentSession);
    }
    final server = await _api.deleteAccount(generation: origin);
    if (server != DeletionServerResult.confirmed &&
        server != DeletionServerResult.authenticationRejected) {
      return AccountDeletionResult(
          operation: operation,
          server: server,
          sessionEnd: _session.isCurrent(origin)
              ? LocalSessionEnd.unchanged
              : LocalSessionEnd.differentSession);
    }
    // Invalidate RAM synchronously, before awaiting either storage operation.
    // The post-state ID remains usable for A cleanup until a new login begins.
    final ended = _session.endSession(origin);
    final completion = ended.completionGeneration;
    final tokens = completion == null
        ? TokenCleanupResult.differentSession
        : await SecureStorageService.clearTokens(
            isCurrent: () => _session.isCurrent(completion));
    return AccountDeletionResult(
        operation: operation,
        server: server,
        sessionEnd: ended.result,
        completionGeneration: completion,
        tokens: tokens,
        google: completion == null
            ? LocalCleanupStep.differentSession
            : LocalCleanupStep.notRequired);
  }

  Future<void> requestPasswordReset(String email, {int? generation}) =>
      _api.requestPasswordReset(
          email: email, generation: generation ?? _session.generation);
}
