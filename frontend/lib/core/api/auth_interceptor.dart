import 'package:dio/dio.dart';

import '../constants.dart' show apiBaseUrl;
import '../auth/auth_storage.dart';

/// Injects the bearer token and performs the 401 → refresh → retry-once flow.
///
/// Flow on a 401 from a protected request:
///   1. Read the refresh token from [AuthStorage].
///   2. POST `/auth/refresh` (using a separate, interceptor-free Dio so the
///      refresh call itself can't recurse).
///   3. On success: persist the new tokens and replay the original request once
///      with the fresh access token.
///   4. On failure (or missing refresh token): clear storage, invoke
///      [onAuthFailure], and surface the original error so the router can
///      redirect to /login.
///
/// A single in-flight refresh is shared so concurrent 401s don't each fire
/// their own refresh.
class AuthInterceptor extends QueuedInterceptor {
  // ignore_for_file: prefer_initializing_formals
  AuthInterceptor({
    required AuthStorage storage,
    required void Function() onAuthFailure,
  })  : _storage = storage,
        _onAuthFailure = onAuthFailure,
        _refreshDio = Dio(BaseOptions(baseUrl: apiBaseUrl));

  final AuthStorage _storage;
  final void Function() _onAuthFailure;
  final Dio _refreshDio;

  /// Header marker used to ensure a request is retried at most once.
  static const _retriedFlag = 'x-retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Never attach / refresh tokens for the auth endpoints themselves.
    if (!_isAuthEndpoint(options.path)) {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final request = err.requestOptions;

    final shouldAttemptRefresh = response?.statusCode == 401 &&
        !_isAuthEndpoint(request.path) &&
        request.headers[_retriedFlag] != true;

    if (!shouldAttemptRefresh) {
      return handler.next(err);
    }

    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _failAuth();
      return handler.next(err);
    }

    try {
      final refreshResponse = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = refreshResponse.data?['data'];
      if (data is! Map<String, dynamic>) {
        await _failAuth();
        return handler.next(err);
      }

      final newAccess = data['access_token']?.toString();
      final newRefresh = data['refresh_token']?.toString();
      if (newAccess == null || newAccess.isEmpty) {
        await _failAuth();
        return handler.next(err);
      }

      await _storage.saveTokens(
        accessToken: newAccess,
        refreshToken: (newRefresh != null && newRefresh.isNotEmpty)
            ? newRefresh
            : refreshToken,
      );

      // Replay the original request exactly once with the new token.
      final retryOptions = request
        ..headers['Authorization'] = 'Bearer $newAccess'
        ..headers[_retriedFlag] = true;

      final retryResponse = await _refreshDio.fetch<dynamic>(retryOptions);
      return handler.resolve(retryResponse);
    } on DioException {
      await _failAuth();
      return handler.next(err);
    }
  }

  Future<void> _failAuth() async {
    await _storage.clear();
    _onAuthFailure();
  }

  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/logout');
  }
}
