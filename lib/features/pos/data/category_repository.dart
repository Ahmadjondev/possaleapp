import 'package:dio/dio.dart';
import 'package:pos_terminal/core/constants/api_endpoints.dart';
import 'package:pos_terminal/core/network/api_client.dart';
import 'package:pos_terminal/core/network/auth_interceptor.dart';
import 'package:pos_terminal/core/network/memory_cache.dart';
import 'package:pos_terminal/features/pos/data/models/category_model.dart';

class CategoryRepository {
  final ApiClient _apiClient;
  final _cache = MemoryCache<String, List<CategoryModel>>(
    ttl: Duration(minutes: 10),
    maxEntries: 1,
  );

  CategoryRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get all product categories (cached for 10 minutes).
  Future<List<CategoryModel>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get('categories');
      if (cached != null) return cached;
    }

    try {
      final response = await _apiClient.dio.get(ApiEndpoints.categories);
      final data = response.data;
      final List<dynamic> results =
          data is Map && data['data'] is Map && data['data']['items'] is List
          ? data['data']['items'] as List
          : data is Map && data['data'] is List
          ? data['data'] as List
          : data is Map && data['results'] is List
          ? data['results'] as List
          : data is List
          ? data
          : [];
      final categories = results
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache.set('categories', categories);
      return categories;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Force-clear the cached categories.
  void invalidateCache() => _cache.clear();
}
