import 'package:dio/dio.dart';
import 'package:pos_terminal/core/constants/api_endpoints.dart';
import 'package:pos_terminal/core/network/api_client.dart';
import 'package:pos_terminal/core/network/auth_interceptor.dart';
import 'package:pos_terminal/core/network/memory_cache.dart';
import 'package:pos_terminal/features/pos/data/models/draft_model.dart';
import 'package:pos_terminal/features/pos/data/models/exchange_rate_model.dart';
import 'package:pos_terminal/features/pos/data/models/product_model.dart';
import 'package:pos_terminal/features/pos/data/models/receipt_model.dart';
import 'package:pos_terminal/features/pos/data/models/sale_model.dart';

class PosRepository {
  final ApiClient _apiClient;

  // --- Caches ---
  final _searchCache = MemoryCache<String, List<ProductModel>>(
    ttl: Duration(minutes: 2),
    maxEntries: 20,
  );
  final _exchangeRateCache = MemoryCache<String, ExchangeRateModel>(
    ttl: Duration(minutes: 30),
    maxEntries: 1,
  );
  final _featuredCache = MemoryCache<String, List<ProductModel>>(
    ttl: Duration(minutes: 5),
    maxEntries: 1,
  );
  final _salesCache = MemoryCache<String, List<SaleModel>>(
    ttl: Duration(minutes: 2),
    maxEntries: 5,
  );

  PosRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Search products by name, code, barcode, or OEM (cached for 2 minutes).
  Future<List<ProductModel>> searchProducts({
    required String query,
    required int warehouseId,
    int? categoryId,
    int limit = 50,
    bool includeParts = true,
  }) async {
    final cacheKey = '$query|$warehouseId|$categoryId';
    final cached = _searchCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final params = <String, dynamic>{
        'search': query,
        'warehouse': warehouseId,
        'limit': limit,
        'include_parts': includeParts,
      };
      if (categoryId != null) params['category'] = categoryId;

      final response = await _apiClient.dio.get(
        ApiEndpoints.posSearch,
        queryParameters: params,
      );
      final data = response.data;
      final List<dynamic> results = data is Map && data['data'] is List
          ? data['data'] as List
          : data is Map && data['results'] is List
          ? data['results'] as List
          : data is List
          ? data
          : [];
      final products = results
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _searchCache.set(cacheKey, products);
      return products;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Scan barcode/code/OEM to find a single product.
  Future<ProductModel?> scanBarcode({
    required String barcode,
    required int warehouseId,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.posScan,
        queryParameters: {'barcode': barcode, 'warehouse': warehouseId},
      );
      final data = response.data;
      if (data == null) return null;
      final product = data is Map && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data is Map
          ? data as Map<String, dynamic>
          : null;
      if (product == null) return null;
      return ProductModel.fromJson(product);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Process a quick sale (main POS checkout).
  Future<SaleModel> quickSale(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.posQuickSale,
        data: payload,
      );
      final data = response.data;
      final saleJson = data is Map && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      return SaleModel.fromJson(saleJson);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Fetch receipt data for printing.
  Future<ReceiptModel> getReceipt(int saleId) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.posReceipt(saleId),
      );
      final data = response.data;
      final receiptJson = data is Map && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      return ReceiptModel.fromJson(receiptJson);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Mark receipt as printed.
  Future<void> markReceiptPrinted(int saleId) async {
    try {
      await _apiClient.dio.post(ApiEndpoints.posReceiptPrinted(saleId));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Get current exchange rate (USD → UZS) — cached for 30 minutes.
  Future<ExchangeRateModel> getExchangeRate() async {
    final cached = _exchangeRateCache.get('rate');
    if (cached != null) return cached;

    try {
      final response = await _apiClient.dio.get(ApiEndpoints.posExchangeRate);
      final data = response.data;
      final rateJson = data is Map && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      final rate = ExchangeRateModel.fromJson(rateJson);
      _exchangeRateCache.set('rate', rate);
      return rate;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Save current cart as draft.
  Future<DraftModel> saveDraft(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.posSaveDraft,
        data: payload,
      );
      final data = response.data;
      final draftJson = data is Map && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      return DraftModel.fromJson(draftJson);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// List all drafts.
  Future<List<DraftModel>> getDrafts() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.posDrafts);
      final data = response.data;
      final List<dynamic> results = data is Map && data['data'] is List
          ? data['data'] as List
          : data is Map && data['results'] is List
          ? data['results'] as List
          : data is List
          ? data
          : [];
      return results
          .map((e) => DraftModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Load a specific draft.
  Future<DraftModel> getDraft(int draftId) async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.posDraft(draftId));
      final data = response.data;
      final draftJson = data is Map && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data as Map<String, dynamic>;
      return DraftModel.fromJson(draftJson);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Delete a draft.
  Future<void> deleteDraft(int draftId) async {
    try {
      await _apiClient.dio.delete(ApiEndpoints.posDraftDelete(draftId));
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Process a return.
  Future<void> processReturn(Map<String, dynamic> payload) async {
    try {
      await _apiClient.dio.post(ApiEndpoints.posReturn, data: payload);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Fetch admin-curated featured (fast-selling) products — cached for 5 minutes.
  Future<List<ProductModel>> getFeaturedProducts({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _featuredCache.get('featured');
      if (cached != null) return cached;
    }

    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.featuredProducts,
        queryParameters: {'page_size': 100},
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
      final products = results.map((e) {
        final item = e as Map<String, dynamic>;
        final productJson = item['product'] as Map<String, dynamic>? ?? item;
        return ProductModel.fromJson(productJson);
      }).toList();
      _featuredCache.set('featured', products);
      return products;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Fetch featured items with their IDs (for management).
  Future<List<Map<String, dynamic>>> getFeaturedItems() async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.featuredProducts,
        queryParameters: {'page_size': 200},
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
      return results.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Add a product to featured list.
  Future<void> addFeaturedProduct(int productId, int displayOrder) async {
    try {
      await _apiClient.dio.post(
        ApiEndpoints.featuredProducts,
        data: {'product': productId, 'display_order': displayOrder},
      );
      _featuredCache.clear();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Remove a featured product by its featured-item ID.
  Future<void> removeFeaturedProduct(int featuredItemId) async {
    try {
      await _apiClient.dio.delete(
        ApiEndpoints.featuredProductDetail(featuredItemId),
      );
      _featuredCache.clear();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Update display_order for a featured item.
  Future<void> updateFeaturedOrder(int featuredItemId, int newOrder) async {
    try {
      await _apiClient.dio.patch(
        ApiEndpoints.featuredProductDetail(featuredItemId),
        data: {'display_order': newOrder},
      );
      _featuredCache.clear();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Search products for adding to featured list.
  Future<List<ProductModel>> searchAllProducts(String query) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.products,
        queryParameters: {'search': query, 'page_size': 20},
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
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Fetch recent sales list — cached for 2 minutes per page.
  Future<List<SaleModel>> getSalesList({
    int pageSize = 50,
    int page = 1,
    String? dateFrom,
    String? dateTo,
    String? status,
    String? search,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'sales|$page|$pageSize|$dateFrom|$dateTo|$status|$search';
    if (!forceRefresh) {
      final cached = _salesCache.get(cacheKey);
      if (cached != null) return cached;
    }

    try {
      final params = <String, dynamic>{
        'ordering': '-created_at',
        'page_size': pageSize,
        'page': page,
      };
      if (dateFrom != null && dateFrom.isNotEmpty) {
        params['date_from'] = dateFrom;
      }
      if (dateTo != null && dateTo.isNotEmpty) {
        params['date_to'] = dateTo;
      }
      if (status != null && status.isNotEmpty) {
        params['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        params['search'] = search;
      }

      final response = await _apiClient.dio.get(
        ApiEndpoints.sales,
        queryParameters: params,
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
      final sales = results
          .map((e) => SaleModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _salesCache.set(cacheKey, sales);
      return sales;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Invalidate product-related caches (call after sale completes).
  void invalidateProductCache() {
    _searchCache.clear();
    _featuredCache.clear();
    _salesCache.clear();
  }
}
