import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/board_model.dart';

/// A page of posts plus its pagination metadata.
class PostPage {
  const PostPage({required this.posts, required this.pagination});

  final List<Post> posts;
  final Pagination pagination;
}

/// Thrown by [BoardRepository] when a board/post/comment call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend error [code] for callers that branch on it.
class BoardException implements Exception {
  const BoardException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Calls the `/boards`, `/posts`, `/comments` and `/files/presign` endpoints
/// and parses the backend response envelope.
///
/// This layer holds NO state and NO UI logic: it returns parsed domain models
/// or throws a [BoardException] with a clean message.
class BoardRepository {
  BoardRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  // ── Boards ────────────────────────────────────────────────────────────

  /// `GET /boards` → visible boards. The backend already scopes by the
  /// caller's cohort; [type] optionally filters by board type.
  Future<List<Board>> listBoards({int? cohortId, String? type}) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/boards/',
        queryParameters: {
          'cohort_id': ?cohortId,
          if (type != null && type.isNotEmpty) 'type': type,
        },
      );
      final envelope = ApiResponse<List<Board>>.fromJson(
        response.data ?? const {},
        _parseBoardList,
      );
      return _unwrap(envelope) ?? const <Board>[];
    });
  }

  /// `POST /boards/` → the created board. Roles `admin_ops` / `instructor`
  /// only (enforced server-side). Note the collection-root trailing slash.
  Future<Board> createBoard({
    required String name,
    required String type,
    int? cohortId,
    String? description,
    bool allowAnonymous = false,
    bool allowPrivatePost = false,
    String visibility = 'cohort',
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/boards/',
        data: {
          'name': name,
          'type': type,
          'cohort_id': ?cohortId,
          if (description != null && description.isNotEmpty)
            'description': description,
          'allow_anonymous': allowAnonymous,
          'allow_private_post': allowPrivatePost,
          'visibility': visibility,
        },
      );
      return _unwrapData(
        ApiResponse<Board>.fromJson(response.data ?? const {}, _parseBoard),
      );
    });
  }

  /// `PATCH /boards/{id}` → the updated board. Only non-null fields are sent.
  /// Owner or `admin_ops` only (enforced server-side). No trailing slash.
  Future<Board> updateBoard(
    int boardId, {
    String? name,
    String? description,
    bool? allowAnonymous,
    bool? allowPrivatePost,
    String? visibility,
    int? sortOrder,
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/boards/$boardId',
        data: {
          'name': ?name,
          'description': ?description,
          'allow_anonymous': ?allowAnonymous,
          'allow_private_post': ?allowPrivatePost,
          'visibility': ?visibility,
          'sort_order': ?sortOrder,
        },
      );
      return _unwrapData(
        ApiResponse<Board>.fromJson(response.data ?? const {}, _parseBoard),
      );
    });
  }

  /// `DELETE /boards/{id}`. Owner or `admin_ops` only (enforced server-side).
  Future<void> deleteBoard(int boardId) async {
    return _guard(() async {
      await _dio.delete<Map<String, dynamic>>('/boards/$boardId');
    });
  }

  // ── Posts ─────────────────────────────────────────────────────────────

  /// `GET /posts` → a page of posts (pinned first, then newest). Server-side
  /// visibility hides other students' private posts.
  Future<PostPage> listPosts({
    int? boardId,
    String? search,
    int? authorId,
    int page = 1,
    int size = 20,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/posts',
        queryParameters: {
          'board_id': ?boardId,
          if (search != null && search.isNotEmpty) 'search': search,
          'author_id': ?authorId,
          'page': page,
          'size': size,
        },
      );
      final envelope = ApiResponse<List<Post>>.fromJson(
        response.data ?? const {},
        _parsePostList,
      );
      final posts = _unwrap(envelope) ?? const <Post>[];
      final meta = envelope.meta;
      return PostPage(
        posts: posts,
        pagination: meta == null
            ? Pagination(page: page, size: size, total: posts.length)
            : Pagination.fromMeta(meta),
      );
    });
  }

  /// `GET /posts/{id}` → a single post (also increments its view count
  /// server-side).
  Future<Post> getPost(int postId) async {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/posts/$postId');
      return _unwrapData(
        ApiResponse<Post>.fromJson(response.data ?? const {}, _parsePost),
      );
    });
  }

  /// `POST /posts` → the created post.
  Future<Post> createPost({
    required int boardId,
    required String title,
    required String content,
    bool isAnonymous = false,
    bool isPrivate = false,
    List<PostAttachment> attachments = const [],
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/posts',
        data: {
          'board_id': boardId,
          'title': title,
          'content': content,
          'is_anonymous': isAnonymous,
          'is_private': isPrivate,
          'attachments': attachments.map((a) => a.toJson()).toList(),
        },
      );
      return _unwrapData(
        ApiResponse<Post>.fromJson(response.data ?? const {}, _parsePost),
      );
    });
  }

  /// `PATCH /posts/{id}` → the updated post. Only non-null fields are sent.
  /// Author or `admin_ops` only (enforced server-side).
  Future<Post> updatePost(
    int postId, {
    String? title,
    String? content,
    List<PostAttachment>? attachments,
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/posts/$postId',
        data: {
          'title': ?title,
          'content': ?content,
          if (attachments != null)
            'attachments': attachments.map((a) => a.toJson()).toList(),
        },
      );
      return _unwrapData(
        ApiResponse<Post>.fromJson(response.data ?? const {}, _parsePost),
      );
    });
  }

  /// `DELETE /posts/{id}` (soft delete). Author or admin_ops only (enforced
  /// server-side).
  Future<void> deletePost(int postId) async {
    return _guard(() async {
      await _dio.delete<Map<String, dynamic>>('/posts/$postId');
    });
  }

  /// `POST /posts/{id}/pin` → the updated post with the new pinned state.
  /// Roles `admin_ops` / `instructor` only (enforced server-side). Pass the
  /// desired [pinned] target (a toggle is computed by the caller).
  Future<Post> pinPost(int postId, {required bool pinned}) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/posts/$postId/pin',
        data: {'pinned': pinned},
      );
      return _unwrapData(
        ApiResponse<Post>.fromJson(response.data ?? const {}, _parsePost),
      );
    });
  }

  /// `GET /posts/{id}/author-identity` → de-anonymizes an anonymous post's
  /// author. Role `admin_ops` ONLY and **audited** server-side; a non-empty
  /// [reason] is required and logged. Never call this except behind an explicit
  /// operator confirmation.
  Future<AuthorIdentity> getAuthorIdentity(int postId, String reason) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/posts/$postId/author-identity',
        queryParameters: {'reason': reason},
      );
      return _unwrapData(
        ApiResponse<AuthorIdentity>.fromJson(
            response.data ?? const {}, _parseAuthorIdentity),
      );
    });
  }

  // ── Comments ──────────────────────────────────────────────────────────

  /// `GET /posts/{id}/comments` → comments in creation order.
  Future<List<Comment>> listComments(int postId) async {
    return _guard(() async {
      final response = await _dio
          .get<Map<String, dynamic>>('/posts/$postId/comments');
      final envelope = ApiResponse<List<Comment>>.fromJson(
        response.data ?? const {},
        _parseCommentList,
      );
      return _unwrap(envelope) ?? const <Comment>[];
    });
  }

  /// `POST /posts/{id}/comments` → the created comment.
  Future<Comment> createComment({
    required int postId,
    required String content,
    int? parentCommentId,
    bool isAnonymous = false,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/posts/$postId/comments',
        data: {
          'content': content,
          'parent_comment_id': ?parentCommentId,
          'is_anonymous': isAnonymous,
        },
      );
      return _unwrapData(
        ApiResponse<Comment>.fromJson(
            response.data ?? const {}, _parseComment),
      );
    });
  }

  /// `PATCH /comments/{id}` → the updated comment. Author or admin_ops only.
  Future<Comment> updateComment(int commentId, String content) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/comments/$commentId',
        data: {'content': content},
      );
      return _unwrapData(
        ApiResponse<Comment>.fromJson(
            response.data ?? const {}, _parseComment),
      );
    });
  }

  /// `DELETE /comments/{id}` (soft delete). Author or admin_ops only.
  Future<void> deleteComment(int commentId) async {
    return _guard(() async {
      await _dio.delete<Map<String, dynamic>>('/comments/$commentId');
    });
  }

  // ── Attachments (S3 presigned upload) ───────────────────────────────────

  /// `POST /files/presign` → a presigned PUT URL + the final file key for a
  /// post attachment. The caller then PUTs the bytes to [PresignResult.uploadUrl]
  /// (see [uploadToPresignedUrl]) and includes the [PresignResult.fileKey] in
  /// the post `attachments` payload.
  Future<PresignResult> presignPostAttachment({
    required String fileName,
    required String contentType,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/files/presign',
        data: {
          'purpose': 'post_attachment',
          'context': const <String, dynamic>{},
          'file_name': fileName,
          'content_type': contentType,
        },
      );
      return _unwrapData(
        ApiResponse<PresignResult>.fromJson(
            response.data ?? const {}, _parsePresign),
      );
    });
  }

  /// Uploads raw [bytes] to a presigned S3 PUT [uploadUrl]. This call goes
  /// directly to S3, NOT the API, so it bypasses the envelope/auth interceptor.
  Future<void> uploadToPresignedUrl({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    try {
      await Dio().put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
    } on DioException {
      throw const BoardException('파일 업로드에 실패했습니다. 다시 시도해주세요.');
    }
  }

  // ── Envelope / error plumbing ───────────────────────────────────────────

  static List<Board> _parseBoardList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) => Board.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static List<Post> _parsePostList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) => Post.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static List<Comment> _parseCommentList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) => Comment.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static Board _parseBoard(Object? json) =>
      Board.fromJson(json as Map<String, dynamic>);

  static Post _parsePost(Object? json) =>
      Post.fromJson(json as Map<String, dynamic>);

  static AuthorIdentity _parseAuthorIdentity(Object? json) =>
      AuthorIdentity.fromJson(json as Map<String, dynamic>);

  static Comment _parseComment(Object? json) =>
      Comment.fromJson(json as Map<String, dynamic>);

  static PresignResult _parsePresign(Object? json) =>
      PresignResult.fromJson(json as Map<String, dynamic>);

  /// Returns [ApiResponse.data] (may be null for empty list payloads) or throws
  /// a [BoardException] when the envelope carries an error.
  T? _unwrap<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      throw BoardException(response.error!.message, code: response.error!.code);
    }
    return response.data;
  }

  /// Like [_unwrap] but for single-object payloads that must not be null.
  T _unwrapData<T>(ApiResponse<T> response) {
    final data = _unwrap(response);
    if (data == null) throw const BoardException(_fallbackMessage);
    return data;
  }

  /// Runs [action], converting a [DioException] into a [BoardException] whose
  /// message is taken from the backend error envelope when present.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw BoardException(
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
    // Fall back to a friendly message for known status codes.
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

/// Provides the [BoardRepository] wired to the shared [dioProvider].
final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(ref.watch(dioProvider)),
);
