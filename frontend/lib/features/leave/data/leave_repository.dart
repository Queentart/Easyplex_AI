import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/leave_model.dart';

/// Thrown by [LeaveRepository] when a leave-request call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend [code] for callers that want to branch on it
/// (e.g. `DUPLICATE_REQUEST`, `FORBIDDEN`).
class LeaveException implements Exception {
  const LeaveException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// A page of leave requests plus pagination metadata.
class LeaveRequestPage {
  const LeaveRequestPage({required this.items, this.pagination});

  final List<LeaveRequest> items;
  final Pagination? pagination;
}

/// Calls the `/leave-requests/*` endpoints and parses the backend envelope.
///
/// This layer holds NO state and NO UI logic: it returns parsed DTOs or throws
/// a [LeaveException] with a clean message. Backend is the source of truth
/// (see backend `app/api/v1/leave_requests.py`).
class LeaveRepository {
  LeaveRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  /// `GET /leave-requests` → a page of requests.
  ///
  /// Students implicitly see only their own requests (server-side RLS). The
  /// optional [status] / [type] / [cohortId] filters map straight onto the
  /// backend query params.
  Future<LeaveRequestPage> list({
    LeaveStatus? status,
    LeaveType? type,
    int? cohortId,
    int page = 1,
    int size = 20,
  }) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/leave-requests/',
        queryParameters: {
          if (status != null) 'status': status.code,
          if (type != null) 'type': type.code,
          'cohort_id': ?cohortId,
          'page': page,
          'size': size,
        },
      );
      final envelope = ApiResponse<List<LeaveRequest>>.fromJson(
        response.data ?? const {},
        (json) => (json as List<dynamic>)
            .map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      final items = _unwrap(envelope);
      return LeaveRequestPage(
        items: items,
        pagination:
            envelope.meta == null ? null : Pagination.fromMeta(envelope.meta!),
      );
    });
  }

  /// `GET /leave-requests/balance` → the CURRENT user's leave allowance/usage.
  ///
  /// When the cohort has no allowance configured the backend returns
  /// `has_allowance: false` with null `allowance_days` / `remaining_days`
  /// (기수 한도 미설정).
  Future<LeaveBalance> getBalance() {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/leave-requests/balance');
      final envelope = ApiResponse<LeaveBalance>.fromJson(
        response.data ?? const {},
        (json) => LeaveBalance.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `GET /leave-requests/{id}` → a single request (403 if not the owner).
  Future<LeaveRequest> getById(int id) {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/leave-requests/$id');
      final envelope = ApiResponse<LeaveRequest>.fromJson(
        response.data ?? const {},
        (json) => LeaveRequest.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `POST /leave-requests` → the created request.
  Future<LeaveRequest> create(LeaveRequestCreate body) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/leave-requests/',
        data: body.toJson(),
      );
      final envelope = ApiResponse<LeaveRequest>.fromJson(
        response.data ?? const {},
        (json) => LeaveRequest.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `DELETE /leave-requests/{id}` → cancels a pending request (student own).
  Future<void> cancel(int id) {
    return _guard(() async {
      await _dio.delete<Map<String, dynamic>>('/leave-requests/$id');
    });
  }

  // ── Operations-team actions (modelled for completeness; not used by the ──
  // ── student screens, which only create / list / view). ──────────────────

  /// `POST /leave-requests/{id}/approve {review_comment}` (admin_ops only).
  Future<LeaveRequest> approve(int id, String reviewComment) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/leave-requests/$id/approve',
        data: {'review_comment': reviewComment},
      );
      final envelope = ApiResponse<LeaveRequest>.fromJson(
        response.data ?? const {},
        (json) => LeaveRequest.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  /// `POST /leave-requests/{id}/reject {review_comment}` (admin_ops only).
  Future<LeaveRequest> reject(int id, String reviewComment) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/leave-requests/$id/reject',
        data: {'review_comment': reviewComment},
      );
      final envelope = ApiResponse<LeaveRequest>.fromJson(
        response.data ?? const {},
        (json) => LeaveRequest.fromJson(json as Map<String, dynamic>),
      );
      return _unwrap(envelope);
    });
  }

  // ── Supporting-document upload (presign → S3 PUT) ───────────────────────

  /// Uploads a supporting document for a leave request via the two-step
  /// presigned-URL flow and returns the [UploadedFile] reference to embed in
  /// the create payload:
  ///
  ///   1. `POST /files/presign {purpose, file_name, content_type}`
  ///      → `{upload_url, file_key}`
  ///   2. `PUT upload_url` with the raw [bytes] (direct object-storage upload)
  ///
  /// The returned [UploadedFile.fileKey] is what `POST /leave-requests` stores.
  Future<UploadedFile> uploadEvidence({
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) {
    return _guard(() async {
      // 1. Ask the backend for a presigned upload URL + storage key.
      final presignResponse = await _dio.post<Map<String, dynamic>>(
        '/files/presign',
        data: {
          'purpose': 'leave_evidence',
          'context': const <String, dynamic>{},
          'file_name': fileName,
          'content_type': contentType,
        },
      );
      final presign = ApiResponse<_PresignResult>.fromJson(
        presignResponse.data ?? const {},
        (json) => _PresignResult.fromJson(json as Map<String, dynamic>),
      );
      final result = _unwrap(presign);

      // 2. PUT the bytes straight to object storage. This URL is pre-signed,
      //    so it must NOT carry the app's Authorization header.
      await Dio().put<void>(
        result.uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );

      return UploadedFile(
        fileKey: result.fileKey,
        fileName: fileName,
        fileSize: bytes.length,
      );
    });
  }

  /// Returns [ApiResponse.data] or throws a [LeaveException] when the envelope
  /// carries an error or an empty `data` payload.
  T _unwrap<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      throw LeaveException(
        response.error!.message,
        code: response.error!.code,
      );
    }
    final data = response.data;
    if (data == null) {
      throw const LeaveException(_fallbackMessage);
    }
    return data;
  }

  /// Runs [action], converting a [DioException] into a [LeaveException] whose
  /// message + code are taken from the backend error envelope when present.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      final (message, code) = _errorFromDioException(e);
      throw LeaveException(message, code: code);
    }
  }

  (String message, String? code) _errorFromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return (_networkMessage, null);
      default:
        break;
    }

    // 403 fallback when the backend gives no structured message.
    if (e.response?.statusCode == 403) {
      return ('접근 권한이 없습니다.', 'FORBIDDEN');
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        final code = error['code'];
        if (message is String && message.isNotEmpty) {
          return (message, code is String ? code : null);
        }
      }
    }
    return (_fallbackMessage, null);
  }
}

/// Internal parse helper for the `/files/presign` response.
class _PresignResult {
  const _PresignResult({required this.uploadUrl, required this.fileKey});

  final String uploadUrl;
  final String fileKey;

  factory _PresignResult.fromJson(Map<String, dynamic> json) => _PresignResult(
        uploadUrl: (json['upload_url'] ?? '').toString(),
        fileKey: (json['file_key'] ?? '').toString(),
      );
}

/// Provides the [LeaveRepository] wired to the shared [dioProvider].
final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => LeaveRepository(ref.watch(dioProvider)),
);
