import 'package:dio/dio.dart';
import 'package:pos_terminal/core/network/auth_interceptor.dart';
import 'package:pos_terminal/features/auth/data/auth_local_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Creates and configures the Dio HTTP client for POS API calls.
class ApiClient {
  final Dio dio;

  ApiClient._({required this.dio});

  /// Factory that wires up the Dio instance with auth interceptor.
  /// [baseUrl] is the tenant server URL, e.g. `https://demo.digitex.uz`
  /// [authStorage] provides token read/write.
  /// [onAuthFailed] is called when refresh fails (forces re-login).
  factory ApiClient({
    required String baseUrl,
    required AuthLocalStorage authStorage,
    required Future<void> Function() onAuthFailed,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    final authInterceptor = AuthInterceptor(
      dio: dio,
      getAccessToken: () => authStorage.getAccessToken(),
      getRefreshToken: () => authStorage.getRefreshToken(),
      saveTokens: (access, refresh) =>
          authStorage.saveTokens(access: access, refresh: refresh),
      onAuthFailed: onAuthFailed,
    );

    dio.interceptors.addAll([
      authInterceptor,
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
      ),
    ]);

    return ApiClient._(dio: dio);
  }

  void updateBaseUrl(String baseUrl) {
    dio.options.baseUrl = baseUrl;
  }
}
