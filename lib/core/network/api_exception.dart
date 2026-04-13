/// Typed API exceptions for consistent error handling.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({required this.message, this.statusCode, this.data});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({String message = 'Unauthorized'})
    : super(message: message, statusCode: 401);
}

class ForbiddenException extends ApiException {
  const ForbiddenException({String message = 'Forbidden'})
    : super(message: message, statusCode: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException({String message = 'Not found'})
    : super(message: message, statusCode: 404);
}

class ServerException extends ApiException {
  const ServerException({String message = 'Server error'})
    : super(message: message, statusCode: 500);
}

class NetworkException extends ApiException {
  const NetworkException({String message = 'Network error'})
    : super(message: message);
}
