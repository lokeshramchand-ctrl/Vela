import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Attaches `X-Vela-API-Key` to every request and `Authorization: Bearer`
/// once a session exists. On a 401, attempts exactly one token refresh
/// (single-flight - concurrent 401s share the same refresh call) and
/// retries the original request; if refresh itself fails, clears the
/// session and calls [onSessionExpired] so the app can drop back to login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._tokenStorage,
    required this._onSessionExpired,
  })  : _refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))
          ..options.headers['X-Vela-API-Key'] = AppConfig.apiKey;

  final TokenStorage _tokenStorage;
  final Future<void> Function() _onSessionExpired;
  final Dio _refreshDio;

  Completer<bool>? _refreshInFlight;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers['X-Vela-API-Key'] = AppConfig.apiKey;
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final alreadyRetried = err.requestOptions.extra['Vela_retried'] == true;

    final isAuthEndpoint = err.requestOptions.path.startsWith('/auth/');
    if (response?.statusCode != 401 || alreadyRetried || isAuthEndpoint) {
      handler.next(err);
      return;
    }

    final refreshed = await _refreshTokens();
    if (!refreshed) {
      await _tokenStorage.clear();
      await _onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      final retryOptions = err.requestOptions;
      retryOptions.extra['Vela_retried'] = true;
      final accessToken = await _tokenStorage.readAccessToken();
      retryOptions.headers['Authorization'] = 'Bearer $accessToken';
      final response = await _refreshDio.fetch(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Single-flight refresh: if a refresh is already underway, every caller
  /// awaits the same result instead of racing the rotating refresh token
  /// (the backend revokes it after first use).
  Future<bool> _refreshTokens() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshInFlight = completer;
    _doRefresh().then(completer.complete).catchError((_) => completer.complete(false)).whenComplete(() {
      _refreshInFlight = null;
    });
    return completer.future;
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _refreshDio.post('/auth/refresh', data: {'refresh_token': refreshToken});
      final data = response.data as Map<String, dynamic>;
      await _tokenStorage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }
}
