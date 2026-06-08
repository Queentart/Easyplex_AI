import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/assignment_model.dart';

/// Thrown by [AssignmentRepository] when an assignment call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend error [code] for callers that want to branch on
/// it (e.g. `LATE_NOT_ALLOWED`).
class AssignmentException implements Exception {
  const AssignmentException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Result of a paged `GET /assignments` call: the parsed items plus pagination.
class AssignmentPage {
  const AssignmentPage({required this.items, this.pagination});

  final List<Assignment> items;
  final Pagination? pagination;
}

/// Maps known backend 422 business-rule codes to friendly Korean copy. Falls
/// back to the server-provided message when the code is unknown.
const Map<String, String> _assignmentErrorCopy = {
  'LATE_NOT_ALLOWED': '제출 마감일이 지나 더 이상 제출할 수 없습니다.',
  'NOT_FOUND': '과제를 찾을 수 없습니다.',
  'FORBIDDEN': '접근 권한이 없습니다.',
};

/// Calls the `/assignments/*` and `/files/presign` endpoints and parses the
/// backend response envelope.
///
/// This layer holds NO state and NO UI logic: it returns parsed DTOs
/// ([Assignment] / [Submission]) or throws an [AssignmentException] with a
/// clean Korean message.
class AssignmentRepository {
  AssignmentRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  /// `GET /assignments?cohort_id&status&page&size` → list of [Assignment].
  ///
  /// The backend already scopes a student to their own cohort, so the student
  /// list screen does not need to pass [cohortId].
  Future<AssignmentPage> listAssignments({
    int? cohortId,
    String? status,
    int page = 1,
    int size = 20,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/assignments',
        queryParameters: {
          'cohort_id': ?cohortId,
          'status': ?status,
          'page': page,
          'size': size,
        },
      );
      final envelope = ApiResponse<List<Assignment>>.fromJson(
        response.data ?? const {},
        (json) => (json as List<dynamic>)
            .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      _throwIfError(envelope);
      return AssignmentPage(
        items: envelope.data ?? const [],
        pagination:
            envelope.meta == null ? null : Pagination.fromMeta(envelope.meta!),
      );
    });
  }

  /// `GET /assignments/{id}` → a single [Assignment].
  Future<Assignment> getAssignment(int assignmentId) async {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/assignments/$assignmentId');
      final envelope = ApiResponse<Assignment>.fromJson(
        response.data ?? const {},
        (json) => Assignment.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `POST /assignments/{id}/submissions` → the created/updated [Submission].
  ///
  /// The backend upserts: re-submitting the same assignment replaces content +
  /// timestamp and appends the file (if any). [file] is optional; pass null for
  /// a text-only submission.
  Future<Submission> submit(
    int assignmentId, {
    String? content,
    SubmissionFileRef? file,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/assignments/$assignmentId/submissions',
        data: {
          'content': ?content,
          ...?file?.toJson(),
        },
      );
      final envelope = ApiResponse<Submission>.fromJson(
        response.data ?? const {},
        (json) => Submission.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `GET /submissions/{id}` → the current student's own [Submission].
  ///
  /// Only used to re-read a submission whose id is already known (returned by a
  /// prior [submit] call). The backend forbids reading another student's
  /// submission, so this is always the caller's own work.
  Future<Submission> getSubmission(int submissionId) async {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/submissions/$submissionId');
      final envelope = ApiResponse<Submission>.fromJson(
        response.data ?? const {},
        (json) => Submission.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// Full upload flow for one attachment, returning a [SubmissionFileRef] ready
  /// to attach to a submission:
  ///   1. `POST /files/presign` → `{upload_url, file_key}`
  ///   2. `PUT upload_url` (direct-to-S3 upload of [bytes])
  /// The backend does not echo a size, so [SubmissionFileRef.fileSize] is the
  /// locally measured byte length.
  Future<SubmissionFileRef> uploadSubmissionFile({
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    return _guard(() async {
      final presignResponse = await _dio.post<Map<String, dynamic>>(
        '/files/presign',
        data: {
          'purpose': 'assignment_submission',
          'file_name': fileName,
          'content_type': contentType,
          'context': <String, dynamic>{},
        },
      );
      final envelope = ApiResponse<_PresignResult>.fromJson(
        presignResponse.data ?? const {},
        (json) => _PresignResult.fromJson(json as Map<String, dynamic>),
      );
      final presign = _unwrap(envelope);

      // Direct PUT to the presigned S3 URL. Use a bare Dio so the auth
      // interceptor / base URL do not leak onto the S3 request.
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

      return SubmissionFileRef(
        fileKey: presign.fileKey,
        fileName: fileName,
        fileSize: bytes.length,
        mimeType: contentType,
      );
    });
  }

  // ── envelope / error helpers ──────────────────────────────────────────────

  T _unwrap<T>(ApiResponse<T> response) {
    _throwIfError(response);
    final data = response.data;
    if (data == null) {
      throw const AssignmentException(_fallbackMessage);
    }
    return data;
  }

  void _throwIfError<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      final code = response.error!.code;
      throw AssignmentException(
        _assignmentErrorCopy[code] ?? response.error!.message,
        code: code,
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw AssignmentException(
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
    if (code != null && _assignmentErrorCopy.containsKey(code)) {
      return _assignmentErrorCopy[code]!;
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

/// Provides the [AssignmentRepository] wired to the shared [dioProvider].
final assignmentRepositoryProvider = Provider<AssignmentRepository>(
  (ref) => AssignmentRepository(ref.watch(dioProvider)),
);
