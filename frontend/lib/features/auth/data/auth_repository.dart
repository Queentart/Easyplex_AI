import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../../../shared/models/user.dart';
import '../domain/auth_model.dart';

/// Thrown by [AuthRepository] when an auth call fails. Carries a user-facing
/// (Korean) [message] already extracted from the backend error envelope, plus
/// the backend error [code] for callers that want to branch on it.
class AuthException implements Exception {
  const AuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Calls the `/auth/*` endpoints and parses the backend response envelope.
///
/// This layer holds NO state and NO UI logic: it returns parsed DTOs
/// ([TokenPair] / [AppUser]) or throws an [AuthException] with a clean message.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  /// `POST /auth/login {email, password}` → [TokenPair].
  Future<TokenPair> login(String email, String password) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: LoginRequest(email: email, password: password).toJson(),
      );
      final envelope = ApiResponse<TokenPair>.fromJson(
        response.data ?? const {},
        (json) => TokenPair.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `POST /auth/refresh {refresh_token}` → [TokenPair] (rotated tokens).
  Future<TokenPair> refresh(String refreshToken) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final envelope = ApiResponse<TokenPair>.fromJson(
        response.data ?? const {},
        (json) => TokenPair.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `POST /auth/logout {refresh_token}`. Best-effort: server-side token
  /// revocation. Never throws — local cleanup must proceed regardless.
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    } on DioException {
      // Ignore: logging out locally is what matters; the refresh token will
      // expire server-side anyway.
    }
  }

  /// `GET /auth/me` → the fresh [AppUser]. Used on session restore to validate
  /// the cached access token and refresh the cached user.
  Future<AppUser> me() async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final envelope = ApiResponse<AppUser>.fromJson(
        response.data ?? const {},
        (json) => AppUser.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// Returns [ApiResponse.data] or throws an [AuthException] when the envelope
  /// carries an error or an empty `data` payload.
  T _unwrap<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      throw AuthException(
        response.error!.message,
        code: response.error!.code,
      );
    }
    final data = response.data;
    if (data == null) {
      throw const AuthException(_fallbackMessage);
    }
    return data;
  }

  /// Runs [action], converting a [DioException] into an [AuthException] whose
  /// message is taken from the backend error envelope when present.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw AuthException(_messageFromDioException(e));
    }
  }

  String _messageFromDioException(DioException e) {
    // Connection / timeout failures never reach the server.
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return _networkMessage;
      default:
        break;
    }

    // Pull the message out of the `{data, meta, error:{code, message}}`
    // envelope returned by the backend exception handlers.
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    }
    return _fallbackMessage;
  }
}

/// Provides the [AuthRepository] wired to the shared [dioProvider].
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
