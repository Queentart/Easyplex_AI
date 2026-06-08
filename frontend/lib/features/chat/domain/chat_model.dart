/// Domain models for the live (WebSocket) chat feature.
///
/// Shapes mirror the backend exactly (see `backend/app/api/v1/chat.py`):
///   - `GET /chat/channels`               → `{id, name, type, cohort_id, class_id}`
///   - `POST /chat/channels`              → `{id, name, type, cohort_id, class_id}`
///   - `GET /chat/channels/{id}/messages` →
///         `{id, sender_id, sender_name, content, attachments, created_at}`
///   - `WS  /chat/ws` inbound frame       → `{"type":"message","data":{...message...}}`
///
/// `attachments` is `null` or `{"items":[ {file_key, file_name, content_type, ...} ]}`.
///
/// These are plain data classes — no business logic, no API calls.
library;

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

/// A live chat channel scoped to a cohort (and optionally a class).
class ChatChannel {
  const ChatChannel({
    required this.id,
    required this.name,
    required this.type,
    this.cohortId,
    this.classId,
  });

  final int id;
  final String name;

  /// Backend `type`: `cohort` / `class` / `free` (also legacy `class_live` /
  /// `custom` from older rows).
  final String type;
  final int? cohortId;
  final int? classId;

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      cohortId: _asInt(json['cohort_id']),
      classId: _asInt(json['class_id']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'cohort_id': cohortId,
        'class_id': classId,
      };
}

/// Selectable channel types offered in the "새 채팅방" dialog. The [code] is what
/// the backend `POST /chat/channels` `type` field expects.
enum ChatChannelType {
  cohort('cohort', '기수'),
  classRoom('class', '수업'),
  free('free', '자유');

  const ChatChannelType(this.code, this.label);

  final String code;
  final String label;
}

/// A single file attached to a chat message.
///
/// Mirrors one entry of the backend `attachments.items` array. Only the three
/// fields we send/render are modelled; any extra backend fields are ignored.
class ChatAttachment {
  const ChatAttachment({
    required this.fileKey,
    required this.fileName,
    required this.contentType,
  });

  final String fileKey;
  final String fileName;
  final String contentType;

  /// True when this attachment is a renderable image (inline preview), based on
  /// the declared content type.
  bool get isImage => contentType.toLowerCase().startsWith('image/');

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      fileKey: (json['file_key'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      contentType: (json['content_type'] ?? '').toString(),
    );
  }

  /// The wire shape sent to the backend over the WebSocket and when persisted.
  Map<String, dynamic> toJson() => {
        'file_key': fileKey,
        'file_name': fileName,
        'content_type': contentType,
      };

  /// Parses the backend `attachments` value (`null` or `{"items":[...]}`) into a
  /// flat list. Tolerates a bare list too, for forward compatibility.
  static List<ChatAttachment> parse(Object? raw) {
    List<dynamic>? items;
    if (raw is Map) {
      final inner = raw['items'];
      if (inner is List) items = inner;
    } else if (raw is List) {
      items = raw;
    }
    if (items == null) return const <ChatAttachment>[];
    return items
        .whereType<Map>()
        .map((e) =>
            ChatAttachment.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
        .toList();
  }
}

/// A single chat message.
///
/// [id] is negative for client-side optimistic messages that have not yet been
/// confirmed by the server (see [ChatMessage.optimistic]); once the server
/// echoes the message back over the socket the real row replaces it.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.attachments = const <ChatAttachment>[],
    this.pending = false,
  });

  final int id;
  final int senderId;

  /// Display name of the sender, used to label other people's messages. May be
  /// empty for legacy rows or optimistic placeholders.
  final String senderName;
  final String content;
  final DateTime createdAt;
  final List<ChatAttachment> attachments;

  /// True while an optimistic message is awaiting server confirmation.
  final bool pending;

  bool get isOptimistic => id < 0;
  bool get hasAttachments => attachments.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _asInt(json['id']) ?? 0,
      senderId: _asInt(json['sender_id']) ?? 0,
      senderName: (json['sender_name'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: _parseDate(json['created_at']),
      attachments: ChatAttachment.parse(json['attachments']),
    );
  }

  /// Builds a temporary, locally-rendered message for optimistic UI. Uses a
  /// negative [id] (derived from the wall clock) so it is unique and clearly
  /// distinguishable from server ids.
  factory ChatMessage.optimistic({
    required int senderId,
    required String content,
    List<ChatAttachment> attachments = const <ChatAttachment>[],
  }) {
    return ChatMessage(
      id: -DateTime.now().microsecondsSinceEpoch,
      senderId: senderId,
      senderName: '',
      content: content,
      createdAt: DateTime.now(),
      attachments: attachments,
      pending: true,
    );
  }

  ChatMessage copyWith({bool? pending}) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      content: content,
      createdAt: createdAt,
      attachments: attachments,
      pending: pending ?? this.pending,
    );
  }

  static DateTime _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }
}
