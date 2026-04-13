import 'package:dio/dio.dart';
import 'package:pos_terminal/core/constants/api_endpoints.dart';
import 'package:pos_terminal/core/network/api_client.dart';
import 'package:pos_terminal/core/network/auth_interceptor.dart';
import 'package:pos_terminal/core/network/memory_cache.dart';
import 'package:pos_terminal/features/pos/data/models/customer_model.dart';

class CustomerRepository {
  final ApiClient _apiClient;
  final _balanceCache = MemoryCache<int, CustomerBalanceModel>(
    ttl: Duration(minutes: 2),
    maxEntries: 10,
  );

  CustomerRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Search customers by name, phone, or company.
  Future<List<CustomerModel>> searchCustomers(String query) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.customers,
        queryParameters: {'search': query},
      );
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
      return results
          .map((e) => CustomerModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Create a new customer.
  Future<CustomerModel> createCustomer({
    required String firstName,
    required String phone,
    String? lastName,
    String customerType = 'individual',
    String? address,
    double? debtLimitUzs,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName ?? '',
        'phone': phone,
        'customer_type': customerType,
      };
      if (address != null && address.isNotEmpty) data['address'] = address;
      if (debtLimitUzs != null) data['debt_limit_uzs'] = debtLimitUzs;
      if (notes != null && notes.isNotEmpty) data['notes'] = notes;
      final response = await _apiClient.dio.post(
        ApiEndpoints.customers,
        data: data,
      );
      final respData = response.data;
      final json = respData is Map && respData['data'] is Map
          ? respData['data'] as Map<String, dynamic>
          : respData as Map<String, dynamic>;
      return CustomerModel.fromJson(json);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Get customer balance & debt status — cached for 2 minutes.
  Future<CustomerBalanceModel> getCustomerBalance(int customerId) async {
    final cached = _balanceCache.get(customerId);
    if (cached != null) return cached;

    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.customerBalance(customerId),
      );
      final data = response.data;
      final balanceJson = data is Map && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      final balance = CustomerBalanceModel.fromJson(balanceJson);
      _balanceCache.set(customerId, balance);
      return balance;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Invalidate a specific customer's balance cache (call after sale).
  void invalidateBalance(int customerId) =>
      _balanceCache.invalidate(customerId);

  /// Invalidate all cached balances.
  void invalidateAllBalances() => _balanceCache.clear();
}
