// ==============================================
// Emie • Memory API
// Pfad: lib/data/memory/api/memory_api.dart
// ==============================================

import 'package:dio/dio.dart';

import '../../../api/client.dart';
import '../models/memory_item.dart';

class MemoryApi {
  MemoryApi({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  Future<List<MemoryItem>> fetchMemories() async {
    final res = await _dio.get('/v1/memory/list');

    final data = res.data;

    if (data is List) {
      return data
          .map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (data is Map<String, dynamic>) {
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => MemoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<void> deleteMemory(String id) async {
    await _dio.delete('/v1/memory/$id');
  }

  Future<MemoryItem> updateMemory({
    required String id,
    String? content,
    int? importance,
  }) async {
    final body = <String, dynamic>{};

    if (content != null) body['value'] = content;
    if (importance != null) body['importance'] = importance;

    final res = await _dio.patch(
      '/v1/memory/$id',
      data: body,
    );

    return MemoryItem.fromJson(res.data as Map<String, dynamic>);
  }
}