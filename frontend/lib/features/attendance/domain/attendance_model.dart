/// Domain models for the attendance feature.
///
/// These mirror the backend response shapes exactly (see
/// `backend/app/schemas/attendance.py`):
///   - [AttendanceSummary] ← `AttendanceSummary` (GET /attendance/summary)
///   - [AttendanceRecord]  ← `AttendanceOut`     (GET /attendance/)
///
/// This layer holds NO business logic. In particular the
/// "3 지각 = 1 결석" conversion is computed by the server and surfaced as
/// [AttendanceSummary.computedAbsent]; the client only displays it.
library;

/// Canonical attendance type codes returned by the backend `type` field.
///
/// Mirrors `ATTENDANCE_TYPES` in `backend/app/services/attendance.py`.
enum AttendanceType {
  present,
  late,
  absent,
  earlyLeave,
  medical,
  official,
  unknown;

  /// Maps a backend code (`"present"`, `"early_leave"`, …) to the enum.
  static AttendanceType fromCode(String? code) {
    switch (code) {
      case 'present':
        return AttendanceType.present;
      case 'late':
        return AttendanceType.late;
      case 'absent':
        return AttendanceType.absent;
      case 'early_leave':
        return AttendanceType.earlyLeave;
      case 'medical':
        return AttendanceType.medical;
      case 'official':
        return AttendanceType.official;
      default:
        return AttendanceType.unknown;
    }
  }

  /// Backend wire code for this type (inverse of [fromCode]).
  ///
  /// [unknown] has no canonical backend code; it maps to `present` so callers
  /// that round-trip a corrected record never send an invalid value.
  String get code {
    switch (this) {
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

  /// Korean user-facing label for the type.
  String get label {
    switch (this) {
      case AttendanceType.present:
        return '출석';
      case AttendanceType.late:
        return '지각';
      case AttendanceType.absent:
        return '결석';
      case AttendanceType.earlyLeave:
        return '조퇴';
      case AttendanceType.medical:
        return '병결';
      case AttendanceType.official:
        return '공결';
      case AttendanceType.unknown:
        return '미정';
    }
  }
}

/// Aggregated attendance summary for one student in one cohort.
///
/// Source: `GET /attendance/summary` → envelope `data`.
class AttendanceSummary {
  const AttendanceSummary({
    required this.cohortId,
    required this.totalDays,
    required this.present,
    required this.late,
    required this.absent,
    required this.earlyLeave,
    required this.medical,
    required this.official,
    required this.computedAbsent,
    required this.attendanceRate,
    this.userId,
  });

  final int? userId;
  final int cohortId;
  final int totalDays;
  final int present;
  final int late;
  final int absent;
  final int earlyLeave;
  final int medical;
  final int official;

  /// Server-derived absence count: `absent + (late ~/ 3)`.
  /// DISPLAY ONLY — never recomputed on the client.
  final int computedAbsent;

  /// Attendance rate as a 0.0–1.0 fraction (server already rounds to 4dp).
  final double attendanceRate;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);
    double asDouble(Object? v) =>
        v is double ? v : (v is num ? v.toDouble() : 0.0);
    return AttendanceSummary(
      userId: json['user_id'] is num ? (json['user_id'] as num).toInt() : null,
      cohortId: asInt(json['cohort_id']),
      totalDays: asInt(json['total_days']),
      present: asInt(json['present']),
      late: asInt(json['late']),
      absent: asInt(json['absent']),
      earlyLeave: asInt(json['early_leave']),
      medical: asInt(json['medical']),
      official: asInt(json['official']),
      computedAbsent: asInt(json['computed_absent']),
      attendanceRate: asDouble(json['attendance_rate']),
    );
  }
}

/// A single per-date attendance record.
///
/// Source: `GET /attendance/` → envelope `data` (paginated list).
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.cohortId,
    required this.userId,
    required this.date,
    required this.type,
    this.checkInAt,
    this.checkOutAt,
    this.lateMinutes,
    this.earlyLeaveMinutes,
    this.note,
  });

  final int id;
  final int cohortId;
  final int userId;
  final DateTime date;
  final AttendanceType type;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final int? lateMinutes;
  final int? earlyLeaveMinutes;
  final String? note;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);
    int? asIntOrNull(Object? v) =>
        v is int ? v : (v is num ? v.toInt() : null);
    DateTime? asDateOrNull(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
    return AttendanceRecord(
      id: asInt(json['id']),
      cohortId: asInt(json['cohort_id']),
      userId: asInt(json['user_id']),
      date: asDateOrNull(json['date']) ?? DateTime.now(),
      type: AttendanceType.fromCode(json['type'] as String?),
      checkInAt: asDateOrNull(json['check_in_at']),
      checkOutAt: asDateOrNull(json['check_out_at']),
      lateMinutes: asIntOrNull(json['late_minutes']),
      earlyLeaveMinutes: asIntOrNull(json['early_leave_minutes']),
      note: json['note'] as String?,
    );
  }
}
