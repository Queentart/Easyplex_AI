import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/attendance_model.dart';

/// Thrown by [AttendanceRepository] when an attendance call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend error [code] for callers that want to branch.
class AttendanceException implements Exception {
  const AttendanceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// One page of attendance records plus its pagination metadata.
class AttendancePage {
  const AttendancePage({required this.records, this.pagination});

  final List<AttendanceRecord> records;
  final Pagination? pagination;
}

/// Calls the `/attendance/*` read endpoints and parses the response envelope.
///
/// This layer holds NO state and NO UI logic: it returns parsed DTOs
/// ([AttendanceSummary] / [AttendancePage]) or throws an [AttendanceException]
/// with a clean message. 401 refresh is handled transparently by the
/// [AuthInterceptor] on the shared Dio.
class AttendanceRepository {
  AttendanceRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';
  static const _forbiddenMessage = '접근 권한이 없습니다.';

  /// `GET /attendance/summary` → [AttendanceSummary] for the current student.
  ///
  /// Students are scoped to their own records server-side, so [cohortId] /
  /// [userId] are optional (the backend defaults to the caller's cohort).
  Future<AttendanceSummary> getSummary({int? cohortId, int? userId}) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/summary',
        queryParameters: _query({'cohort_id': cohortId, 'user_id': userId}),
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

  /// `GET /attendance/` → one [AttendancePage] of records (newest first).
  ///
  /// [fromDate] / [toDate] (each `YYYY-MM-DD`) map to the backend `from_date` /
  /// `to_date` query params, letting the caller scope records to a date range
  /// (e.g. a single month) server-side instead of fetching everything.
  Future<AttendancePage> getRecords({
    int? cohortId,
    int? userId,
    String? type,
    String? fromDate,
    String? toDate,
    int page = 1,
    int size = 50,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/attendance/',
        queryParameters: _query({
          'cohort_id': cohortId,
          'user_id': userId,
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

  /// Drops null-valued query params so they don't serialize as `key=`.
  Map<String, dynamic> _query(Map<String, dynamic> params) {
    params.removeWhere((_, value) => value == null);
    return params;
  }

  /// Runs [action], converting a [DioException] into an [AttendanceException]
  /// whose message is taken from the backend error envelope when present.
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

/// Provides the [AttendanceRepository] wired to the shared [dioProvider].
final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(ref.watch(dioProvider)),
);
