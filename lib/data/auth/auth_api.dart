import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../api/client.dart';
import '../../state/session_store.dart';
import 'auth_models.dart';
import 'apple_confirmation_models.dart';

class AuthApi {
  AuthApi({Dio? dio}) : _dio = dio ?? ApiClient().dio;
  final Dio _dio;

  Future<AppleConfirmationReply> appleConfirmation(
      AppleConfirmationOperation operation, String method, String suffix,
      {Map<String, String>? data, required bool Function() isCurrent,
      bool forDeletion = false}) async {
    final complete = method == 'POST' && suffix.endsWith('/complete');
    final id = operation.serverId,
        state = operation.state,
        nonce = operation.nonce;
    final expiry = operation.expiresAt;
    final accountId = SessionStore.instance.user?.id;
    bool current() =>
        operation.valid &&
        SessionStore.instance.isAuthenticated &&
        SessionStore.instance.user?.id == accountId &&
        SessionStore.instance.isCurrent(operation.originGeneration) &&
        isCurrent() &&
        (!complete ||
            (operation.serverId == id &&
                operation.state == state &&
                operation.nonce == nonce &&
                operation.expiresAt == expiry &&
                operation.isUnexpired));
    if (!current()) return const AppleConfirmationReply(null, stale: true);
    if (complete) {
      if (!AppleConfirmationInput.valid(data) ||
          data?['state'] != state ||
          id == null ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(id) ||
          id.length != 32 ||
          suffix != '/$id/complete') {
        return const AppleConfirmationReply(422);
      }
      if (!operation.claimComplete()) return const AppleConfirmationReply(409);
    }
    // No shared interceptors, auth-refresh replay or automatic redirects.
    final local = Dio(_dio.options.copyWith());
    local.transformer = _dio.transformer;
    local.httpClientAdapter = _AppleConfirmationTransport(
        _dio.httpClientAdapter, current,
        onSend: complete ? () => operation.completeSent = true : null);
    final access = SessionStore.instance.accessToken;
    final options =
        ApiClient.sessionOptions(operation.originGeneration, noRefresh: true)
            .copyWith(
                method: method,
                responseType: ResponseType.bytes,
                validateStatus: (_) => true,
                followRedirects: false,
                receiveDataWhenStatusError: false,
                headers: {
          'Authorization': 'Bearer $access',
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        });
    Response<List<int>>? response;
    try {
      if (!current()) return const AppleConfirmationReply(null, stale: true);
      response = await local.request<List<int>>(
          forDeletion ? '/v1/me/apple-deletion$suffix' : '/v1/auth/apple/confirmations$suffix',
          data: data,
          options: options,
          cancelToken: operation.transportCancellation);
      if (!current()) return const AppleConfirmationReply(null, stale: true);
      Map<String, dynamic>? body;
      try {
        final value = jsonDecode(utf8.decode(response.data ?? []));
        if (value is Map<String, dynamic>) {
          if ((response.statusCode ?? 0) >= 400) {
            // Retain only known machine codes, never server messages/details.
            const codes = {
              'apple_code_binding_not_demonstrable',
              'apple_code_binding_invalid',
              'apple_code_binding_unavailable',
              'INVALID_PROOF',
              'UNAUTHORIZED',
              'NOT_FOUND',
              'CONFLICT',
              'VALIDATION_ERROR',
              'UNCONFIRMED',
              'apple_deletion_unavailable',
              'apple_deletion_unconfirmed',
              'apple_deletion_outcome_unknown'
            };
            if (value['ok'] == false && codes.contains(value['code'])) {
              body = {'ok': false, 'code': value['code']};
            }
          } else if (complete && forDeletion) {
            if (parseDeletionReply(response.statusCode, value).confirmsDeletion) {
              body = {'status': 'deleted', 'apple_revocation': value['apple_revocation']};
            }
          } else if (complete) {
            if (value.length == 2 &&
                value['id'] == id &&
                value['status'] == 'confirmed') {
              body = {'id': id, 'status': 'confirmed'};
            }
          } else {
            body = value;
          }
        }
      } catch (_) {
        // Preserve the HTTP status even when the body cannot be decoded.
      }
      return AppleConfirmationReply(response.statusCode, body: body);
    } on DioException catch (error) {
      error.requestOptions.data = null;
      error.response?.data = null;
      if (!current()) return const AppleConfirmationReply(null, stale: true);
      return AppleConfirmationReply(error.response?.statusCode);
    } catch (_) {
      return AppleConfirmationReply(null, stale: !current());
    } finally {
      data?.clear();
      response?.requestOptions.data = null;
      response?.data = null;
      // The adapter deliberately does not close the shared underlying transport.
      local.close();
    }
  }

  /// Shared strict wire parser; backend-generated fixtures exercise this method.
  static DeletionServerResult parseDeletionReply(int? status, dynamic body) {
    if (status == 401) return DeletionServerResult.authenticationRejected;
    if (status == 409 && body is Map && body['ok'] == false &&
        body['code'] == 'apple_deletion_required') {
      return DeletionServerResult.appleRequired;
    }
    if (status != 200 || body is! Map || body['status'] != 'deleted') {
      return DeletionServerResult.unconfirmed;
    }
    if (!body.containsKey('apple_revocation')) return DeletionServerResult.confirmed;
    return switch (body['apple_revocation']) {
      'pending' => DeletionServerResult.applePending,
      'acknowledged' => DeletionServerResult.appleAcknowledged,
      'not_confirmed' => DeletionServerResult.appleNotConfirmed,
      'manual_required' => DeletionServerResult.appleManualRequired,
      _ => DeletionServerResult.unconfirmed,
    };
  }

  Future<TokenPair> login(
      {required String email,
      required String password,
      int? generation}) async {
    final response = await _dio.post('/v1/auth/login',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        data: {'email': email, 'password': password});
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  Future<VerifyResponse> register(
      {required String name,
      required String email,
      required String password,
      int? generation}) async {
    final response = await _dio.post('/v1/auth/register',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        data: {'name': name, 'email': email, 'password': password});
    return VerifyResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<VerifyResponse> verifyEmail(
      {required String token, int? generation}) async {
    final response = await _dio.post('/v1/auth/verify',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        data: {'token': token});
    return VerifyResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserProfile> me({int? generation}) async {
    final response =
        await _dio.get('/v1/me', options: ApiClient.sessionOptions(generation));
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DeletionServerResult> deleteAccount({required int generation}) async {
    if (!SessionStore.instance.isCurrent(generation)) {
      return DeletionServerResult.notSent;
    }
    try {
      final response = await _dio.delete('/v1/me',
          // Keep a rejected HTTP status even if its unused error body is invalid.
          options: ApiClient.sessionOptions(generation, noRefresh: true)
              .copyWith(receiveDataWhenStatusError: false,
                  validateStatus: (code) => code != null &&
                      ((code >= 200 && code < 300) || code == 409)));
      return parseDeletionReply(response.statusCode, response.data);
    } on DioException catch (error) {
      if (error.error is StaleSessionException) {
        return DeletionServerResult.notSent;
      }
      return error.response?.statusCode == 401
          ? DeletionServerResult.authenticationRejected
          : DeletionServerResult.unconfirmed;
    } catch (_) {
      return DeletionServerResult.unconfirmed;
    }
  }

  Future<TokenPair> loginWithGoogle(
      {required String idToken, int? generation}) async {
    final response = await _dio.post('/v1/auth/google',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        data: {'id_token': idToken});
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TokenPair> loginWithApple(
      {required String identityToken, int? generation}) async {
    final response = await _dio.post('/v1/auth/apple',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        data: {'id_token': identityToken});
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TokenPair> refresh(
      {required String refreshToken, int? generation}) async {
    final response = await _dio.post('/v1/auth/refresh',
        // Error bodies are unused; decoding them must not hide an HTTP 401.
        options: ApiClient.sessionOptions(generation, noRefresh: true)
            .copyWith(receiveDataWhenStatusError: false),
        data: {'refresh_token': refreshToken});
    return TokenPair.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout({required String refreshToken, int? generation}) async {
    await _dio.post('/v1/auth/logout',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        data: {'refresh_token': refreshToken});
  }

  Future<void> requestPasswordReset(
      {required String email, int? generation}) async {
    _requireRecoveryAck(await _dio.post('/v1/auth/password/reset/start',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        data: {'email': email}));
  }
  Future<void> finishPasswordReset(
      {required String token, required String newPassword, int? generation}) async {
    _requireRecoveryAck(await _dio.post('/v1/auth/password/reset/finish',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        data: {'token': token, 'new_password': newPassword}));
  }

  Future<void> requestVerificationResend(
      {required String email, int? generation}) async {
    _requireRecoveryAck(await _dio.post('/v1/auth/verify/resend',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        data: {'email': email}));
  }

  void _requireRecoveryAck(Response<dynamic> response) {
    if (response.statusCode != 200 ||
        response.data is! Map || response.data['status'] != 'ok') {
      throw StateError('Recovery acknowledgement unavailable');
    }
  }
}

class _AppleConfirmationTransport implements HttpClientAdapter {
  _AppleConfirmationTransport(this.delegate, this.isCurrent, {this.onSend});
  final void Function()? onSend;
  bool _sent = false;
  final HttpClientAdapter delegate;
  final bool Function() isCurrent;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) {
    if (!isCurrent() || _sent) {
      throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const StaleSessionException());
    }
    _sent = true;
    onSend?.call();
    return delegate.fetch(options, stream, cancelFuture).whenComplete(() {
      options.data = null;
    });
  }

  @override
  void close({bool force = false}) {}
}
