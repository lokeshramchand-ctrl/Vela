import 'package:dio/dio.dart';

/// Typed errors mirroring docs/API_REFERENCE.md §0.
///
/// Three response shapes exist on the wire:
///  - the standard envelope: `{"error": {"detail", "request_id", "errors"?}}`
///  - the body-size-limit fast path: `{"error": "payload_too_large", "detail": "..."}`
///  - the rate-limit shape: `{"error": "Rate limit exceeded: ..."}`
sealed class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int? statusCode;
  final String message;

  @override
  String toString() => message;
}

/// A structured error from the standard envelope (401/403/404/409/422/500...).
final class ApiHttpException extends ApiException {
  const ApiHttpException({
    required int statusCode,
    required String detail,
    this.requestId,
    this.validationErrors,
  }) : super(statusCode, detail);

  final String? requestId;
  final List<ApiValidationError>? validationErrors;
}

final class ApiValidationError {
  const ApiValidationError({required this.loc, required this.msg, required this.type});
  final List<String> loc;
  final String msg;
  final String type;

  factory ApiValidationError.fromJson(Map<String, dynamic> json) => ApiValidationError(
        loc: (json['loc'] as List? ?? const []).map((e) => e.toString()).toList(),
        msg: json['msg']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
      );
}

/// 413 fast-path: `Content-Length` exceeded `MAX_REQUEST_BODY_BYTES` before
/// the request body was even read.
final class ApiPayloadTooLargeException extends ApiException {
  const ApiPayloadTooLargeException(String message) : super(413, message);
}

/// 429: `core/rate_limiter.py` (slowapi default handler).
final class ApiRateLimitException extends ApiException {
  const ApiRateLimitException(String message, {this.retryAfterSeconds}) : super(429, message);
  final int? retryAfterSeconds;
}

/// No response reached the server at all (offline, timeout, DNS, TLS...).
final class ApiNetworkException extends ApiException {
  const ApiNetworkException(String message) : super(null, message);
}

/// Refresh token was invalid, expired, or reused (theft response - the
/// backend revokes ALL sessions server-side on reuse). Callers must force a
/// full re-login, not retry.
final class ApiSessionExpiredException extends ApiException {
  const ApiSessionExpiredException([String message = 'Your session has expired. Please sign in again.'])
      : super(401, message);
}

ApiException apiExceptionFromDioError(DioException error) {
  final response = error.response;
  if (response == null) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ApiNetworkException('The request timed out. Check your connection and try again.');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const ApiNetworkException("Couldn't reach Vela. Check your connection and try again.");
    }
    return ApiNetworkException(error.message ?? 'Something went wrong.');
  }

  final status = response.statusCode ?? 0;
  final data = response.data;

  if (status == 413) {
    final detail = data is Map ? data['detail']?.toString() : null;
    return ApiPayloadTooLargeException(detail ?? 'This file is too large.');
  }

  if (status == 429) {
    final retryAfter = response.headers.value('Retry-After');
    final rawError = data is Map ? data['error']?.toString() : null;
    return ApiRateLimitException(
      rawError ?? "You're doing that too often. Try again shortly.",
      retryAfterSeconds: retryAfter == null ? null : int.tryParse(retryAfter),
    );
  }

  if (data is Map && data['error'] is Map) {
    final envelope = data['error'] as Map;
    final rawErrors = envelope['errors'];
    return ApiHttpException(
      statusCode: status,
      detail: envelope['detail']?.toString() ?? 'Something went wrong.',
      requestId: envelope['request_id']?.toString(),
      validationErrors: rawErrors is List
          ? rawErrors.whereType<Map<String, dynamic>>().map(ApiValidationError.fromJson).toList()
          : null,
    );
  }

  return ApiHttpException(statusCode: status, detail: 'Something went wrong. (HTTP $status)');
}
