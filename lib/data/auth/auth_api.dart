import 'package:dio/dio.dart';

import '../../api/client.dart';
import '../../state/session_store.dart';
import 'auth_models.dart';

class AuthApi {
  AuthApi({Dio? dio}) : _dio = dio ?? ApiClient().dio;
  final Dio _dio;

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
