import 'package:dio/dio.dart';
import 'package:pos_terminal/core/constants/api_endpoints.dart';
import 'package:pos_terminal/core/network/api_client.dart';

import 'package:pos_terminal/core/network/auth_interceptor.dart';

/// Handles authentication API calls: login, refresh, PIN verify.
class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Login with username/password. Returns {access, refresh} tokens.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {'username': username, 'password': password},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Verify user PIN code against backend.
  Future<bool> verifyPin(String pin) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.verifyPin,
        data: {'pin': pin},
      );
      return response.data['success'] == true;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Get current user info.
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.me);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Validate that a tenant exists and is active.
  Future<bool> validateTenant(String baseUrl) async {
    try {
      final tempDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final response = await tempDio.get(ApiEndpoints.validateTenant);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
