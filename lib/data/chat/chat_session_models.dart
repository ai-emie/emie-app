// ===============================================
// Emie • Chat Session Models (User-saved History)
// Pfad: lib/data/chat/chat_session_models.dart
// ===============================================

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: (json['id'] ?? json['session_id'] ?? '').toString(),
      title: (json['title'] ?? 'New chat').toString(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
