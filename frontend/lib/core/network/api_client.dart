import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Thin wrapper around a configured [Dio] instance. Every repository takes
/// an [ApiClient] and calls [get]/[post]/etc., which map any [DioException]
/// to a typed [ApiException] (see api_exception.dart) so UI code never
/// touches Dio directly.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    required Future<void> Function() onSessionExpired,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 30),
          ),
        ) {
    dio.interceptors.add(AuthInterceptor(tokenStorage: tokenStorage, onSessionExpired: onSessionExpired));
    if (kDebugMode) {
      dio.interceptors.add(PrettyDioLogger(requestBody: true, responseBody: true, compact: true));
    }
  }

  final Dio dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) =>
      _run(() => dio.get<T>(path, queryParameters: queryParameters));

  Future<Response<T>> post<T>(String path, {Object? data, Map<String, dynamic>? queryParameters}) =>
      _run(() => dio.post<T>(path, data: data, queryParameters: queryParameters));

  Future<Response<T>> patch<T>(String path, {Object? data}) => _run(() => dio.patch<T>(path, data: data));

  Future<Response<T>> delete<T>(String path) => _run(() => dio.delete<T>(path));

  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) =>
      _run(() => dio.post<T>(path, data: formData, onSendProgress: onSendProgress, cancelToken: cancelToken));

  Future<Response<T>> _run<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw apiExceptionFromDioError(e);
    }
  }
}
