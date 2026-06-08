import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/class_model.dart';

/// A page of class sessions plus its pagination metadata.
class ClassPage {
  const ClassPage({required this.classes, required this.pagination});

  final List<ClassSession> classes;
  final Pagination pagination;
}

/// A page of career postings plus its pagination metadata.
class CareerPostingPage {
  const CareerPostingPage({required this.postings, required this.pagination});

  final List<CareerPosting> postings;
  final Pagination pagination;
}

/// Thrown by [ClassRepository] when a class-management call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend error [code] for callers that branch on it
/// (e.g. `EDIT_WINDOW_CLOSED`, `LOG_ALREADY_EXISTS`, `FORBIDDEN`).
class ClassException implements Exception {
  const ClassException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Calls the class-management endpoints (`/classes`, `/classes/{id}/...`,
/// `/cohorts/{id}/curriculum`, `/curriculum/{id}`, `/career-postings`) and
/// parses the backend response envelope.
///
/// This layer holds NO state and NO UI logic: it returns parsed domain models
/// or throws a [ClassException] with a clean message.
class ClassRepository {
  ClassRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  // ── Classes ─────────────────────────────────────────────────────────────

  /// `GET /classes` → a page of class sessions (newest first). The backend
  /// scopes results by the caller's cohort / instructor assignment.
  Future<ClassPage> listClasses({
    int? cohortId,
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
    int size = 20,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/classes',
        queryParameters: {
          'cohort_id': ?cohortId,
          if (fromDate != null) 'from_date': _dateParam(fromDate),
          if (toDate != null) 'to_date': _dateParam(toDate),
          'page': page,
          'size': size,
        },
      );
      final envelope = ApiResponse<List<ClassSession>>.fromJson(
        response.data ?? const {},
        _parseClassList,
      );
      final classes = _unwrap(envelope) ?? const <ClassSession>[];
      final meta = envelope.meta;
      return ClassPage(
        classes: classes,
        pagination: meta == null
            ? Pagination(page: page, size: size, total: classes.length)
            : Pagination.fromMeta(meta),
      );
    });
  }

  /// `GET /classes/{id}` → a single class session.
  Future<ClassSession> getClass(int classId) async {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/classes/$classId');
      return _unwrapData(
        ApiResponse<ClassSession>.fromJson(
            response.data ?? const {}, _parseClass),
      );
    });
  }

  /// `POST /classes` → the created class session. admin_ops / instructor only.
  Future<ClassSession> createClass({
    required int cohortId,
    required int instructorId,
    required String title,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? location,
    List<ClassMaterial> materials = const [],
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/classes',
        data: {
          'cohort_id': cohortId,
          'instructor_id': instructorId,
          'title': title,
          'date': _dateParam(date),
          'start_time': startTime,
          'end_time': endTime,
          'location': ?location,
          'materials': materials.map((m) => m.toJson()).toList(),
        },
      );
      return _unwrapData(
        ApiResponse<ClassSession>.fromJson(
            response.data ?? const {}, _parseClass),
      );
    });
  }

  /// `PATCH /classes/{id}` → the updated class session. Assigned instructor or
  /// admin_ops only (enforced server-side). Only non-null fields are sent.
  Future<ClassSession> updateClass(
    int classId, {
    String? title,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? location,
    String? status,
    List<ClassMaterial>? materials,
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/classes/$classId',
        data: {
          'title': ?title,
          if (date != null) 'date': _dateParam(date),
          'start_time': ?startTime,
          'end_time': ?endTime,
          'location': ?location,
          'status': ?status,
          if (materials != null)
            'materials': materials.map((m) => m.toJson()).toList(),
        },
      );
      return _unwrapData(
        ApiResponse<ClassSession>.fromJson(
            response.data ?? const {}, _parseClass),
      );
    });
  }

  // ── Recordings ──────────────────────────────────────────────────────────

  /// `POST /classes/{id}/recording` → the updated class session. The recording
  /// itself is created server-side from [fileKey]; admin_ops / instructor only.
  Future<ClassSession> addRecording(
    int classId, {
    required String fileKey,
    String? title,
    int? durationSeconds,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/classes/$classId/recording',
        data: {
          'file_key': fileKey,
          'title': ?title,
          'duration_seconds': ?durationSeconds,
        },
      );
      return _unwrapData(
        ApiResponse<ClassSession>.fromJson(
            response.data ?? const {}, _parseClass),
      );
    });
  }

  // ── Training log ──────────────────────────────────────────────────────────

  /// `GET /classes/{id}/training-log` → the class's training log. Throws a
  /// [ClassException] with code `NOT_FOUND` when none has been written yet.
  Future<TrainingLog> getTrainingLog(int classId) async {
    return _guard(() async {
      final response = await _dio
          .get<Map<String, dynamic>>('/classes/$classId/training-log');
      return _unwrapData(
        ApiResponse<TrainingLog>.fromJson(
            response.data ?? const {}, _parseTrainingLog),
      );
    });
  }

  /// `POST /classes/{id}/training-log` → the created training log. Instructor
  /// only; one log per class (server returns `LOG_ALREADY_EXISTS` otherwise).
  Future<TrainingLog> createTrainingLog(
    int classId, {
    required String content,
    String? achievements,
    String? nextPlan,
    Map<String, dynamic>? attendanceSummary,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/classes/$classId/training-log',
        data: {
          'content': content,
          'achievements': ?achievements,
          'next_plan': ?nextPlan,
          'attendance_summary': ?attendanceSummary,
        },
      );
      return _unwrapData(
        ApiResponse<TrainingLog>.fromJson(
            response.data ?? const {}, _parseTrainingLog),
      );
    });
  }

  /// `PATCH /classes/{id}/training-log` → the updated training log. The 24h
  /// edit window is enforced server-side: past it the backend returns
  /// `EDIT_WINDOW_CLOSED` (422) for instructors.
  Future<TrainingLog> updateTrainingLog(
    int classId, {
    String? content,
    String? achievements,
    String? nextPlan,
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/classes/$classId/training-log',
        data: {
          'content': ?content,
          'achievements': ?achievements,
          'next_plan': ?nextPlan,
        },
      );
      return _unwrapData(
        ApiResponse<TrainingLog>.fromJson(
            response.data ?? const {}, _parseTrainingLog),
      );
    });
  }

  // ── Curriculum ────────────────────────────────────────────────────────────

  /// `GET /cohorts/{cohortId}/curriculum` → curriculum items ordered by week /
  /// day / sort order (server-side). The tree is rebuilt client-side via
  /// [CurriculumItem.parentItemId].
  Future<List<CurriculumItem>> listCurriculum(int cohortId) async {
    return _guard(() async {
      final response = await _dio
          .get<Map<String, dynamic>>('/cohorts/$cohortId/curriculum');
      final envelope = ApiResponse<List<CurriculumItem>>.fromJson(
        response.data ?? const {},
        _parseCurriculumList,
      );
      return _unwrap(envelope) ?? const <CurriculumItem>[];
    });
  }

  /// `PATCH /curriculum/{itemId}` → the updated item. admin_ops / instructor
  /// only. Used to toggle completion and record actual hours.
  Future<CurriculumItem> updateCurriculumItem(
    int itemId, {
    String? topic,
    bool? isCompleted,
    int? actualHours,
    int? sortOrder,
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/curriculum/$itemId',
        data: {
          'topic': ?topic,
          'is_completed': ?isCompleted,
          'actual_hours': ?actualHours,
          'sort_order': ?sortOrder,
        },
      );
      return _unwrapData(
        ApiResponse<CurriculumItem>.fromJson(
            response.data ?? const {}, _parseCurriculumItem),
      );
    });
  }

  // ── Career postings ────────────────────────────────────────────────────────

  /// `GET /career-postings` → a page of postings (newest first), scoped to the
  /// caller's institution server-side.
  Future<CareerPostingPage> listCareerPostings({
    int page = 1,
    int size = 20,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/career-postings',
        queryParameters: {'page': page, 'size': size},
      );
      final envelope = ApiResponse<List<CareerPosting>>.fromJson(
        response.data ?? const {},
        _parseCareerPostingList,
      );
      final postings = _unwrap(envelope) ?? const <CareerPosting>[];
      final meta = envelope.meta;
      return CareerPostingPage(
        postings: postings,
        pagination: meta == null
            ? Pagination(page: page, size: size, total: postings.length)
            : Pagination.fromMeta(meta),
      );
    });
  }

  /// `POST /career-postings` → the created posting. admin_ops only (instructors
  /// receive a 403, surfaced as "접근 권한이 없습니다.").
  Future<CareerPosting> createCareerPosting({
    required String postingType,
    required String title,
    required String content,
    String? externalUrl,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? targetCohortIds,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/career-postings',
        data: {
          'posting_type': postingType,
          'title': title,
          'content': content,
          'external_url': ?externalUrl,
          if (startDate != null) 'start_date': _dateParam(startDate),
          if (endDate != null) 'end_date': _dateParam(endDate),
          'target_cohort_ids': ?targetCohortIds,
          'attachments': const <Map<String, dynamic>>[],
        },
      );
      return _unwrapData(
        ApiResponse<CareerPosting>.fromJson(
            response.data ?? const {}, _parseCareerPosting),
      );
    });
  }

  // ── Course evaluations ───────────────────────────────────────────────────

  /// `POST /classes/{classId}/evaluations` → the submission acknowledgement.
  /// STUDENT only (server returns 403 otherwise). Submitting twice for the same
  /// class yields `ALREADY_EVALUATED` (409), surfaced via [ClassException.code].
  ///
  /// The evaluation is always anonymous to the instructor: only [rating] (1–5)
  /// and an optional [comment] are sent; the student identity is never exposed
  /// back through the results endpoint.
  Future<EvaluationResult> submitEvaluation(
    int classId, {
    required int rating,
    String? comment,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/classes/$classId/evaluations',
        data: {
          'rating': rating,
          'comment': ?comment,
          'is_anonymous': true,
        },
      );
      return _unwrapData(
        ApiResponse<EvaluationResult>.fromJson(
            response.data ?? const {}, _parseEvaluationResult),
      );
    });
  }

  // ── Envelope / error plumbing ───────────────────────────────────────────

  /// Formats a [DateTime] as the `YYYY-MM-DD` string the backend expects.
  static String _dateParam(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static List<ClassSession> _parseClassList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) =>
          ClassSession.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static ClassSession _parseClass(Object? json) =>
      ClassSession.fromJson(json as Map<String, dynamic>);

  static TrainingLog _parseTrainingLog(Object? json) =>
      TrainingLog.fromJson(json as Map<String, dynamic>);

  static List<CurriculumItem> _parseCurriculumList(Object? json) =>
      (json as List)
          .whereType<Map>()
          .map((e) => CurriculumItem.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v))))
          .toList();

  static CurriculumItem _parseCurriculumItem(Object? json) =>
      CurriculumItem.fromJson(json as Map<String, dynamic>);

  static List<CareerPosting> _parseCareerPostingList(Object? json) =>
      (json as List)
          .whereType<Map>()
          .map((e) => CareerPosting.fromJson(
              e.map((k, v) => MapEntry(k.toString(), v))))
          .toList();

  static CareerPosting _parseCareerPosting(Object? json) =>
      CareerPosting.fromJson(json as Map<String, dynamic>);

  static EvaluationResult _parseEvaluationResult(Object? json) =>
      EvaluationResult.fromJson(json is Map<String, dynamic>
          ? json
          : const <String, dynamic>{'ok': true});

  /// Returns [ApiResponse.data] (may be null for empty list payloads) or throws
  /// a [ClassException] when the envelope carries an error.
  T? _unwrap<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      throw ClassException(response.error!.message, code: response.error!.code);
    }
    return response.data;
  }

  /// Like [_unwrap] but for single-object payloads that must not be null.
  T _unwrapData<T>(ApiResponse<T> response) {
    final data = _unwrap(response);
    if (data == null) throw const ClassException(_fallbackMessage);
    return data;
  }

  /// Runs [action], converting a [DioException] into a [ClassException] whose
  /// message + code are taken from the backend error envelope when present.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ClassException(
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
      // Some handlers nest the message under `detail`.
      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        final message = detail['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    }
    final status = e.response?.statusCode;
    if (status == 403) return '접근 권한이 없습니다.';
    if (status == 404) return '요청한 정보를 찾을 수 없습니다.';
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
      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        final code = detail['code'];
        if (code is String && code.isNotEmpty) return code;
      }
    }
    return null;
  }
}

/// Provides the [ClassRepository] wired to the shared [dioProvider].
final classRepositoryProvider = Provider<ClassRepository>(
  (ref) => ClassRepository(ref.watch(dioProvider)),
);
