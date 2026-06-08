import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';

/// Thrown by [SettingsRepository] when a settings call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend error [code] for callers that want to branch on
/// it (e.g. surfacing a wrong-current-password message inline).
class SettingsException implements Exception {
  const SettingsException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Calls the settings-related `/auth/*` endpoints and parses the backend
/// response envelope.
///
/// This layer holds NO state and NO UI logic: it performs the request and
/// either returns normally or throws a [SettingsException] with a clean Korean
/// message. The 3-layer rule is respected — parsing of the envelope happens
/// here, but business/view logic lives in the presentation layer.
///
/// NOTE: Only endpoints that actually exist on the backend are called. As of
/// this writing the backend exposes `POST /auth/password/change`
/// (`{current_password, new_password}` → `{ok: true}`); there is no
/// notification/profile preferences endpoint, so this repository deliberately
/// does NOT expose one.
class SettingsRepository {
  SettingsRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  /// `POST /auth/password/change {current_password, new_password}`.
  ///
  /// Returns normally on success; throws a [SettingsException] (clean Korean
  /// message + backend [code]) on failure so the caller can surface it inline
  /// or via SnackBar.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/password/change',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      // The success body is `{data: {ok: true}, meta, error: null}`; we only
      // need to confirm the envelope did not carry an error.
      final envelope = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data ?? const {},
        (json) => (json as Map<String, dynamic>?) ?? const {},
      );
      if (!envelope.isSuccess) {
        throw SettingsException(
          envelope.error!.message,
          code: envelope.error!.code,
        );
      }
    } on DioException catch (e) {
      throw SettingsException(
        _messageFromDioException(e),
        code: _codeFromDioException(e),
      );
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

  String? _codeFromDioException(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final code = error['code'];
        if (code is String && code.isNotEmpty) return code;
      }
    }
    return null;
  }
}

/// Provides the [SettingsRepository] wired to the shared [dioProvider].
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(dioProvider)),
);
