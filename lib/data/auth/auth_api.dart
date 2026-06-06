// ===============================================
// Emie • Auth API
// Pfad: lib/data/auth/auth_api.dart
// ===============================================

import 'package:dio/dio.dart';

import '../../api/client.dart';
import 'auth_models.dart';

class AuthApi {
  AuthApi({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  // -------------------------------------------
  // • Login (E-Mail & Passwort)
  //    Backend: POST /v1/auth/login
  // -------------------------------------------
  Future<TokenPair> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/v1/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    return TokenPair.fromJson(res.data as Map<String, dynamic>);
  }

  // -------------------------------------------
  // • Registrierung (E-Mail & Passwort)
  //    Backend: POST /v1/auth/register
  //    Response: VerifyResponse (KEIN TokenPair)
// -------------------------------------------
  Future<VerifyResponse> register({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/v1/auth/register',
      data: {
        'email': email,
        'password': password,
      },
    );

    return VerifyResponse.fromJson(res.data as Map<String, dynamic>);
  }

  // -------------------------------------------
  // • E-Mail verifizieren
  //    Backend: GET /v1/auth/verify?token=...
  // -------------------------------------------
  Future<VerifyResponse> verifyEmail({
    required String token,
  }) async {
    final res = await _dio.get(
      '/v1/auth/verify',
      queryParameters: {
        'token': token,
      },
    );

    return VerifyResponse.fromJson(res.data as Map<String, dynamic>);
  }

  // -------------------------------------------
  // • eigenes Profil laden
  //    Backend: GET /v1/me
  // -------------------------------------------
  Future<UserProfile> me() async {
    final res = await _dio.get('/v1/me');
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }

  // -------------------------------------------
  // • Google Login (Backend später)
  //    Backend: POST /v1/auth/google
  // -------------------------------------------
  Future<TokenPair> loginWithGoogle({
    required String idToken,
  }) async {
    final res = await _dio.post(
      '/v1/auth/google',
      data: {
        'id_token': idToken,
      },
    );

    return TokenPair.fromJson(res.data as Map<String, dynamic>);
  }

  // -------------------------------------------
  // • Apple Login
  //    Backend: POST /v1/auth/apple
  // -------------------------------------------
  Future<TokenPair> loginWithApple({
    required String identityToken,
  }) async {
    final res = await _dio.post(
      '/v1/auth/apple',
      data: {
        'id_token': identityToken,
      },
    );

  return TokenPair.fromJson(res.data as Map<String, dynamic>);
  }

  // -------------------------------------------
  // • Forgot Password
  //    Backend: POST /v1/auth/password/reset/start
  // -------------------------------------------
  Future<void> requestPasswordReset({required String email}) async {
    await _dio.post(
      '/v1/auth/password/reset/start',
      data: {'email': email},
    );
  }
}