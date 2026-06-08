/// Data layer for the INSTRUCTOR assignment-grading flow.
///
/// Wraps the instructor/admin-only `/assignments/*` and `/submissions/*`
/// endpoints (see backend `app/api/v1/assignments.py`). This layer holds NO
/// state and NO UI logic: it returns parsed DTOs or throws a [GradingException]
/// carrying a clean Korean message.
///
/// Reuses the existing F2 domain models [Assignment] / [Submission]
/// (`domain/assignment_model.dart`) — only the list-row shape, which the
/// backend returns as `SubmissionListItem` (with `student_name`), is new and is
/// defined here as [SubmissionRow].
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../../../shared/utils/date_formatter.dart';
import '../domain/assignment_model.dart';

/// Thrown by [GradingRepository] when a call fails. Carries a user-facing
/// (Korean) [message] already extracted from the backend error envelope, plus
/// the backend error [code] for callers that want to branch on it.
class GradingException implements Exception {
  const GradingException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// A single submission row as returned by
/// `GET /assignments/{id}/submissions` (`SubmissionListItem`).
///
/// This is the LIST projection — it carries the student's name + score + status
/// but NOT the submission `content` (the instructor opens a detail to read it,
/// and a student's content is never exposed to other students).
class SubmissionRow {
  const SubmissionRow({
    required this.id,
    required this.studentId,
    required this.submittedAt,
    required this.isLate,
    required this.status,
    this.studentName,
    this.score,
  });

  final int id;
  final int studentId;
  final String? studentName;
  final DateTime submittedAt;
  final bool isLate;
  final int? score;
  final SubmissionStatus status;

  bool get isGraded => status == SubmissionStatus.reviewed;

  factory SubmissionRow.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
    return SubmissionRow(
      id: asInt(json['id']) ?? 0,
      studentId: asInt(json['student_id']) ?? 0,
      studentName: json['student_name']?.toString(),
      submittedAt: DateFormatter.tryParse(json['submitted_at']?.toString()) ??
          DateTime.now(),
      isLate: json['is_late'] == true,
      score: asInt(json['score']),
      status: SubmissionStatus.fromRaw(json['status']?.toString()),
    );
  }
}

/// Maps known backend error codes to friendly Korean copy. Falls back to the
/// server-provided message when the code is unknown.
const Map<String, String> _gradingErrorCopy = {
  'NOT_FOUND': '대상을 찾을 수 없습니다.',
  'FORBIDDEN': '접근 권한이 없습니다.',
};

/// Calls the instructor-facing `/assignments/*` and `/submissions/*` endpoints.
class GradingRepository {
  GradingRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  /// `GET /assignments?cohort_id&status&page&size` → list of [Assignment].
  ///
  /// For an instructor the backend already scopes the result to their cohort /
  /// authored assignments, so [cohortId] is optional.
  Future<List<Assignment>> listAssignments({
    int? cohortId,
    String? status,
    int page = 1,
    int size = 100,
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
      return envelope.data ?? const [];
    });
  }

  /// `POST /assignments` → the created [Assignment].
  ///
  /// Instructor/admin only (backend `require_roles`). [maxScore] and
  /// [attachments] are optional.
  Future<Assignment> createAssignment({
    required int cohortId,
    required String title,
    required String description,
    required DateTime dueDate,
    bool allowLateSubmission = false,
    int? maxScore,
    List<SubmissionFileRef> attachments = const [],
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/assignments',
        data: {
          'cohort_id': cohortId,
          'title': title,
          'description': description,
          'due_date': dueDate.toUtc().toIso8601String(),
          'allow_late_submission': allowLateSubmission,
          'max_score': ?maxScore,
          'attachments': attachments.map((a) => a.toJson()).toList(),
        },
      );
      final envelope = ApiResponse<Assignment>.fromJson(
        response.data ?? const {},
        (json) => Assignment.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `GET /assignments/{id}/submissions?page&size` → submission rows.
  ///
  /// Instructor/admin only. Returns the LIST projection ([SubmissionRow]) with
  /// student names; the instructor opens [getSubmission] to read content.
  Future<List<SubmissionRow>> listSubmissions(
    int assignmentId, {
    int page = 1,
    int size = 100,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/assignments/$assignmentId/submissions',
        queryParameters: {'page': page, 'size': size},
      );
      final envelope = ApiResponse<List<SubmissionRow>>.fromJson(
        response.data ?? const {},
        (json) => (json as List<dynamic>)
            .map((e) => SubmissionRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      _throwIfError(envelope);
      return envelope.data ?? const [];
    });
  }

  /// `GET /submissions/{id}` → the full [Submission] (incl. `content`).
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

  /// `PATCH /submissions/{id}/feedback` → the updated [Submission].
  ///
  /// [feedback] is required by the backend (`FeedbackRequest.feedback`).
  /// [score] is optional (null leaves the stored score unchanged on the server).
  /// [status] defaults to `reviewed` (use `resubmit_requested` to ask for a
  /// resubmission).
  Future<Submission> giveFeedback(
    int submissionId, {
    required String feedback,
    int? score,
    String status = 'reviewed',
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/submissions/$submissionId/feedback',
        data: {
          'feedback': feedback,
          'score': ?score,
          'status': status,
        },
      );
      final envelope = ApiResponse<Submission>.fromJson(
        response.data ?? const {},
        (json) => Submission.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  // ── envelope / error helpers ──────────────────────────────────────────────

  T _unwrap<T>(ApiResponse<T> response) {
    _throwIfError(response);
    final data = response.data;
    if (data == null) {
      throw const GradingException(_fallbackMessage);
    }
    return data;
  }

  void _throwIfError<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      final code = response.error!.code;
      throw GradingException(
        _gradingErrorCopy[code] ?? response.error!.message,
        code: code,
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw GradingException(
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
    if (code != null && _gradingErrorCopy.containsKey(code)) {
      return _gradingErrorCopy[code]!;
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

/// Provides the [GradingRepository] wired to the shared [dioProvider].
final gradingRepositoryProvider = Provider<GradingRepository>(
  (ref) => GradingRepository(ref.watch(dioProvider)),
);
