// ===============================================
// Emie • Voice API
// Pfad: lib/data/voice/voice_api.dart
// ===============================================

import 'package:dio/dio.dart';

import '../../api/client.dart';
import 'voice_models.dart';

class VoiceApi {
  VoiceApi({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  /// audioBase64: vom Recorder encodete Audiodaten
  Future<VoiceResult> transcribe(String audioBase64) async {
    final res = await _dio.post(
      '/v1/voice/transcribe',
      data: {
        'audio_base64': audioBase64,
      },
    );

    return VoiceResult.fromJson(res.data as Map<String, dynamic>);
  }
}