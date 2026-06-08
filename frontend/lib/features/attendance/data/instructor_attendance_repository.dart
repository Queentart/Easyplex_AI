import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/attendance_model.dart';
import 'attendance_repository.dart';

/// Calls the instructor-facing `/attendance/*` endpoints and parses the
/// response envelope.
///
/// This is a SEPARATE repository from the student-facing [AttendanceRepository]
/// (F2): it owns the write paths an instructor uses to manage a whole cohort —
///   - `GET  /attendance/`            (cohort-scoped record list)
///   - `GET  /attendance/summary`     (cohort or per-student summary)
///   - `PATCH /attendance/{id}`       (manual correction; reason required)
///   - `POST /attendance/notify`      (notify selected students)
///
/// Backend is the source of truth (`backend/app/api/v1/attendance.py`). The
/// PATCH body field is `note` and the backend enforces `min_length=1`, so the
/// correction reason is mandatory.
///
/// Like the F2 repository, this layer holds NO state and NO UI logic: it
/// returns parsed DTOs ([AttendanceRecord] / [AttendanceSummary] /
/// [AttendancePage]) or throws an [AttendanceException] carrying a clean
/// (Korean) message. 401 refresh is handled transparently by the
/// `AuthInterceptor` on the shared Dio.
class InstructorAttendanceRepository {
  InstructorAttendanceRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';
  static const _forbiddenMessage = '접근 권한이 없습니다.';

  /// `GET /attendance/` for a whole cohort → one [AttendancePage] of records.
  ///
  /// An optional [fromDate]/[toDate] range (each `YYYY-MM-DD`) scopes the
  /// records to a period (e.g. a single month) server-side so the roster view
  /// aggregates only the selected period.
  Future<AttendancePage> getCohortRecords({
    required int cohortId,
    String? type,
    String? fromDate,
    String? toDate,
    int page = 1,
    int size = 100,
  }) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/',
        queryParameters: _query({
          'cohort_id': cohortId,
          'type': type,
          'from_date': fromDate,
          'to_date': toDate,
          'page': page,
          'size': size,
        }),
      );
      final json = response.data ?? const {};

      final error = json['error'];
      if (error is Map<String, dynamic>) {
        final parsed = ApiError.fromJson(error);
        throw AttendanceException(parsed.message, code: parsed.code);
      }

      final rawList = json['data'];
      final records = <AttendanceRecord>[];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            records.add(AttendanceRecord.fromJson(item));
          }
        }
      }

      final rawMeta = json['meta'];
      final pagination = rawMeta is Map<String, dynamic>
          ? Pagination.fromMeta(ApiMeta.fromJson(rawMeta))
          : null;

      return AttendancePage(records: records, pagination: pagination);
    });
  }

  /// `GET /attendance/summary` for a cohort → aggregate [AttendanceSummary].
  Future<AttendanceSummary> getCohortSummary({required int cohortId}) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/summary',
        queryParameters: _query({'cohort_id': cohortId}),
      );
      final envelope = ApiResponse<AttendanceSummary>.fromJson(
        response.data ?? const {},
        (json) => AttendanceSummary.fromJson(json as Map<String, dynamic>),
      );
      if (!envelope.isSuccess) {
        throw AttendanceException(
          envelope.error!.message,
          code: envelope.error!.code,
        );
      }
      final data = envelope.data;
      if (data == null) throw const AttendanceException(_fallbackMessage);
      return data;
    });
  }

  /// `PATCH /attendance/{recordId}` → corrected [AttendanceRecord].
  ///
  /// Manual correction by an instructor. The backend requires a non-empty
  /// [reason] (serialized as `note`, `min_length=1`); callers must validate it
  /// before calling.
  Future<AttendanceRecord> correctRecord({
    required int recordId,
    required AttendanceType type,
    required String reason,
  }) {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/attendance/$recordId',
        data: {'type': _typeCode(type), 'note': reason},
      );
      final envelope = ApiResponse<AttendanceRecord>.fromJson(
        response.data ?? const {},
        (json) => AttendanceRecord.fromJson(json as Map<String, dynamic>),
      );
      if (!envelope.isSuccess) {
        throw AttendanceException(
          envelope.error!.message,
          code: envelope.error!.code,
        );
      }
      final data = envelope.data;
      if (data == null) throw const AttendanceException(_fallbackMessage);
      return data;
    });
  }

  /// `POST /attendance/notify` → number of notifications dispatched.
  ///
  /// Notifies [userIds] in [cohortId] with [message] (e.g. an absence alert).
  Future<int> notify({
    required int cohortId,
    required List<int> userIds,
    required String message,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/attendance/notify',
        data: {
          'cohort_id': cohortId,
          'user_ids': userIds,
          'message': message,
        },
      );
      final json = response.data ?? const {};

      final error = json['error'];
      if (error is Map<String, dynamic>) {
        final parsed = ApiError.fromJson(error);
        throw AttendanceException(parsed.message, code: parsed.code);
      }

      final data = json['data'];
      if (data is Map<String, dynamic>) {
        final sent = data['sent'];
        if (sent is num) return sent.toInt();
      }
      return userIds.length;
    });
  }

  /// Maps an [AttendanceType] back to the backend wire code used by PATCH.
  ///
  /// The F2 [AttendanceType] enum only ships `fromCode`/`label`; this is the
  /// inverse, kept local so the shared model is not modified.
  String _typeCode(AttendanceType type) {
    switch (type) {
      case AttendanceType.present:
        return 'present';
      case AttendanceType.late:
        return 'late';
      case AttendanceType.absent:
        return 'absent';
      case AttendanceType.earlyLeave:
        return 'early_leave';
      case AttendanceType.medical:
        return 'medical';
      case AttendanceType.official:
        return 'official';
      case AttendanceType.unknown:
        return 'present';
    }
  }

  /// Drops null-valued query params so they don't serialize as `key=`.
  Map<String, dynamic> _query(Map<String, dynamic> params) {
    params.removeWhere((_, value) => value == null);
    return params;
  }

  /// Runs [action], converting a [DioException] into an [AttendanceException]
  /// whose message comes from the backend error envelope when present.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw AttendanceException(
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

    if (e.response?.statusCode == 403) return _forbiddenMessage;

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

/// Provides the [InstructorAttendanceRepository] wired to the shared
/// [dioProvider].
final instructorAttendanceRepositoryProvider =
    Provider<InstructorAttendanceRepository>(
  (ref) => InstructorAttendanceRepository(ref.watch(dioProvider)),
);
