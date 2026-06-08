import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/course_model.dart';

/// Thrown by [CourseRepository] when a course/video call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend error [code] for callers that want to branch.
class CourseException implements Exception {
  const CourseException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Result of a paged `GET /courses/` call: the parsed items plus pagination.
class CoursePage {
  const CoursePage({required this.items, this.pagination});

  final List<Course> items;
  final Pagination? pagination;
}

/// Maps known backend error codes to friendly Korean copy.
const Map<String, String> _courseErrorCopy = {
  'NOT_FOUND': '수업을 찾을 수 없습니다.',
  'FORBIDDEN': '접근 권한이 없습니다.',
};

/// Calls the `/courses/*` and `/files/presign` endpoints and parses the backend
/// response envelope.
///
/// This layer holds NO state and NO UI logic: it returns parsed DTOs
/// ([Course] / [CourseVideo]) or throws a [CourseException] with a clean Korean
/// message.
///
/// IMPORTANT: collection calls MUST use the trailing-slash path `'/courses/'`
/// (the backend router declares `@router.get("/")` under `prefix="/courses"`).
/// Hitting `/courses` (no slash) triggers a 307 redirect that drops the
/// Authorization header / request body.
class CourseRepository {
  CourseRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  /// Formats a [DateTime] to the backend `YYYY-MM-DD` date-only wire format.
  static String formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// `GET /courses/?cohort_id&page&size` → (items, total).
  ///
  /// The backend already scopes results by role (student → own cohort,
  /// instructor → taught cohorts, admin_ops → institution), so [cohortId] is an
  /// optional extra filter.
  Future<CoursePage> listCourses({
    int? cohortId,
    int page = 1,
    int size = 20,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/courses/',
        queryParameters: {
          'cohort_id': ?cohortId,
          'page': page,
          'size': size,
        },
      );
      final envelope = ApiResponse<List<Course>>.fromJson(
        response.data ?? const {},
        (json) => (json as List<dynamic>)
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      _throwIfError(envelope);
      return CoursePage(
        items: envelope.data ?? const [],
        pagination:
            envelope.meta == null ? null : Pagination.fromMeta(envelope.meta!),
      );
    });
  }

  /// `GET /courses/{id}` → a single [Course] (metadata only; videos load
  /// separately via [listVideos]).
  Future<Course> getCourse(int id) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>('/courses/$id');
      final envelope = ApiResponse<Course>.fromJson(
        response.data ?? const {},
        (json) => Course.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `POST /courses/` (trailing slash) → the created [Course].
  Future<Course> createCourse({
    required int cohortId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/courses/',
        data: {
          'cohort_id': cohortId,
          'title': title,
          'description': ?description,
          'start_date': formatDate(startDate),
          'end_date': formatDate(endDate),
        },
      );
      final envelope = ApiResponse<Course>.fromJson(
        response.data ?? const {},
        (json) => Course.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `PATCH /courses/{id}` → the updated [Course]. Only non-null fields are sent.
  Future<Course> updateCourse(
    int id, {
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    CourseStatus? status,
  }) async {
    return _guard(() async {
      final body = <String, dynamic>{
        'title': ?title,
        'description': ?description,
        'start_date': startDate == null ? null : formatDate(startDate),
        'end_date': endDate == null ? null : formatDate(endDate),
        'status': ?status?.wire,
      }..removeWhere((_, v) => v == null);
      final response = await _dio.patch<Map<String, dynamic>>(
        '/courses/$id',
        data: body,
      );
      final envelope = ApiResponse<Course>.fromJson(
        response.data ?? const {},
        (json) => Course.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `GET /courses/{id}/videos?from&to` → a BARE list of [CourseVideo]
  /// (NOT paginated; `data` is the list itself).
  Future<List<CourseVideo>> listVideos(
    int courseId, {
    DateTime? from,
    DateTime? to,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/courses/$courseId/videos',
        queryParameters: {
          'from': from == null ? null : formatDate(from),
          'to': to == null ? null : formatDate(to),
        }..removeWhere((_, v) => v == null),
      );
      final envelope = ApiResponse<List<CourseVideo>>.fromJson(
        response.data ?? const {},
        (json) => (json as List<dynamic>)
            .map((e) => CourseVideo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      _throwIfError(envelope);
      return envelope.data ?? const [];
    });
  }

  /// `POST /courses/{id}/videos` → the registered [CourseVideo].
  Future<CourseVideo> addVideo(
    int courseId, {
    required DateTime classDate,
    required String fileKey,
    String? title,
    String? originalFilename,
    String? contentType,
    int? sizeBytes,
    int? durationSeconds,
    int sortOrder = 0,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/courses/$courseId/videos',
        data: {
          'class_date': formatDate(classDate),
          'file_key': fileKey,
          'title': ?title,
          'original_filename': ?originalFilename,
          'content_type': ?contentType,
          'size_bytes': ?sizeBytes,
          'duration_seconds': ?durationSeconds,
          'sort_order': sortOrder,
        },
      );
      final envelope = ApiResponse<CourseVideo>.fromJson(
        response.data ?? const {},
        (json) => CourseVideo.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `GET /courses/{id}/day-logs?from&to` → a BARE list of [CourseDayLog]
  /// (NOT paginated; `data` is the list itself).
  Future<List<CourseDayLog>> listDayLogs(
    int courseId, {
    DateTime? from,
    DateTime? to,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/courses/$courseId/day-logs',
        queryParameters: {
          'from': from == null ? null : formatDate(from),
          'to': to == null ? null : formatDate(to),
        }..removeWhere((_, v) => v == null),
      );
      final envelope = ApiResponse<List<CourseDayLog>>.fromJson(
        response.data ?? const {},
        (json) => (json as List<dynamic>)
            .map((e) => CourseDayLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      _throwIfError(envelope);
      return envelope.data ?? const [];
    });
  }

  /// `GET /courses/{id}/day-logs/{class_date}` → the day's [CourseDayLog], or
  /// `null` when no log has been written for that date yet.
  Future<CourseDayLog?> getDayLog(int courseId, DateTime date) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/courses/$courseId/day-logs/${formatDate(date)}',
      );
      final body = response.data ?? const {};
      final envelope = ApiResponse<CourseDayLog?>.fromJson(
        body,
        (json) =>
            json == null ? null : CourseDayLog.fromJson(json as Map<String, dynamic>),
      );
      _throwIfError(envelope);
      return envelope.data;
    });
  }

  /// `PUT /courses/{id}/day-logs {class_date, content}` → the upserted
  /// [CourseDayLog] (instructor-owner / admin only).
  Future<CourseDayLog> upsertDayLog(
    int courseId, {
    required DateTime classDate,
    required String content,
  }) async {
    return _guard(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/courses/$courseId/day-logs',
        data: {
          'class_date': formatDate(classDate),
          'content': content,
        },
      );
      final envelope = ApiResponse<CourseDayLog>.fromJson(
        response.data ?? const {},
        (json) => CourseDayLog.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `POST /files/download-url {file_key, download?, filename?}` → a short-lived
  /// presigned GET URL for the stored object [fileKey].
  ///
  ///   - For in-app PLAY: leave [download] false (inline URL the web-native
  ///     `<video>` element can stream with Range support).
  ///   - For DOWNLOAD: pass `download: true` plus an optional [filename] so the
  ///     browser saves the file with a friendly name (attachment disposition).
  Future<String> videoUrl(
    String fileKey, {
    bool download = false,
    String? filename,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/files/download-url',
        data: {
          'file_key': fileKey,
          'download': download,
          'filename': ?filename,
        },
      );
      final data = (response.data ?? const {})['data'];
      if (data is Map) {
        final url = (data['url'] ?? '').toString();
        if (url.isNotEmpty) return url;
      }
      throw const CourseException(_fallbackMessage);
    });
  }

  /// `DELETE /courses/{id}/videos/{videoId}` — removes a video's metadata.
  Future<void> deleteVideo(int courseId, int videoId) async {
    return _guard(() async {
      await _dio.delete<dynamic>('/courses/$courseId/videos/$videoId');
    });
  }

  /// Full upload flow for one video file, returning the resulting S3 `file_key`:
  ///   1. `POST /files/presign {purpose: "course_video"}` → `{upload_url, file_key}`
  ///   2. `PUT upload_url` (direct-to-S3 upload of [bytes]) on a BARE Dio so the
  ///      auth interceptor / base URL do not leak onto the S3 request.
  Future<String> presignAndUpload({
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    return _guard(() async {
      final presignResponse = await _dio.post<Map<String, dynamic>>(
        '/files/presign',
        data: {
          'purpose': 'course_video',
          'file_name': fileName,
          'content_type': contentType,
        },
      );
      final envelope = ApiResponse<_PresignResult>.fromJson(
        presignResponse.data ?? const {},
        (json) => _PresignResult.fromJson(json as Map<String, dynamic>),
      );
      final presign = _unwrap(envelope);

      final s3 = Dio();
      await s3.put<void>(
        presign.uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );

      return presign.fileKey;
    });
  }

  // ── envelope / error helpers ──────────────────────────────────────────────

  T _unwrap<T>(ApiResponse<T> response) {
    _throwIfError(response);
    final data = response.data;
    if (data == null) {
      throw const CourseException(_fallbackMessage);
    }
    return data;
  }

  void _throwIfError<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      final code = response.error!.code;
      throw CourseException(
        _courseErrorCopy[code] ?? response.error!.message,
        code: code,
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw CourseException(
        _messageFromDioException(e),
        code: _codeFromDioException(e),
      );
    }
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

    final code = _codeFromDioException(e);
    if (code != null && _courseErrorCopy.containsKey(code)) {
      return _courseErrorCopy[code]!;
    }

    if (e.response?.statusCode == 403) {
      return '접근 권한이 없습니다.';
    }

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

/// Internal parse of the `/files/presign` `data` block.
class _PresignResult {
  const _PresignResult({required this.uploadUrl, required this.fileKey});

  final String uploadUrl;
  final String fileKey;

  factory _PresignResult.fromJson(Map<String, dynamic> json) => _PresignResult(
        uploadUrl: (json['upload_url'] ?? '').toString(),
        fileKey: (json['file_key'] ?? '').toString(),
      );
}

/// Provides the [CourseRepository] wired to the shared [dioProvider].
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(ref.watch(dioProvider)),
);
