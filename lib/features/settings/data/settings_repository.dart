import 'package:dio/dio.dart';
import 'package:pos_terminal/core/constants/api_endpoints.dart';
import 'package:pos_terminal/core/network/api_client.dart';
import 'package:pos_terminal/core/network/auth_interceptor.dart';
import 'package:pos_terminal/features/settings/data/warehouse_model.dart';

class SettingsRepository {
  final ApiClient _apiClient;

  SettingsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Fetch all warehouses the user has access to.
  Future<List<WarehouseModel>> getWarehouses() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.warehouses);
      final data = response.data;
      final List<dynamic> items =
          data is Map && data['data'] is Map && data['data']['items'] is List
          ? data['data']['items'] as List
          : data is Map && data['data'] is List
          ? data['data'] as List
          : data is List
          ? data
          : [];
      return items
          .map((e) => WarehouseModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
