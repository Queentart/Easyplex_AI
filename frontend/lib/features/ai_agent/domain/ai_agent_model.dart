/// Domain models for the AI Agent co-pilot feature.
///
/// These are plain Dart data classes (no business logic, no API calls). They
/// mirror the backend payloads from `app/api/v1/ai_agent.py`:
///   - `POST /ai-agent/query`        → [AiQueryResult]
///   - `POST /ai-agent/query/stream` → SSE token deltas (parsed in the repo)
///   - `GET  /ai-agent/tools`        → `List<AiTool>`
library;

/// Author of a chat message in the transcript.
enum AiMessageRole { user, agent }

/// A single message rendered in the co-pilot transcript.
///
/// For agent messages [streaming] is true while SSE deltas are still being
/// appended to [content]; it flips to false on the `done` event or on error.
class AiMessage {
  const AiMessage({
    required this.role,
    required this.content,
    this.streaming = false,
    this.isError = false,
    this.toolsUsed = const [],
  });

  final AiMessageRole role;
  final String content;

  /// True while the agent response is still streaming in.
  final bool streaming;

  /// True when this (agent) message carries an error notice (e.g. 429/403).
  final bool isError;

  /// Tool names the agent invoked, surfaced once streaming completes.
  final List<String> toolsUsed;

  bool get isUser => role == AiMessageRole.user;

  AiMessage copyWith({
    AiMessageRole? role,
    String? content,
    bool? streaming,
    bool? isError,
    List<String>? toolsUsed,
  }) {
    return AiMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      streaming: streaming ?? this.streaming,
      isError: isError ?? this.isError,
      toolsUsed: toolsUsed ?? this.toolsUsed,
    );
  }

  factory AiMessage.user(String content) =>
      AiMessage(role: AiMessageRole.user, content: content);

  factory AiMessage.agent(String content, {bool streaming = false}) =>
      AiMessage(
        role: AiMessageRole.agent,
        content: content,
        streaming: streaming,
      );
}

/// Result of a non-streaming `POST /ai-agent/query` call.
///
/// Envelope `data` shape (see `AiQueryResponse`):
/// `{answer, tools_used: [], references: [], session_id, latency_ms}`.
class AiQueryResult {
  const AiQueryResult({
    required this.answer,
    this.toolsUsed = const [],
    this.references = const [],
    this.sessionId,
    this.latencyMs = 0,
  });

  final String answer;
  final List<String> toolsUsed;
  final List<Map<String, dynamic>> references;
  final String? sessionId;
  final int latencyMs;

  factory AiQueryResult.fromJson(Map<String, dynamic> json) {
    return AiQueryResult(
      answer: (json['answer'] ?? '').toString(),
      toolsUsed: _toolNames(json['tools_used']),
      references: (json['references'] is List)
          ? (json['references'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
          : const [],
      sessionId: json['session_id']?.toString(),
      latencyMs: json['latency_ms'] is num
          ? (json['latency_ms'] as num).toInt()
          : 0,
    );
  }
}

/// A whitelisted query tool from `GET /ai-agent/tools`.
///
/// `data` is a list of `{name, description}` objects.
class AiTool {
  const AiTool({required this.name, required this.description});

  final String name;
  final String description;

  factory AiTool.fromJson(Map<String, dynamic> json) {
    return AiTool(
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

/// Extracts tool names from the backend `tools_used` field, which may be a
/// list of strings or a list of `{name, ...}` objects.
List<String> _toolNames(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) {
        if (e is String) return e;
        if (e is Map && e['name'] != null) return e['name'].toString();
        return '';
      })
      .where((s) => s.isNotEmpty)
      .toList();
}
