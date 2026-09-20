import 'package:dio/dio.dart';

import '../../core/storage/secure_storage.dart';
import '../../state/session_store.dart';
import 'auth_api.dart';
import 'auth_models.dart';
import 'apple_confirmation_models.dart';

class AuthRepository {
  AuthRepository({AuthApi? api}) : _api = api ?? AuthApi();
  final AuthApi _api;
  final SessionStore _session = SessionStore.instance;

  bool _confirmationCurrent(AppleConfirmationOperation operation, bool Function() owns) =>
      operation.valid && _session.isAuthenticated &&
      _session.isCurrent(operation.originGeneration) && owns();

  AppleConfirmationResult _confirmationFailure(AppleConfirmationOperation operation,
      AppleConfirmationReply reply) {
    final outcome = reply.stale ? AppleConfirmationOutcome.stale : switch (reply.statusCode) {
      401 => AppleConfirmationOutcome.authenticationRejected,
      404 => AppleConfirmationOutcome.notAvailable,
      409 => AppleConfirmationOutcome.conflict,
      400 => AppleConfirmationOutcome.invalidProof,
      _ => AppleConfirmationOutcome.unconfirmed,
    };
    return AppleConfirmationResult(outcome, operationId: operation.serverId);
  }

  Future<AppleConfirmationResult?> beginAppleConfirmation(AppleConfirmationOperation operation,
      {required bool Function() owns}) async {
    bool current() => _confirmationCurrent(operation, owns);
    if (!current()) return const AppleConfirmationResult(AppleConfirmationOutcome.stale);
    final reply = await _api.appleConfirmation(operation, 'POST', '', isCurrent: current);
    if (!current()) return const AppleConfirmationResult(AppleConfirmationOutcome.stale);
    final body = reply.body;
    if (reply.statusCode != 201 || body == null) return _confirmationFailure(operation, reply);
    final id = body['id'], nonce = body['nonce'], state = body['state'], expiry = body['expires_at'];
    if (id is! String || !RegExp(r'^[0-9a-f]{32}$').hasMatch(id) || id.length != 32 ||
        nonce is! String || state is! String || nonce == state ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(nonce) || nonce.length != 43 ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(state) || state.length != 43 ||
        expiry is! String || DateTime.tryParse(expiry) == null) {
      return const AppleConfirmationResult(AppleConfirmationOutcome.unconfirmed);
    }
    operation.serverId = id;
    operation.nonce = nonce;
    operation.state = state;
    return null;
  }

  Future<AppleConfirmationResult> finishAppleConfirmation(AppleConfirmationOperation operation,
      {required String identityToken, required String state, required bool Function() owns}) =>
      _mutateConfirmation(operation, 'complete', owns,
          data: {'id_token': identityToken, 'state': state});

  Future<AppleConfirmationResult> cancelAppleConfirmation(AppleConfirmationOperation operation,
      {required bool Function() owns}) => _mutateConfirmation(operation, 'cancel', owns);

  Future<AppleConfirmationResult> _mutateConfirmation(AppleConfirmationOperation operation,
      String action, bool Function() owns, {Map<String, String>? data}) async {
    bool current() => _confirmationCurrent(operation, owns);
    if (!current()) return const AppleConfirmationResult(AppleConfirmationOutcome.stale);
    final id = operation.serverId;
    if (id == null) return const AppleConfirmationResult(AppleConfirmationOutcome.unconfirmed);
    final reply = await _api.appleConfirmation(operation, 'POST', '/$id/$action',
        data: data, isCurrent: current);
    if (!current()) return const AppleConfirmationResult(AppleConfirmationOutcome.stale);
    final wanted = action == 'complete' ? 'confirmed' : 'cancelled';
    if (reply.statusCode == 200 && reply.body?['id'] == id && reply.body?['status'] == wanted) {
      return AppleConfirmationResult(action == 'complete'
          ? AppleConfirmationOutcome.confirmed : AppleConfirmationOutcome.cancelled, operationId: id);
    }
    final failure = _confirmationFailure(operation, reply);
    if (failure.outcome != AppleConfirmationOutcome.unconfirmed || operation.statusAttempted) return failure;
    operation.statusAttempted = true;
    if (!current()) return const AppleConfirmationResult(AppleConfirmationOutcome.stale);
    final status = await _api.appleConfirmation(operation, 'GET', '/$id', isCurrent: current);
    if (!current()) return const AppleConfirmationResult(AppleConfirmationOutcome.stale);
    if (status.statusCode != 200 || status.body?['id'] != id) return _confirmationFailure(operation, status);
    final outcome = switch (status.body?['status']) {
      'confirmed' => AppleConfirmationOutcome.confirmed,
      'cancelled' => AppleConfirmationOutcome.cancelled,
      'expired' => AppleConfirmationOutcome.conflict,
      _ => AppleConfirmationOutcome.unconfirmed, // pending is only a snapshot.
    };
    return AppleConfirmationResult(outcome, operationId: id);
  }

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
