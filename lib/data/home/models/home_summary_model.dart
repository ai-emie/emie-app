// ==============================================
// Emie • Home Summary Model
// Pfad: lib/data/home/models/home_summary_model.dart
// ==============================================

class HomeSummaryModel {
  final int energyLevel;
  final String energyLabel;
  final HomeTopProjectModel topProject;
  final String dailyInsight;
  final HomeUserStatsModel userStats;
  final DateTime? generatedAt;

  HomeSummaryModel({
    required this.energyLevel,
    required this.energyLabel,
    required this.topProject,
    required this.dailyInsight,
    required this.userStats,
    required this.generatedAt,
  });

  factory HomeSummaryModel.fromJson(Map<String, dynamic> json) {
    return HomeSummaryModel(
      energyLevel: json['energy_level'] as int? ?? 60,
      energyLabel: json['energy_label'] as String? ?? 'Ruhig & fokussiert',
      topProject: HomeTopProjectModel.fromJson(
        json['top_project'] as Map<String, dynamic>? ?? {},
      ),
      dailyInsight: json['daily_insight'] as String? ?? '',
      userStats: HomeUserStatsModel.fromJson(
        json['user_stats'] as Map<String, dynamic>? ?? {},
      ),
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
    );
  }
}

class HomeTopProjectModel {
  final String name;
  final int entriesCount;
  final double progress;
  final String statusText;

  HomeTopProjectModel({
    required this.name,
    required this.entriesCount,
    required this.progress,
    required this.statusText,
  });

  factory HomeTopProjectModel.fromJson(Map<String, dynamic> json) {
    return HomeTopProjectModel(
      name: json['name'] as String? ?? 'Emie',
      entriesCount: json['entries_count'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      statusText:
          json['status_text'] as String? ?? 'Ein neues Kapitel beginnt.',
    );
  }
}

class HomeUserStatsModel {
  final int totalMemories;
  final int memoriesToday;

  HomeUserStatsModel({
    required this.totalMemories,
    required this.memoriesToday,
  });

  factory HomeUserStatsModel.fromJson(Map<String, dynamic> json) {
    return HomeUserStatsModel(
      totalMemories: json['total_memories'] as int? ?? 0,
      memoriesToday: json['memories_today'] as int? ?? 0,
    );
  }
}