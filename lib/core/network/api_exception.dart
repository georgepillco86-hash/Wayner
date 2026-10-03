enum ApiErrorType {
  network,
  timeout,
  http,
  notFound,
  server,
  invalidResponse,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final String technicalMessage;
  final int? statusCode;
  final ApiErrorType type;

  const ApiException(
    this.message, {
    this.technicalMessage = '',
    this.statusCode,
    this.type = ApiErrorType.unknown,
  });

  bool get canRetry =>
      type == ApiErrorType.network ||
      type == ApiErrorType.timeout ||
      type == ApiErrorType.server;

  @override
  String toString() => message;
}
