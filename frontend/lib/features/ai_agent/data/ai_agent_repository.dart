import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/ai_agent_model.dart';

/// Thrown by [AiAgentRepository] when an AI Agent call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend error [code] / HTTP [statusCode] so callers can
/// branch (e.g. surface a rate-limit notice on 429, a permission notice on 403).
class AiAgentException implements Exception {
  const AiAgentException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  bool get isRateLimited => statusCode == 429;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

/// Calls the `/ai-agent/*` endpoints. Holds NO state and NO UI logic.
///
/// Backend (`app/api/v1/ai_agent.py`):
///   - `POST /ai-agent/query`        → enveloped [AiQueryResult]
///   - `POST /ai-agent/query/stream` → SSE `text/event-stream` (token deltas)
///   - `GET  /ai-agent/history`      → enveloped + paginated query log
///   - `GET  /ai-agent/tools`        → enveloped `List<AiTool>`
class AiAgentRepository {
  AiAgentRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';
  static const _rateLimitMessage = '요청이 너무 많습니다. 잠시 후 다시 시도해주세요. (분당 5회 제한)';
  static const _forbiddenMessage = '접근 권한이 없습니다.';

  /// `POST /ai-agent/query {query, session_id, stream:false}` → [AiQueryResult].
  ///
  /// Non-streaming variant; used as a fallback when streaming is unavailable.
  Future<AiQueryResult> query(String prompt, {String? sessionId}) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai-agent/query',
        data: {'query': prompt, 'session_id': sessionId, 'stream': false},
      );
      final envelope = ApiResponse<AiQueryResult>.fromJson(
        response.data ?? const {},
        (json) => AiQueryResult.fromJson(json as Map<String, dynamic>),
      );
      if (!envelope.isSuccess) {
        throw AiAgentException(
          envelope.error!.message,
          code: envelope.error!.code,
        );
      }
      return envelope.data ?? const AiQueryResult(answer: '');
    });
  }

  /// `POST /ai-agent/query/stream {query, session_id, stream:true}` → a
  /// `Stream<String>` of token deltas (the text fragments to append live).
  ///
  /// The backend emits Server-Sent Events with this exact chunk format:
  /// ```
  /// event: token
  /// data: {"text": "단어 "}
  ///
  /// event: done
  /// data: {"tools_used": []}
  /// ```
  /// We open the response with [ResponseType.stream], decode the byte stream to
  /// UTF-8, buffer across chunk boundaries, and split on the blank-line event
  /// delimiter. For each `token` event we yield the `data.text` fragment; the
  /// `done` event ends the stream. Errors are converted to [AiAgentException].
  Stream<String> queryStream(String prompt, {String? sessionId}) async* {
    final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        '/ai-agent/query/stream',
        data: {'query': prompt, 'session_id': sessionId, 'stream': true},
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'Accept': 'text/event-stream'},
        ),
      );
    } on DioException catch (e) {
      throw _fromDioException(e);
    }

    final body = response.data;
    if (body == null) {
      throw const AiAgentException(_fallbackMessage);
    }

    // SSE events are separated by a blank line. Buffer raw text across network
    // chunks since an event may be split across TCP packets.
    var buffer = '';
    try {
      await for (final chunk in body.stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);

        var delimiter = buffer.indexOf('\n\n');
        while (delimiter != -1) {
          final rawEvent = buffer.substring(0, delimiter);
          buffer = buffer.substring(delimiter + 2);

          final parsed = _parseEvent(rawEvent);
          if (parsed == null) {
            delimiter = buffer.indexOf('\n\n');
            continue;
          }
          if (parsed.event == 'done') return;
          if (parsed.event == 'token' && parsed.text != null) {
            yield parsed.text!;
          }
          delimiter = buffer.indexOf('\n\n');
        }
      }

      // Flush a trailing event with no terminating blank line.
      final tail = _parseEvent(buffer);
      if (tail != null && tail.event == 'token' && tail.text != null) {
        yield tail.text!;
      }
    } on DioException catch (e) {
      throw _fromDioException(e);
    }
  }

  /// `GET /ai-agent/tools` → the whitelisted query tools (role-filtered server
  /// side). Surfaced as sample-prompt hints in the UI.
  Future<List<AiTool>> tools() async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/ai-agent/tools');
      final envelope = ApiResponse<List<AiTool>>.fromJson(
        response.data ?? const {},
        (json) => (json as List)
            .whereType<Map<String, dynamic>>()
            .map(AiTool.fromJson)
            .toList(),
      );
      if (!envelope.isSuccess) {
        throw AiAgentException(
          envelope.error!.message,
          code: envelope.error!.code,
        );
      }
      return envelope.data ?? const [];
    });
  }

  /// `GET /ai-agent/history` → past queries (paginated). Returns the raw rows
  /// (`{id, query_text, status, latency_ms, created_at}`) since the transcript
  /// UI does not yet render history detail.
  Future<List<Map<String, dynamic>>> history({
    int page = 1,
    int size = 20,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/ai-agent/history',
        queryParameters: {'page': page, 'size': size},
      );
      final data = response.data?['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
      return const <Map<String, dynamic>>[];
    });
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Parsed single SSE event (`event:` line + `data:` JSON line).
  static _SseEvent? _parseEvent(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    String? event;
    final dataLines = <String>[];
    for (final line in const LineSplitter().convert(trimmed)) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }
    if (event == null) return null;

    String? text;
    final dataRaw = dataLines.join('\n');
    if (dataRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(dataRaw);
        if (decoded is Map && decoded['text'] != null) {
          text = decoded['text'].toString();
        }
      } catch (_) {
        // Non-JSON data line — ignore (token events always carry JSON).
      }
    }
    return _SseEvent(event: event, text: text);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AiAgentException {
      rethrow;
    } on DioException catch (e) {
      throw _fromDioException(e);
    }
  }

  AiAgentException _fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const AiAgentException(_networkMessage);
      default:
        break;
    }

    final status = e.response?.statusCode;
    if (status == 429) {
      return const AiAgentException(_rateLimitMessage, statusCode: 429);
    }
    if (status == 403) {
      return const AiAgentException(_forbiddenMessage, statusCode: 403);
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) {
          return AiAgentException(
            message,
            code: error['code']?.toString(),
            statusCode: status,
          );
        }
      }
    }
    return AiAgentException(_fallbackMessage, statusCode: status);
  }
}

/// Internal: a decoded SSE event.
class _SseEvent {
  const _SseEvent({required this.event, this.text});

  final String event;
  final String? text;
}

/// Provides the [AiAgentRepository] wired to the shared [dioProvider].
final aiAgentRepositoryProvider = Provider<AiAgentRepository>(
  (ref) => AiAgentRepository(ref.watch(dioProvider)),
);
