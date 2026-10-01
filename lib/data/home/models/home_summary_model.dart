import '../../memory/models/memory_item.dart';
import '../../projects/project_api.dart';

class HomeSummaryModel {
  const HomeSummaryModel(
      {required this.totalMemories,
      required this.memoriesToday,
      required this.totalProjects,
      required this.generatedAt,
      this.recentProject,
      this.recentMemory});
  final int totalMemories, memoriesToday, totalProjects;
  final Project? recentProject;
  final MemoryItem? recentMemory;
  final DateTime generatedAt;
  factory HomeSummaryModel.fromJson(Map<String, dynamic> json) {
    final stats = json['user_stats'] as Map<String, dynamic>;
    return HomeSummaryModel(
        totalMemories: stats['total_memories'] as int,
        memoriesToday: stats['memories_today'] as int,
        totalProjects: stats['total_projects'] as int,
        generatedAt: DateTime.parse(json['generated_at'] as String),
        recentProject: json['recent_project'] == null
            ? null
            : Project.fromJson(json['recent_project']),
        recentMemory: json['recent_memory'] == null
            ? null
            : MemoryItem.fromJson(json['recent_memory']));
  }
}
