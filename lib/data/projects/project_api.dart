import 'package:dio/dio.dart';
import '../../api/client.dart';
import '../../state/paged_list.dart';

class Project {
  const Project(
      {required this.id,
      required this.name,
      required this.description,
      required this.content,
      required this.createdAt,
      required this.updatedAt});
  final String id, name, description, content;
  final DateTime createdAt, updatedAt;
  factory Project.fromJson(Map<String, dynamic> json) => Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String));
}

class ProjectApi {
  ProjectApi({Dio? dio}) : dio = dio ?? ApiClient().dio;
  final Dio dio;
  Future<ListPage<Project>> list(int offset, int generation) async {
    final response = await dio.get('/v1/projects',
        queryParameters: {'offset': offset, 'limit': 20},
        options: ApiClient.sessionOptions(generation));
    final data = response.data as Map<String, dynamic>;
    return ListPage(
        (data['items'] as List).map((e) => Project.fromJson(e)).toList(),
        data['total_items'] as int,
        data['offset'] as int,
        data['limit'] as int);
  }

  Future<Project> get(String id, int generation) async =>
      Project.fromJson((await dio.get('/v1/projects/$id',
              options: ApiClient.sessionOptions(generation)))
          .data);
  Future<Project> save(
      {String? id,
      required String name,
      required String description,
      required String content,
      required int generation}) async {
    final body = {'name': name, 'description': description, 'content': content};
    final options = ApiClient.sessionOptions(generation, noRefresh: true);
    final response = id == null
        ? await dio.post('/v1/projects', data: body, options: options)
        : await dio.put('/v1/projects/$id', data: body, options: options);
    return Project.fromJson(response.data);
  }

  Future<void> delete(String id, int generation) async {
    final response = await dio.delete('/v1/projects/$id',
        options: ApiClient.sessionOptions(generation, noRefresh: true));
    if (response.data is! Map || response.data['deleted'] != id) {
      throw const FormatException('Deletion not confirmed');
    }
  }
}
