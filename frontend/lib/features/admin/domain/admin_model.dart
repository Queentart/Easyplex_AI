/// Domain models for the operations-team user & cohort management feature.
///
/// These mirror the backend `app/schemas/user.py` and `app/schemas/cohort.py`
/// payloads. The user shape reuses the shared [AppUser] elsewhere; here we keep
/// the richer admin-list/detail DTOs the `/users` endpoints return
/// (`UserOut` / `UserListItem`) since they carry `is_active`, `created_at`, etc.
library;

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
bool _asBool(Object? v) => v is bool ? v : v == true || v == 'true';
String _asString(Object? v) => (v ?? '').toString();
String? _asStringOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

DateTime? _asDate(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// A user row as returned by `GET /users` (`UserListItem`) and enriched by
/// `GET /users/{id}` (`UserOut`). The list endpoint only populates a subset of
/// fields, so the detail-only fields are nullable.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.cohortId,
    this.nickname,
    this.phone,
    this.institutionId,
    this.lastLoginAt,
    this.createdAt,
  });

  final int id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final int? cohortId;
  final String? nickname;
  final String? phone;
  final int? institutionId;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: _asInt(json['id']) ?? 0,
      email: _asString(json['email']),
      name: _asString(json['name']),
      role: _asString(json['role']),
      isActive: _asBool(json['is_active']),
      cohortId: _asInt(json['cohort_id']),
      nickname: _asStringOrNull(json['nickname']),
      phone: _asStringOrNull(json['phone']),
      institutionId: _asInt(json['institution_id']),
      lastLoginAt: _asDate(json['last_login_at']),
      createdAt: _asDate(json['created_at']),
    );
  }
}

/// Request body for `POST /users` (`UserCreate`).
class AdminUserCreate {
  const AdminUserCreate({
    required this.email,
    required this.name,
    required this.role,
    this.cohortId,
    this.phone,
    this.sendInvitation = false,
  });

  final String email;
  final String name;
  final String role;
  final int? cohortId;
  final String? phone;
  final bool sendInvitation;

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'role': role,
        if (cohortId != null) 'cohort_id': cohortId,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        'send_invitation': sendInvitation,
      };
}

/// Result of `POST /users/bulk-import` (`BulkImportResult`).
class BulkImportResult {
  const BulkImportResult({
    required this.imported,
    required this.failed,
    required this.errors,
  });

  final int imported;
  final int failed;
  final List<Map<String, dynamic>> errors;

  factory BulkImportResult.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['errors'];
    return BulkImportResult(
      imported: _asInt(json['imported']) ?? 0,
      failed: _asInt(json['failed']) ?? 0,
      errors: rawErrors is List
          ? rawErrors
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList()
          : const [],
    );
  }
}

/// Result of `POST /users/{id}/password-reset` (`PasswordResetResult`).
class PasswordResetResult {
  const PasswordResetResult({this.temporaryPassword, this.emailSent = false});

  final String? temporaryPassword;
  final bool emailSent;

  factory PasswordResetResult.fromJson(Map<String, dynamic> json) {
    return PasswordResetResult(
      temporaryPassword: _asStringOrNull(json['temporary_password']),
      emailSent: _asBool(json['email_sent']),
    );
  }
}

/// A cohort as returned by `GET /cohorts` (`CohortOut`) and enriched by
/// `GET /cohorts/{id}` (`CohortDetail` adds the member counts).
class Cohort {
  const Cohort({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    this.institutionId,
    this.startDate,
    this.endDate,
    this.totalHours,
    this.leaveAllowanceDays,
    this.description,
    this.createdAt,
    this.studentCount = 0,
    this.instructorCount = 0,
  });

  final int id;
  final String name;
  final String code;
  final String status;
  final int? institutionId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? totalHours;

  /// Configured leave allowance (days) for the cohort, or null when 미설정.
  final int? leaveAllowanceDays;
  final String? description;
  final DateTime? createdAt;
  final int studentCount;
  final int instructorCount;

  factory Cohort.fromJson(Map<String, dynamic> json) {
    return Cohort(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['name']),
      code: _asString(json['code']),
      status: _asString(json['status']),
      institutionId: _asInt(json['institution_id']),
      startDate: _asDate(json['start_date']),
      endDate: _asDate(json['end_date']),
      totalHours: _asInt(json['total_hours']),
      leaveAllowanceDays: _asInt(json['leave_allowance_days']),
      description: _asStringOrNull(json['description']),
      createdAt: _asDate(json['created_at']),
      studentCount: _asInt(json['student_count']) ?? 0,
      instructorCount: _asInt(json['instructor_count']) ?? 0,
    );
  }
}

/// Request body for `POST /cohorts` (`CohortCreate`). Dates are serialized as
/// `yyyy-MM-dd` (date only) to match the backend `date` fields.
class CohortCreate {
  const CohortCreate({
    required this.name,
    required this.code,
    required this.startDate,
    required this.endDate,
    this.totalHours,
    this.leaveAllowanceDays,
    this.description,
  });

  final String name;
  final String code;
  final DateTime startDate;
  final DateTime endDate;
  final int? totalHours;

  /// Leave allowance (days); omitted when null (기수 한도 미설정).
  final int? leaveAllowanceDays;
  final String? description;

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        if (totalHours != null) 'total_hours': totalHours,
        if (leaveAllowanceDays != null)
          'leave_allowance_days': leaveAllowanceDays,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}

/// Request body for `PATCH /cohorts/{id}` (`CohortUpdate`). Only the non-null
/// fields are sent so the caller can do partial updates.
class CohortUpdate {
  const CohortUpdate({
    this.name,
    this.startDate,
    this.endDate,
    this.totalHours,
    this.leaveAllowanceDays,
    this.description,
    this.status,
  });

  final String? name;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? totalHours;

  /// Leave allowance (days). Only sent when non-null so an unedited update
  /// leaves the existing value untouched (partial update semantics).
  final int? leaveAllowanceDays;
  final String? description;
  final String? status;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (startDate != null) 'start_date': _dateOnly(startDate!),
        if (endDate != null) 'end_date': _dateOnly(endDate!),
        if (totalHours != null) 'total_hours': totalHours,
        if (leaveAllowanceDays != null)
          'leave_allowance_days': leaveAllowanceDays,
        if (description != null) 'description': description,
        if (status != null) 'status': status,
      };
}

/// A member of a cohort. The backend `GET /cohorts/{id}/members` returns the
/// member's user shape; we parse the fields shared with [AdminUser].
class CohortMember {
  const CohortMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final bool isActive;

  factory CohortMember.fromJson(Map<String, dynamic> json) {
    return CohortMember(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['name']),
      email: _asString(json['email']),
      role: _asString(json['role']),
      isActive: json['is_active'] == null ? true : _asBool(json['is_active']),
    );
  }
}

/// Result of `POST /cohorts/{id}/members` (`MembersAddResult`).
class MembersAddResult {
  const MembersAddResult({required this.added, required this.skipped});

  final int added;
  final int skipped;

  factory MembersAddResult.fromJson(Map<String, dynamic> json) {
    return MembersAddResult(
      added: _asInt(json['added']) ?? 0,
      skipped: _asInt(json['skipped']) ?? 0,
    );
  }
}

String _dateOnly(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// Korean label for a backend role code (used across admin screens).
String roleLabelKo(String role) {
  switch (role) {
    case 'admin_ops':
      return '운영팀';
    case 'tech_support':
      return '기술지원';
    case 'instructor':
      return '강사';
    case 'student':
      return '수강생';
    default:
      return role;
  }
}

/// Korean label for a cohort status code.
String cohortStatusLabelKo(String status) {
  switch (status) {
    case 'active':
      return '진행중';
    case 'planned':
      return '예정';
    case 'completed':
      return '종료';
    case 'archived':
      return '보관';
    default:
      return status;
  }
}
