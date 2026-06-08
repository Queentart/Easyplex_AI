import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/providers.dart';
import '../domain/admin_model.dart';

/// A page of users plus its pagination metadata.
class UserPage {
  const UserPage({required this.users, required this.pagination});

  final List<AdminUser> users;
  final Pagination pagination;
}

/// A page of cohorts plus its pagination metadata.
class CohortPage {
  const CohortPage({required this.cohorts, required this.pagination});

  final List<Cohort> cohorts;
  final Pagination pagination;
}

/// Thrown by [AdminRepository] when a users/cohorts call fails. Carries a
/// user-facing (Korean) [message] already extracted from the backend error
/// envelope, plus the backend error [code] for callers that branch on it.
class AdminException implements Exception {
  const AdminException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Calls the `/users` and `/cohorts` operations-team endpoints and parses the
/// backend response envelope.
///
/// This layer holds NO state and NO UI logic: it returns parsed domain models
/// or throws an [AdminException] with a clean message. Note the backend mounts
/// these routers with a trailing slash on the collection routes
/// (`GET/POST /users/`, `GET/POST /cohorts/`), so those exact paths are used.
class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  static const _fallbackMessage = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const _networkMessage = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';

  // ── Users ───────────────────────────────────────────────────────────────

  /// `GET /users/` → a page of users. Supports role / cohort / search filters.
  Future<UserPage> listUsers({
    String? role,
    int? cohortId,
    String? search,
    int page = 1,
    int size = 20,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/users/',
        queryParameters: {
          if (role != null && role.isNotEmpty) 'role': role,
          'cohort_id': ?cohortId,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page,
          'size': size,
        },
      );
      final envelope = ApiResponse<List<AdminUser>>.fromJson(
        response.data ?? const {},
        _parseUserList,
      );
      final users = _unwrap(envelope) ?? const <AdminUser>[];
      final meta = envelope.meta;
      return UserPage(
        users: users,
        pagination: meta == null
            ? Pagination(page: page, size: size, total: users.length)
            : Pagination.fromMeta(meta),
      );
    });
  }

  /// `POST /users/` → the created user. admin_ops only (enforced server-side).
  Future<AdminUser> createUser(AdminUserCreate body) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/users/',
        data: body.toJson(),
      );
      return _unwrapData(
        ApiResponse<AdminUser>.fromJson(response.data ?? const {}, _parseUser),
      );
    });
  }

  /// `PATCH /users/{id}` → the updated user (profile fields).
  Future<AdminUser> updateUser(
    int userId,
    Map<String, dynamic> changes,
  ) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/users/$userId',
        data: changes,
      );
      return _unwrapData(
        ApiResponse<AdminUser>.fromJson(response.data ?? const {}, _parseUser),
      );
    });
  }

  /// `PATCH /users/{id}/role {role, cohort_id?}` → the updated user.
  /// admin_ops only.
  Future<AdminUser> updateUserRole(
    int userId, {
    required String role,
    int? cohortId,
  }) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/users/$userId/role',
        data: {
          'role': role,
          'cohort_id': ?cohortId,
        },
      );
      return _unwrapData(
        ApiResponse<AdminUser>.fromJson(response.data ?? const {}, _parseUser),
      );
    });
  }

  /// `DELETE /users/{id}` → deactivates (soft) the user. admin_ops only.
  Future<void> deactivateUser(int userId) async {
    return _guard(() async {
      await _dio.delete<Map<String, dynamic>>('/users/$userId');
    });
  }

  /// `POST /users/{id}/password-reset` → a temporary password / email flag.
  /// admin_ops or tech_support.
  Future<PasswordResetResult> resetPassword(int userId) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/users/$userId/password-reset',
      );
      return _unwrapData(
        ApiResponse<PasswordResetResult>.fromJson(
          response.data ?? const {},
          (json) =>
              PasswordResetResult.fromJson(json as Map<String, dynamic>),
        ),
      );
    });
  }

  /// `POST /users/bulk-import` (multipart CSV upload) → an import summary.
  /// admin_ops only.
  ///
  /// The backend reads the uploaded file as UTF-8 CSV text; here we send the
  /// raw [bytes] as a multipart `file` field. File selection is the caller's
  /// concern (see the bulk-import seam in the presentation layer).
  Future<BulkImportResult> bulkImport({
    required String fileName,
    required List<int> bytes,
  }) async {
    return _guard(() async {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/users/bulk-import',
        data: form,
      );
      return _unwrapData(
        ApiResponse<BulkImportResult>.fromJson(
          response.data ?? const {},
          (json) => BulkImportResult.fromJson(json as Map<String, dynamic>),
        ),
      );
    });
  }

  // ── Cohorts ───────────────────────────────────────────────────────────────

  /// `GET /cohorts/` → a page of cohorts. Optional [status] filter.
  Future<CohortPage> listCohorts({
    String? status,
    int page = 1,
    int size = 50,
  }) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/cohorts/',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          'page': page,
          'size': size,
        },
      );
      final envelope = ApiResponse<List<Cohort>>.fromJson(
        response.data ?? const {},
        _parseCohortList,
      );
      final cohorts = _unwrap(envelope) ?? const <Cohort>[];
      final meta = envelope.meta;
      return CohortPage(
        cohorts: cohorts,
        pagination: meta == null
            ? Pagination(page: page, size: size, total: cohorts.length)
            : Pagination.fromMeta(meta),
      );
    });
  }

  /// `GET /cohorts/{id}` → a single cohort with member counts.
  Future<Cohort> getCohort(int cohortId) async {
    return _guard(() async {
      final response =
          await _dio.get<Map<String, dynamic>>('/cohorts/$cohortId');
      return _unwrapData(
        ApiResponse<Cohort>.fromJson(response.data ?? const {}, _parseCohort),
      );
    });
  }

  /// `POST /cohorts/` → the created cohort. admin_ops only.
  Future<Cohort> createCohort(CohortCreate body) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/cohorts/',
        data: body.toJson(),
      );
      return _unwrapData(
        ApiResponse<Cohort>.fromJson(response.data ?? const {}, _parseCohort),
      );
    });
  }

  /// `PATCH /cohorts/{id}` → the updated cohort. admin_ops only.
  Future<Cohort> updateCohort(int cohortId, CohortUpdate body) async {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/cohorts/$cohortId',
        data: body.toJson(),
      );
      return _unwrapData(
        ApiResponse<Cohort>.fromJson(response.data ?? const {}, _parseCohort),
      );
    });
  }

  /// `DELETE /cohorts/{id}` → archives the cohort. admin_ops only.
  Future<void> archiveCohort(int cohortId) async {
    return _guard(() async {
      await _dio.delete<Map<String, dynamic>>('/cohorts/$cohortId');
    });
  }

  /// `GET /cohorts/{id}/members` → the cohort's members. Optional [role] filter.
  Future<List<CohortMember>> listMembers(int cohortId, {String? role}) async {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/cohorts/$cohortId/members',
        queryParameters: {
          if (role != null && role.isNotEmpty) 'role': role,
        },
      );
      final envelope = ApiResponse<List<CohortMember>>.fromJson(
        response.data ?? const {},
        _parseMemberList,
      );
      return _unwrap(envelope) ?? const <CohortMember>[];
    });
  }

  /// `POST /cohorts/{id}/members {user_ids, role}` → an add summary.
  Future<MembersAddResult> addMembers(
    int cohortId, {
    required List<int> userIds,
    required String role,
  }) async {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/cohorts/$cohortId/members',
        data: {'user_ids': userIds, 'role': role},
      );
      return _unwrapData(
        ApiResponse<MembersAddResult>.fromJson(
          response.data ?? const {},
          (json) => MembersAddResult.fromJson(json as Map<String, dynamic>),
        ),
      );
    });
  }

  /// `DELETE /cohorts/{id}/members/{userId}` → removes a member. admin_ops only.
  Future<void> removeMember(int cohortId, int userId) async {
    return _guard(() async {
      await _dio.delete<Map<String, dynamic>>(
        '/cohorts/$cohortId/members/$userId',
      );
    });
  }

  // ── Envelope / parse plumbing ───────────────────────────────────────────

  static List<AdminUser> _parseUserList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) =>
          AdminUser.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static AdminUser _parseUser(Object? json) =>
      AdminUser.fromJson(json as Map<String, dynamic>);

  static List<Cohort> _parseCohortList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) => Cohort.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  static Cohort _parseCohort(Object? json) =>
      Cohort.fromJson(json as Map<String, dynamic>);

  static List<CohortMember> _parseMemberList(Object? json) => (json as List)
      .whereType<Map>()
      .map((e) =>
          CohortMember.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
      .toList();

  /// Returns [ApiResponse.data] (may be null for empty list payloads) or throws
  /// an [AdminException] when the envelope carries an error.
  T? _unwrap<T>(ApiResponse<T> response) {
    if (!response.isSuccess) {
      throw AdminException(response.error!.message, code: response.error!.code);
    }
    return response.data;
  }

  /// Like [_unwrap] but for single-object payloads that must not be null.
  T _unwrapData<T>(ApiResponse<T> response) {
    final data = _unwrap(response);
    if (data == null) throw const AdminException(_fallbackMessage);
    return data;
  }

  /// Runs [action], converting a [DioException] into an [AdminException] whose
  /// message is taken from the backend error envelope when present.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw AdminException(
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
    // Fall back to friendly messages for known status codes.
    final status = e.response?.statusCode;
    if (status == 403) return '접근 권한이 없습니다.';
    if (status == 422) return '입력값을 확인해주세요.';
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

/// Provides the [AdminRepository] wired to the shared [dioProvider].
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(dioProvider)),
);
