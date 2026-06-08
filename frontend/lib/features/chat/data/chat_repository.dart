import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/api/api_response.dart';
import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../domain/chat_model.dart';

/// Thrown by [ChatRepository] when a REST chat call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend [code] for callers that branch on it.
class ChatException implements Exception {
  const ChatException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Talks to the `/chat` endpoints and opens the chat WebSocket.
///
/// REST methods parse the standard backend envelope and return domain models
/// (or throw [ChatException]). The socket helper is intentionally thin: it just
/// builds the authenticated `ws://` URL and connects — frame parsing lives in
/// the provider.
///
/// This layer holds NO state and NO UI logic.
class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  // ── Channels ──────────────────────────────────────────────────────────

  /// `GET /chat/channels` → live chat channels visible to the caller. The
  /// backend scopes by the caller's cohort; [cohortId] optionally overrides it.
  Future<List<ChatChannel>> listChannels({int? cohortId}) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/chat/channels',
        queryParameters: {'cohort_id': ?cohortId},
      );
      final envelope = ApiResponse<List<ChatChannel>>.fromJson(
        response.data ?? const {},
        _parseChannelList,
      );
      return _unwrap(envelope) ?? const <ChatChannel>[];
    });
  }

  /// `POST /chat/channels` → creates a new channel and returns it. Allowed for
  /// admin_ops & instructor (the backend enforces RBAC; a 403 surfaces as a
  /// [ChatException] carrying "접근 권한이 없습니다.").
  ///
  /// [type] is one of `cohort` / `class` / `free`. [classId] is only meaningful
  /// for class channels and is omitted from the body when null.
  Future<ChatChannel> createChannel({
    required String name,
    required String type,
    required int cohortId,
    int? classId,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/chat/channels',
        data: {
          'name': name,
          'type': type,
          'cohort_id': cohortId,
          'class_id': ?classId,
        },
      );
      final envelope = ApiResponse<ChatChannel>.fromJson(
        response.data ?? const {},
        (json) => ChatChannel.fromJson(
            (json as Map).map((k, v) => MapEntry(k.toString(), v))),
      );
      final channel = _unwrap(envelope);
      if (channel == null) throw const ChatException(_fallbackMessage);
      return channel;
    });
  }

  // ── Message history ─────────────────────────────────────────────────────

  /// `GET /chat/channels/{id}/messages` → past messages in creation order
  /// (oldest first), so they append directly to the bottom-anchored list.
  Future<List<ChatMessage>> listMessages(
    int channelId, {
    int page = 1,
    int size = 50,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/chat/channels/$channelId/messages',
        queryParameters: {'page': page, 'size': size},
      );
      final envelope = ApiResponse<List<ChatMessage>>.fromJson(
        response.data ?? const {},
        _parseMessageList,
      );
      return _unwrap(envelope) ?? const <ChatMessage>[];
    });
  }

  // ── File attachments (presign → PUT → view URL) ─────────────────────────

  /// Uploads [bytes] as a chat attachment and returns the persisted
  /// `{file_key, file_name, content_type}` descriptor ready to attach to a
  /// message. Three steps:
  ///   1. `POST /files/presign` (purpose `chat_attachment`) → presigned PUT URL,
  ///   2. PUT the raw bytes to that URL with the matching `Content-Type`,
  ///   3. return the descriptor (the backend keyed the object by `file_key`).
  ///
  /// The PUT goes to object storage directly (an absolute URL), so it uses a
  /// bare [Dio] without our API base URL / auth interceptor.
  Future<ChatAttachment> uploadAttachment({
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    return _guard(() async {
      // 1. Presign.
      final presignRes = await _dio.post<Map<String, dynamic>>(
        '/files/presign',
        data: {
          'purpose': 'chat_attachment',
          'context': <String, dynamic>{},
          'file_name': fileName,
          'content_type': contentType,
        },
      );
      final presignData = (presignRes.data ?? const {})['data'];
      if (presignData is! Map) throw const ChatException(_fallbackMessage);
      final uploadUrl = (presignData['upload_url'] ?? '').toString();
      final fileKey = (presignData['file_key'] ?? '').toString();
      if (uploadUrl.isEmpty || fileKey.isEmpty) {
        throw const ChatException(_fallbackMessage);
      }

      // 2. PUT bytes to object storage. Must echo the Content-Type the URL was
      // signed with. Uses a separate Dio so the API base URL / auth header are
      // not applied to the storage endpoint.
      await Dio().put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': bytes.length,
          },
          contentType: contentType,
        ),
      );

      // 3. Descriptor to attach to the outgoing message.
      return ChatAttachment(
        fileKey: fileKey,
        fileName: fileName,
        contentType: contentType,
      );
    });
  }

  /// `POST /files/download-url` → a short-lived presigned GET URL for viewing /
  /// downloading the stored object identified by [fileKey] (used to render
  /// image attachments inline and to open file attachments).
  Future<String> getDownloadUrl(String fileKey) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/files/download-url',
        data: {'file_key': fileKey},
      );
      final data = (response.data ?? const {})['data'];
      if (data is Map) {
        final url = (data['url'] ?? '').toString();
        if (url.isNotEmpty) return url;
      }
      throw const ChatException(_fallbackMessage);
    });
  }

  // ── WebSocket ─────────────────────────────────────────────────────────

  /// Opens the chat WebSocket for [channelId], authenticating with [accessToken].
  ///
  /// Builds the URL from [apiBaseUrl] by swapping the HTTP scheme for the WS
  /// scheme (`http`→`ws`, `https`→`wss`) and appending `/chat/ws`, then carries
  /// the JWT + channel id as query parameters — matching the backend signature
  /// `@router.websocket("/ws")  (token, channel_id)`.
  ///
  /// The caller owns the returned channel and MUST close its sink when done.
  WebSocketChannel connect({
    required int channelId,
    required String accessToken,
  }) {
    return WebSocketChannel.connect(
      buildWsUri(channelId: channelId, accessToken: accessToken),
    );
  }

  /// Exposed for testing / debugging: the exact `ws(s)://…/chat/ws` URI used by
  /// [connect].
  static Uri buildWsUri({
    required int channelId,
    required String accessToken,
  }) {
    final base = Uri.parse(apiBaseUrl); // e.g. http://localhost:8000/api/v1
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: wsScheme,
      path: '${base.path}/chat/ws',
      queryParameters: {
        'token': accessToken,
        'channel_id': channelId.toString(),
      },
    );
  }

  // ── Envelope / error plumbing ───────────────────────────────────────────

  static List<ChatChannel> _parseChannelList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) =>
          ChatChannel.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static List<ChatMessage> _parseMessageList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) =>
          ChatMessage.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  /// Returns [ApiResponse.data] (may be null for empty payloads) or throws a
  /// [ChatException] when the envelope carries an error.
  T? _unwrap<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      throw ChatException(response.error!.message, code: response.error!.code);
    }
    return response.data;
  }

  /// Runs [action], converting a [DioException] into a [ChatException] whose
  /// message is taken from the backend error envelope when present.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ChatException(
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

/// Provides the [ChatRepository] wired to the shared [dioProvider].
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(dioProvider)),
);
