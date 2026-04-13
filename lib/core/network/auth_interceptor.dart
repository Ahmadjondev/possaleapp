import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:pos_terminal/core/network/api_exception.dart';

/// Dio interceptor that attaches JWT access token and auto-refreshes on 401.
class AuthInterceptor extends Interceptor {
  final Future<String?> Function() getAccessToken;
  final Future<String?> Function() getRefreshToken;
  final Future<void> Function(String access, String refresh) saveTokens;
  final Future<void> Function() onAuthFailed;
  final Dio _dio;

  bool _isRefreshing = false;

  AuthInterceptor({
    required Dio dio,
    required this.getAccessToken,
    required this.getRefreshToken,
    required this.saveTokens,
    required this.onAuthFailed,
  }) : _dio = dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await getRefreshToken();
        if (refreshToken == null) {
          await onAuthFailed();
          return handler.next(err);
        }

        // Attempt token refresh — use a separate Dio to avoid interceptor loop
        final refreshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
        final response = await refreshDio.post(
          '/api/auth/token/refresh/',
          data: {'refresh': refreshToken},
        );

        final newAccess = response.data['access'] as String;
        final newRefresh =
            (response.data['refresh'] as String?) ?? refreshToken;
        await saveTokens(newAccess, newRefresh);

        // Retry original request with new token
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccess';
        final retryResponse = await _dio.fetch(opts);
        return handler.resolve(retryResponse);
      } on DioException catch (e) {
        log('Token refresh failed: ${e.message}');
        await onAuthFailed();
        return handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    }

    handler.next(err);
  }
}

/// Maps Dio errors to typed [ApiException]s.
ApiException mapDioException(DioException e) {
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    return const NetworkException(message: 'Could not connect to server');
  }

  final statusCode = e.response?.statusCode;
  final data = e.response?.data;
  final message = data is Map
      ? (data['detail'] ?? data['message'] ?? e.message)
      : e.message;

  final code = statusCode ?? 0;
  switch (code) {
    case 401:
      return UnauthorizedException(message: message ?? 'Unauthorized');
    case 403:
      return ForbiddenException(message: message ?? 'Forbidden');
    case 404:
      return NotFoundException(message: message ?? 'Not found');
    case >= 500:
      return ServerException(message: message ?? 'Server error');
    default:
      return ApiException(
        message: message ?? 'Unknown error',
        statusCode: code,
        data: data,
      );
  }
}
