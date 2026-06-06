// ==============================================
// Emie • Memory Model
// Pfad: lib/data/memory/models/memory_item.dart
// ==============================================

class MemoryItem {
  final String id;
  final String content;
  final String category;
  final int importance;
  final DateTime? createdAt;

  MemoryItem({
    required this.id,
    required this.content,
    required this.category,
    required this.importance,
    required this.createdAt,
  });

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      importance: json['importance'] as int? ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}