// ===============================================
// Emie • Chat Session Models (User-saved History)
// Pfad: lib/data/chat/chat_session_models.dart
// ===============================================

class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;

  // Nullable:
  // Fehlende oder ungültige Backend-Zeitstempel
  // werden nicht durch DateTime.now() ersetzt.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // -----------------------------------------------
  // DATE PARSER
  // -----------------------------------------------

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final raw = value.toString().trim();

    if (raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  // -----------------------------------------------
  // FROM JSON
  // -----------------------------------------------

  factory ChatSession.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawTitle =
        (json['title'] ?? '').toString().trim();

    return ChatSession(
      id: (
        json['id'] ??
        json['session_id'] ??
        ''
      )
          .toString()
          .trim(),

      // Kein erfundener "New chat"-Titel.
      //
      // Ein leerer Titel bleibt leer.
      // Die UI entscheidet später transparent,
      // wie ein titelloser Chat dargestellt wird.
      title: rawTitle,

      createdAt: _parseDate(
        json['created_at'],
      ),

      updatedAt: _parseDate(
        json['updated_at'] ??
            json['created_at'],
      ),
    );
  }

  // -----------------------------------------------
  // TO JSON
  // -----------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at':
          createdAt?.toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String(),
    };
  }
}