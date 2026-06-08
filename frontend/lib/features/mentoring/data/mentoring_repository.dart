import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/mentoring_model.dart';

/// Thrown by [MentoringRepository] when a mentoring / evaluation call fails.
/// Carries a user-facing (Korean) [message] already extracted from the backend
/// error envelope, plus the backend error [code] for callers that branch on it.
class MentoringException implements Exception {
  const MentoringException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Calls the mentoring / evaluation endpoints and parses the backend response
/// envelope. This layer holds NO state and NO UI logic: it returns parsed
/// domain models or throws a [MentoringException] with a clean message.
///
/// Backend routes (prefix `/api/v1` is baked into the Dio base URL):
///   - `GET  /mentoring-logs`              → list mentoring logs (paginated)
///   - `POST /mentoring-logs`              → create a mentoring log
///   - `GET  /users/`                      → cohort student list (for the picker)
///   - `GET  /classes/{id}/evaluations`    → anonymised evaluation summary
///   - `POST /classes/{id}/evaluations`    → (student-only) submit an evaluation
class MentoringRepository {
  MentoringRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  // ── Mentoring logs ────────────────────────────────────────────────────

  /// `GET /mentoring-logs` → a page of mentoring logs (newest session first).
  ///
  /// The backend scopes by role (an instructor only sees their own logs);
  /// [studentId] optionally narrows to one student.
  Future<List<MentoringLog>> listMentoringLogs({
    int? studentId,
    int page = 1,
    int size = 50,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/mentoring-logs',
        queryParameters: {
          'student_id': ?studentId,
          'page': page,
          'size': size,
        },
      );
      final envelope = ApiResponse<List<MentoringLog>>.fromJson(
        response.data ?? const {},
        _parseLogList,
      );
      return _unwrap(envelope) ?? const <MentoringLog>[];
    });
  }

  /// `POST /mentoring-logs` → the created log. Instructor-only (server-enforced).
  ///
  /// [cohortId] is optional: the server falls back to the instructor's own
  /// cohort when omitted.
  Future<MentoringLog> createMentoringLog({
    required int studentId,
    required DateTime sessionDate,
    required String content,
    String? followUp,
    int? cohortId,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/mentoring-logs',
        data: {
          'student_id': studentId,
          'session_date': _dateOnly(sessionDate),
          'content': content,
          'follow_up': ?_nullIfBlank(followUp),
          'cohort_id': ?cohortId,
        },
      );
      return _unwrapData(
        ApiResponse<MentoringLog>.fromJson(
          response.data ?? const {},
          _parseLog,
        ),
      );
    });
  }

  // ── Cohort students (for the counseling-subject picker) ─────────────────

  /// `GET /users/?role=student&cohort_id=…` → students in the cohort. Used only
  /// to choose the subject of a new mentoring log.
  ///
  /// Note the trailing slash: the backend mounts the list handler at `/users/`.
  Future<List<CohortStudent>> listCohortStudents({
    int? cohortId,
    String? search,
    int size = 200,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/users/',
        queryParameters: {
          'role': 'student',
          'cohort_id': ?cohortId,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': 1,
          'size': size,
        },
      );
      final envelope = ApiResponse<List<CohortStudent>>.fromJson(
        response.data ?? const {},
        _parseStudentList,
      );
      return _unwrap(envelope) ?? const <CohortStudent>[];
    });
  }

  // ── Class evaluations (anonymous) ───────────────────────────────────────

  /// `GET /classes/{classId}/evaluations` → the anonymised evaluation summary.
  ///
  /// admin_ops / instructor only (server-enforced). The payload carries NO
  /// student identity — just aggregates and unattributed comments.
  Future<ClassEvaluation> getEvaluationSummary(int classId) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/classes/$classId/evaluations',
      );
      return _unwrapData(
        ApiResponse<ClassEvaluation>.fromJson(
          response.data ?? const {},
          _parseEvaluation,
        ),
      );
    });
  }

  // ── Parsing helpers ─────────────────────────────────────────────────────

  static List<MentoringLog> _parseLogList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) =>
          MentoringLog.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static MentoringLog _parseLog(Object? json) =>
      MentoringLog.fromJson(json as Map<String, dynamic>);

  static List<CohortStudent> _parseStudentList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) =>
          CohortStudent.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static ClassEvaluation _parseEvaluation(Object? json) =>
      ClassEvaluation.fromJson(json as Map<String, dynamic>);

  /// Formats a [DateTime] as the `YYYY-MM-DD` date-only string the backend's
  /// `session_date` field expects.
  static String _dateOnly(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static String? _nullIfBlank(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  // ── Envelope / error plumbing ───────────────────────────────────────────

  /// Returns [ApiResponse.data] (may be null for empty list payloads) or throws
  /// a [MentoringException] when the envelope carries an error.
  T? _unwrap<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      throw MentoringException(
        response.error!.message,
        code: response.error!.code,
      );
    }
    return response.data;
  }

  /// Like [_unwrap] but for single-object payloads that must not be null.
  T _unwrapData<T>(ApiResponse<T> response) {
    final data = _unwrap(response);
    if (data == null) throw const MentoringException(_fallbackMessage);
    return data;
  }

  /// Runs [action], converting a [DioException] into a [MentoringException]
  /// whose message is taken from the backend error envelope when present.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw MentoringException(
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

/// Provides the [MentoringRepository] wired to the shared [dioProvider].
final mentoringRepositoryProvider = Provider<MentoringRepository>(
  (ref) => MentoringRepository(ref.watch(dioProvider)),
);
