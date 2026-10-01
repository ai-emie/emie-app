import 'package:dio/dio.dart';
import '../../../api/client.dart';
import '../../../state/paged_list.dart';
import '../../../state/session_store.dart';
import '../models/memory_item.dart';

class MemoryApi {
  MemoryApi({Dio? dio}) : _dio = dio ?? ApiClient().dio;
  final Dio _dio;
  Future<ListPage<MemoryItem>> fetchPage(
      {int offset = 0,
      String? category,
      String? search,
      int? generation}) async {
    final response = await _dio.get('/v1/memory/list',
        queryParameters: {
          'limit': 20,
          'offset': offset,
          if (category != null && category != 'all') 'category': category,
          if (search != null && search.trim().isNotEmpty)
            'search_query': search.trim(),
        },
        options: ApiClient.sessionOptions(generation));
    final data = response.data as Map<String, dynamic>;
    return ListPage(
        (data['items'] as List).map((e) => MemoryItem.fromJson(e)).toList(),
        data['total_items'] as int,
        data['offset'] as int,
        data['limit'] as int);
  }

  Future<List<MemoryItem>> fetchMemories() async => (await fetchPage()).items;
  Future<MemoryItem?> getById(String id, int generation) async {
    var offset = 0;
    while (SessionStore.instance.isCurrent(generation)) {
      final page = await fetchPage(offset: offset, generation: generation);
      page.validate(offset);
      for (final item in page.items) {
        if (item.id == id) return item;
      }
      offset += page.items.length;
      if (offset >= page.total || page.items.isEmpty) return null;
    }
    return null;
  }

  Future<void> deleteMemory(String id, {int? generation}) async {
    final response = await _dio.delete('/v1/memory/$id',
        options: ApiClient.sessionOptions(generation, noRefresh: true));
    if (response.data is! Map || response.data['deleted'] != id) {
      throw const FormatException('Deletion not confirmed');
    }
  }

  Future<MemoryItem> updateMemory(
      {required String id,
      String? content,
      int? importance,
      int? generation}) async {
    final response = await _dio.patch('/v1/memory/$id',
        data: {
          if (content != null) 'value': content,
          if (importance != null) 'importance': importance,
        },
        options: ApiClient.sessionOptions(generation, noRefresh: true));
    return MemoryItem.fromJson(response.data as Map<String, dynamic>);
  }
}
