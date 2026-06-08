/// Domain models for the board / community feature.
///
/// These mirror the backend `BoardOut` / `PostOut` / `CommentOut` schemas
/// (see `backend/app/schemas/board.py`). They hold NO business logic — only
/// JSON (de)serialization and small presentation-friendly accessors.
library;

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
bool _asBool(Object? v) => v is bool ? v : false;
String _asString(Object? v) => v?.toString() ?? '';

DateTime? _asDate(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// A board / category (`BoardOut`). `type` is a free-form string from the
/// server (e.g. `notice`, `free`, `qna`). The post-list screen groups its tabs
/// by board, so [name] is the user-facing label.
class Board {
  const Board({
    required this.id,
    required this.name,
    required this.type,
    this.cohortId,
    this.description,
    this.allowAnonymous = false,
    this.allowPrivatePost = false,
    this.visibility = 'cohort',
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String type;
  final int? cohortId;
  final String? description;

  /// When false, the write screen must hide the anonymous toggle.
  final bool allowAnonymous;

  /// When false, the write screen must hide the private-post toggle.
  final bool allowPrivatePost;
  final String visibility;
  final int sortOrder;

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['name']),
      type: _asString(json['type']),
      cohortId: _asInt(json['cohort_id']),
      description: json['description']?.toString(),
      allowAnonymous: _asBool(json['allow_anonymous']),
      allowPrivatePost: _asBool(json['allow_private_post']),
      visibility: _asString(json['visibility']).isEmpty
          ? 'cohort'
          : _asString(json['visibility']),
      sortOrder: _asInt(json['sort_order']) ?? 0,
    );
  }
}

/// A single attachment descriptor stored on a post.
///
/// The backend stores `attachments` as a free-form `list[dict]`; this feature
/// uses the `{file_key, file_name, content_type, size}` shape produced by the
/// `/files/presign` flow. Unknown keys are ignored, missing keys tolerated.
class PostAttachment {
  const PostAttachment({
    required this.fileKey,
    required this.fileName,
    this.contentType,
    this.size,
  });

  final String fileKey;
  final String fileName;
  final String? contentType;
  final int? size;

  factory PostAttachment.fromJson(Map<String, dynamic> json) {
    return PostAttachment(
      fileKey: _asString(json['file_key']),
      fileName: _asString(json['file_name']).isEmpty
          ? _asString(json['file_key'])
          : _asString(json['file_name']),
      contentType: json['content_type']?.toString(),
      size: _asInt(json['size']),
    );
  }

  Map<String, dynamic> toJson() => {
        'file_key': fileKey,
        'file_name': fileName,
        if (contentType != null) 'content_type': contentType,
        if (size != null) 'size': size,
      };
}

/// A post (`PostOut`).
///
/// Anonymity rule: when [isAnonymous] is true the UI must render the author as
/// `'익명'` and never surface [authorId] (the server still returns it so that
/// operations staff can de-anonymize via a separate audited endpoint).
class Post {
  const Post({
    required this.id,
    required this.boardId,
    required this.authorId,
    required this.title,
    required this.content,
    required this.isAnonymous,
    required this.isPrivate,
    required this.isPinned,
    required this.viewCount,
    required this.attachments,
    required this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int boardId;
  final int authorId;
  final String title;
  final String content;
  final bool isAnonymous;
  final bool isPrivate;
  final bool isPinned;
  final int viewCount;
  final List<PostAttachment> attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// True when [viewerId] authored this post — used to gate edit/delete UI.
  bool isAuthoredBy(int? viewerId) => viewerId != null && viewerId == authorId;

  factory Post.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    return Post(
      id: _asInt(json['id']) ?? 0,
      boardId: _asInt(json['board_id']) ?? 0,
      authorId: _asInt(json['author_id']) ?? 0,
      title: _asString(json['title']),
      content: _asString(json['content']),
      isAnonymous: _asBool(json['is_anonymous']),
      isPrivate: _asBool(json['is_private']),
      isPinned: _asBool(json['is_pinned']),
      viewCount: _asInt(json['view_count']) ?? 0,
      attachments: rawAttachments is List
          ? rawAttachments
              .whereType<Map>()
              .map((e) => PostAttachment.fromJson(
                  e.map((k, v) => MapEntry(k.toString(), v))))
              .toList()
          : const [],
      createdAt: _asDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _asDate(json['updated_at']),
    );
  }
}

/// A comment (`CommentOut`). Same anonymity rule as [Post].
class Comment {
  const Comment({
    required this.id,
    required this.authorId,
    required this.content,
    required this.isAnonymous,
    required this.createdAt,
    this.postId,
    this.parentCommentId,
  });

  final int id;
  final int? postId;
  final int authorId;
  final int? parentCommentId;
  final String content;
  final bool isAnonymous;
  final DateTime createdAt;

  bool isAuthoredBy(int? viewerId) => viewerId != null && viewerId == authorId;

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: _asInt(json['id']) ?? 0,
      postId: _asInt(json['post_id']),
      authorId: _asInt(json['author_id']) ?? 0,
      parentCommentId: _asInt(json['parent_comment_id']),
      content: _asString(json['content']),
      isAnonymous: _asBool(json['is_anonymous']),
      createdAt: _asDate(json['created_at']) ?? DateTime.now(),
    );
  }
}

/// De-anonymized author info (`AuthorIdentityOut`) returned by the audited
/// `GET /posts/{id}/author-identity` reveal. This is the ONLY channel through
/// which an anonymous author's real identity may be shown.
class AuthorIdentity {
  const AuthorIdentity({
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

  final int authorId;
  final String authorName;
  final DateTime createdAt;

  factory AuthorIdentity.fromJson(Map<String, dynamic> json) {
    return AuthorIdentity(
      authorId: _asInt(json['author_id']) ?? 0,
      authorName: _asString(json['author_name']),
      createdAt: _asDate(json['created_at']) ?? DateTime.now(),
    );
  }
}

/// Result of a presigned-upload request (`POST /files/presign`).
class PresignResult {
  const PresignResult({required this.uploadUrl, required this.fileKey});

  final String uploadUrl;
  final String fileKey;

  factory PresignResult.fromJson(Map<String, dynamic> json) {
    return PresignResult(
      uploadUrl: _asString(json['upload_url']),
      fileKey: _asString(json['file_key']),
    );
  }
}
