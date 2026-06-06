// ==============================================
// Emie • Home API
// Pfad: lib/data/home/api/home_api.dart
// ==============================================

import 'package:dio/dio.dart';

import '../../../api/client.dart';
import '../models/home_summary_model.dart';

class HomeApi {
  HomeApi({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  Future<HomeSummaryModel> fetchSummary() async {
    final res = await _dio.get('/v1/home/summary');

    return HomeSummaryModel.fromJson(
      res.data as Map<String, dynamic>,
    );
  }
}