// ===============================================
// Emie • Chat Models (Hardened)
// Pfad: lib/data/chat/chat_models.dart
// ===============================================

class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  // ----------------------------------------------
  //  Helpers (defensiv)
  // ----------------------------------------------
  static String _safeString(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  static String _safeRole(dynamic v) {
    final s = _safeString(v).trim();
    if (s == 'user' || s == 'assistant') return s;
    return 'assistant';
  }

  static String _pickText(Map<String, dynamic> json) {
    // Wir akzeptieren mehrere mögliche Keys (Backend/Altlasten)
    final candidates = [
      json['answer'],   // BrainResponse
      json['reply'],    // ChatResponse (backend /v1/chat/respond)
      json['content'],
      json['text'],
      json['message'],
      json['final_answer'], // HRM endpoint alt
    ];

    for (final c in candidates) {
      final s = _safeString(c).trim();
      if (s.isNotEmpty) return s;
    }

    // Hard fallback: niemals leer
    return 'Ich bin da. Schreib mir bitte kurz nochmal, was du brauchst.';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    final text = _pickText(json);

    String role = 'assistant';
    if (json['role'] != null) {
      role = _safeRole(json['role']);
    } else if (json['is_user'] != null) {
      final isUser = json['is_user'] == true;
      role = isUser ? 'user' : 'assistant';
    }

    final idRaw = json['id'] ?? json['message_id'] ?? now.millisecondsSinceEpoch;
    final id = idRaw.toString();

    DateTime createdAt = now;
    if (json['created_at'] != null) {
      createdAt = DateTime.tryParse(json['created_at'].toString()) ?? now;
    }

    return ChatMessage(
      id: id,
      role: role,
      text: text,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': text,
        'created_at': createdAt.toIso8601String(),
      };
}

class ChatHistoryPage {
  final List<ChatMessage> items;
  final String? nextCursor;
  final bool hasMore;

  ChatHistoryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory ChatHistoryPage.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] ?? json['messages'] ?? json['history'] ?? []) as List<dynamic>;

    return ChatHistoryPage(
      items: list
          .whereType<Map<String, dynamic>>()
          .map((e) => ChatMessage.fromJson(e))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
      hasMore: (json['has_more'] ?? json['hasMore'] ?? false) as bool,
    );
  }
}
