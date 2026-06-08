import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/api/api_response.dart';
import '../../../core/auth/auth_storage.dart';
import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../domain/notification_model.dart';

/// Thrown by [NotificationRepository] when a call fails. Carries a user-facing
/// (Korean) [message] already extracted from the backend error envelope, plus
/// the backend error [code] for callers that branch on it.
class NotificationException implements Exception {
  const NotificationException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// A page of notifications plus the server-reported unread count.
class NotificationPage {
  const NotificationPage({
    required this.notifications,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
}

/// Calls the `/notifications` REST endpoints and opens the realtime WS.
///
/// This layer holds NO state and NO UI logic: it returns parsed domain models
/// or throws a [NotificationException] with a clean message.
class NotificationRepository {
  NotificationRepository(this._dio, this._storage);

  final Dio _dio;
  final AuthStorage _storage;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  // ── REST ──────────────────────────────────────────────────────────────

  /// `GET /notifications` → a page of notifications (newest first) plus the
  /// unread count carried in the envelope `meta`.
  Future<NotificationPage> listNotifications({
    bool? isRead,
    int page = 1,
    int size = 20,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/notifications/',
        queryParameters: {
          'is_read': ?isRead,
          'page': page,
          'size': size,
        },
      );
      final raw = response.data ?? const {};
      final envelope = ApiResponse<List<AppNotification>>.fromJson(
        raw,
        _parseNotificationList,
      );
      final notifications = _unwrap(envelope) ?? const <AppNotification>[];
      // `unread_count` is a custom meta field, not modeled by ApiMeta.
      final meta = raw['meta'];
      final unread = meta is Map<String, dynamic>
          ? (meta['unread_count'] is num
              ? (meta['unread_count'] as num).toInt()
              : notifications.where((n) => !n.isRead).length)
          : notifications.where((n) => !n.isRead).length;
      return NotificationPage(notifications: notifications, unreadCount: unread);
    });
  }

  /// `POST /notifications/{id}/read` → marks a single notification read.
  Future<void> markRead(int notificationId) async {
    return _guard(() async {
      await _dio.post<Map<String, dynamic>>('/notifications/$notificationId/read');
    });
  }

  /// `POST /notifications/read-all` → marks every unread notification read.
  Future<void> markAllRead() async {
    return _guard(() async {
      await _dio.post<Map<String, dynamic>>('/notifications/read-all');
    });
  }

  // ── WebSocket ───────────────────────────────────────────────────────────

  /// Opens the realtime notification WebSocket and returns the live channel.
  ///
  /// The access token is passed as a query parameter (the backend decodes it
  /// in the `/ws` handler). Returns null when no token is available so the
  /// caller can simply skip realtime updates rather than crash. The caller
  /// owns the channel lifecycle (listen + close).
  Future<WebSocketChannel?> connect() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) return null;

    // Derive the ws(s):// URL from the configured http(s):// API base.
    final wsBase = apiBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final uri = Uri.parse('$wsBase/notifications/ws?token=$token');
    return WebSocketChannel.connect(uri);
  }

  /// Parses a raw WS frame payload into an [AppNotification], or null when the
  /// frame is not a `{"type": "notification", "data": {...}}` push (e.g. a
  /// keepalive). Never throws — realtime frames must not crash the stream.
  static AppNotification? parseWsMessage(Object? raw) {
    try {
      if (raw is! String || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if (decoded['type'] != 'notification') return null;
      final data = decoded['data'];
      if (data is! Map) return null;
      return AppNotification.fromJson(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Envelope / error plumbing ───────────────────────────────────────────

  static List<AppNotification> _parseNotificationList(Object? json) =>
      (json as List)
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList();

  T? _unwrap<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      throw NotificationException(
        response.error!.message,
        code: response.error!.code,
      );
    }
    return response.data;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw NotificationException(
        _messageFromDioException(e),
        code: _codeFromDioException(e),
      );
    }
  }

  String _messageFromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return _networkMessage;
      default:
        break;
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    }
    final status = e.response?.statusCode;
    if (status == 403) return '접근 권한이 없습니다.';
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

/// Provides the [NotificationRepository] wired to the shared [dioProvider] and
/// [authStorageProvider] (for the WS access token).
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(
    ref.watch(dioProvider),
    ref.watch(authStorageProvider),
  ),
);
