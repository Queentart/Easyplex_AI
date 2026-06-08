/// Domain model for the notification feature.
///
/// Mirrors the backend `NotificationOut` schema
/// (see `backend/app/schemas/notification.py`). Holds NO business logic — only
/// JSON deserialization and small presentation-friendly accessors.
library;

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
bool _asBool(Object? v) => v is bool ? v : false;
String _asString(Object? v) => v?.toString() ?? '';

DateTime? _asDate(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// A single in-app notification (`NotificationOut`).
///
/// Note the backend names the message field `content` and the timestamp
/// `created_at`; the WS push and the REST list share this exact shape.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.type = '',
    this.linkUrl,
    this.relatedEntityType,
    this.relatedEntityId,
    this.isRead = false,
    this.createdAt,
  });

  final int id;
  final String title;

  /// Backend field `content` — the notification message body (nullable).
  final String? body;

  /// Free-form server category (e.g. `post_comment`, `assignment_due`).
  final String type;

  /// Optional in-app deep link target.
  final String? linkUrl;
  final String? relatedEntityType;
  final int? relatedEntityId;

  final bool isRead;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _asInt(json['id']) ?? 0,
      title: _asString(json['title']),
      // Backend uses `content` for the message body.
      body: json['content']?.toString(),
      type: _asString(json['type']),
      linkUrl: json['link_url']?.toString(),
      relatedEntityType: json['related_entity_type']?.toString(),
      relatedEntityId: _asInt(json['related_entity_id']),
      isRead: _asBool(json['is_read']),
      createdAt: _asDate(json['created_at']),
    );
  }

  AppNotification copyWith({
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      linkUrl: linkUrl,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
