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
      {Map<String, String>? data, required bool Function() isCurrent}) async {
    bool current() => operation.valid &&
        SessionStore.instance.isCurrent(operation.originGeneration) && isCurrent();
    if (!current()) return const AppleConfirmationReply(null, stale: true);
    // Request-local transport keeps the shared client/transformer unchanged.
    // In particular, no shared response interceptor mutates SessionStore.
    final local = Dio(_dio.options.copyWith());
    local.transformer = _dio.transformer;
    local.httpClientAdapter = _AppleConfirmationTransport(_dio.httpClientAdapter, current);
    final access = SessionStore.instance.accessToken;
    final options = ApiClient.sessionOptions(operation.originGeneration, noRefresh: true)
        .copyWith(method: method, responseType: ResponseType.plain,
            receiveDataWhenStatusError: false,
            headers: {'Authorization': 'Bearer $access',
              'Content-Type': 'application/json', 'Accept': 'application/json'});
    try {
      if (!current()) return const AppleConfirmationReply(null, stale: true);
      final response = await local.request<String>('/v1/auth/apple/confirmations$suffix',
          data: data, options: options, cancelToken: operation.transportCancellation);
      if (!current()) return const AppleConfirmationReply(null, stale: true);
      Map<String, dynamic>? body;
      try {
        final value = jsonDecode(response.data ?? '');
        if (value is Map<String, dynamic>) body = value;
      } catch (_) {
        // Invalid success data leaves the result unknown; no POST replay.
      }
      return AppleConfirmationReply(response.statusCode, body: body);
    } on DioException catch (error) {
      if (!current()) return const AppleConfirmationReply(null, stale: true);
      return AppleConfirmationReply(error.response?.statusCode);
    } catch (_) {
      return AppleConfirmationReply(null, stale: !current());
    } finally {
      // The adapter deliberately does not close the shared underlying transport.
      local.close();
    }
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
    final response = await _dio.get('/v1/auth/verify',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        queryParameters: {'token': token});
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
              .copyWith(receiveDataWhenStatusError: false));
      final body = response.data;
      return response.statusCode == 200 &&
              body is Map<String, dynamic> &&
              body['status'] == 'deleted'
          ? DeletionServerResult.confirmed
          : DeletionServerResult.unconfirmed;
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
    await _dio.post('/v1/auth/password/reset/start',
        options: ApiClient.sessionOptions(generation, noRefresh: true),
        data: {'email': email});
  }
}

class _AppleConfirmationTransport implements HttpClientAdapter {
  _AppleConfirmationTransport(this.delegate, this.isCurrent);
  final HttpClientAdapter delegate;
  final bool Function() isCurrent;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) {
    if (!isCurrent()) {
      throw DioException(requestOptions: options, type: DioExceptionType.cancel,
          error: const StaleSessionException());
    }
    return delegate.fetch(options, stream, cancelFuture);
  }
  @override
  void close({bool force = false}) {}
}
