// ===============================================
// Emie • Voice Repository
// Pfad: lib/data/voice/voice_repository.dart
// ===============================================

import 'voice_api.dart';


class VoiceRepository {
  VoiceRepository({VoiceApi? api}) : _api = api ?? VoiceApi();

  final VoiceApi _api;

  Future<String> transcribeToText(String audioBase64) async {
    final result = await _api.transcribe(audioBase64);
    return result.text;
  }
}
