// ===============================================
// Emie • Voice Models
// Pfad: lib/data/voice/voice_models.dart
// ===============================================

class VoiceResult {
  final String text;

  VoiceResult({required this.text});

  factory VoiceResult.fromJson(Map<String, dynamic> json) {
    return VoiceResult(
      text: (json['text'] ?? json['transcript'] ?? '') as String,
    );
  }
}
