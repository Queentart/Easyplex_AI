import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/admin_attendance_model.dart';
import '../domain/attendance_model.dart';
import 'attendance_repository.dart';

/// Calls the OPERATIONS-TEAM (admin_ops) `/attendance/*` management endpoints
/// and parses the response envelope.
///
/// This is a SEPARATE repository from the student-facing [AttendanceRepository]
/// (F2) and the instructor [InstructorAttendanceRepository] (F3): it owns the
/// ops-only management + CSV import paths
/// (`backend/app/api/v1/attendance.py`, all `require_roles("admin_ops")`):
///   - `GET  /attendance/`                       (ALL cohorts, cohort filter, paginated)
///   - `POST /attendance/import`                 (CSV upload — dry-run preview / confirm)
///   - `GET  /attendance/imports`                (import history, paginated)
///   - `POST /attendance/imports/{batch}/rollback` (undo a batch)
///
/// Backend is the source of truth. Two contract details worth noting:
///   - `POST /attendance/import` takes the CSV as a multipart `file` field and
///     `cohort_id` + `dry_run` as QUERY params (not body fields). With
///     `dry_run=true` nothing is written; the same [ImportResult] shape is
///     returned for both phases, carrying `batch_id` + a free-form `preview`.
///   - rollback targets the string `batch_id` returned by a prior import.
///
/// Like the sibling repositories this layer holds NO state and NO UI logic: it
/// returns parsed DTOs or throws an [AttendanceException] carrying a clean
/// (Korean) message. 401 refresh is handled transparently by the
/// `AuthInterceptor` on the shared Dio.
class AdminAttendanceRepository {
  AdminAttendanceRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';
  static const _forbiddenMessage = '접근 권한이 없습니다.';

  /// `GET /attendance/` across all cohorts (optionally filtered by [cohortId],
  /// [type], and/or a [fromDate]/[toDate] range, each `YYYY-MM-DD`) → one
  /// [AttendancePage] of records (newest first).
  Future<AttendancePage> getRecords({
    int? cohortId,
    String? type,
    String? fromDate,
    String? toDate,
    int page = 1,
    int size = 50,
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

      _throwIfError(json);

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

  /// `POST /attendance/import` → an [ImportResult].
  ///
  /// Set [dryRun] true to preview the effect WITHOUT writing (the returned
  /// [ImportResult.preview] / counts describe what *would* happen); call again
  /// with [dryRun] false using the same [upload] to commit. The CSV is sent as
  /// a multipart `file`; [cohortId] + [dryRun] go on the query string to match
  /// the FastAPI signature.
  Future<ImportResult> importCsv({
    required CsvUpload upload,
    required int cohortId,
    required bool dryRun,
  }) {
    return _guard(() async {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          upload.bytes,
          filename: upload.fileName,
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/attendance/import',
        data: formData,
        queryParameters: {'cohort_id': cohortId, 'dry_run': dryRun},
      );
      final envelope = ApiResponse<ImportResult>.fromJson(
        response.data ?? const {},
        (json) => ImportResult.fromJson(json as Map<String, dynamic>),
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

  /// `GET /attendance/imports` → one page of [ImportLog] history (newest first).
  Future<ImportLogPage> getImportHistory({
    int? cohortId,
    String? status,
    int page = 1,
    int size = 20,
  }) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/imports',
        queryParameters: _query({
          'cohort_id': cohortId,
          'status': status,
          'page': page,
          'size': size,
        }),
      );
      final json = response.data ?? const {};

      _throwIfError(json);

      final rawList = json['data'];
      final logs = <ImportLog>[];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            logs.add(ImportLog.fromJson(item));
          }
        }
      }

      final rawMeta = json['meta'];
      final pagination = rawMeta is Map<String, dynamic>
          ? Pagination.fromMeta(ApiMeta.fromJson(rawMeta))
          : null;

      return ImportLogPage(logs: logs, pagination: pagination);
    });
  }

  /// `POST /attendance/imports/{batchId}/rollback` → deletes every record the
  /// batch created and marks the log `rolled_back`. Throws an
  /// [AttendanceException] (e.g. `ALREADY_ROLLED_BACK`) on failure.
  Future<void> rollbackImport(String batchId) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/attendance/imports/$batchId/rollback',
      );
      _throwIfError(response.data ?? const {});
    });
  }

  /// Throws an [AttendanceException] when the envelope carries an `error` block.
  void _throwIfError(Map<String, dynamic> json) {
    final error = json['error'];
    if (error is Map<String, dynamic>) {
      final parsed = ApiError.fromJson(error);
      throw AttendanceException(parsed.message, code: parsed.code);
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

/// One page of import-history logs plus its pagination metadata.
class ImportLogPage {
  const ImportLogPage({required this.logs, this.pagination});

  final List<ImportLog> logs;
  final Pagination? pagination;
}

/// Provides the [AdminAttendanceRepository] wired to the shared [dioProvider].
final adminAttendanceRepositoryProvider = Provider<AdminAttendanceRepository>(
  (ref) => AdminAttendanceRepository(ref.watch(dioProvider)),
);
