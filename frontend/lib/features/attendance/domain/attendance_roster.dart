/// Per-student attendance ROSTER aggregates for the management views
/// (operations team + instructor).
///
/// The backend has no roster endpoint — `GET /attendance/` returns flat
/// per-date records (see `backend/app/schemas/attendance.py` `AttendanceOut`),
/// and those records carry only a numeric `user_id` (no student name). So the
/// management screens fetch a cohort's records for a period and aggregate them
/// CLIENT-SIDE into one [StudentAttendanceRoster] row per student here.
///
/// This mirrors the "3 지각 = 1 결석" rule the backend uses for the per-student
/// SUMMARY endpoint, but applied to the SELECTED PERIOD's records (the summary
/// endpoint is cumulative and cannot be period-scoped, so the roster recomputes
/// from the period's records instead). This is presentation-period aggregation,
/// not a divergent business rule: the canonical cumulative figure still comes
/// from the server summary where one is shown.
library;

import 'attendance_model.dart';

/// Risk tier for a student's period attendance, surfaced as a status chip.
enum RiskTier {
  /// 정상 — healthy attendance.
  normal,

  /// 주의 — some late/early-leave/absence; worth watching.
  warning,

  /// 위험 — at risk (high converted-absence count).
  danger;

  /// Korean user-facing label.
  String get label {
    switch (this) {
      case RiskTier.normal:
        return '정상';
      case RiskTier.warning:
        return '주의';
      case RiskTier.danger:
        return '위험';
    }
  }
}

/// One student's aggregated attendance for the selected period.
///
/// Counts are summed from that student's [AttendanceRecord]s; [computedAbsent]
/// applies the "3 지각 = 1 결석" conversion (`absent + late ~/ 3`) and
/// [attendanceRate] is `present / totalDays` as a 0.0–1.0 fraction.
class StudentAttendanceRoster {
  const StudentAttendanceRoster({
    required this.userId,
    required this.cohortId,
    required this.totalDays,
    required this.present,
    required this.late,
    required this.absent,
    required this.earlyLeave,
    required this.medical,
    required this.official,
    required this.records,
  });

  final int userId;
  final int cohortId;
  final int totalDays;
  final int present;
  final int late;
  final int absent;
  final int earlyLeave;
  final int medical;
  final int official;

  /// This student's per-date records for the period (newest first), used by the
  /// drill-down detail sheet.
  final List<AttendanceRecord> records;

  /// Display name. The backend records carry no name, so we render a stable
  /// `수강생 #N` handle keyed on the user id.
  String get displayName => '수강생 #$userId';

  /// 조퇴 + 병결 + 공결 grouped as "조퇴/기타" for the compact roster column.
  int get otherCount => earlyLeave + medical + official;

  /// Server-style converted absence: `absent + (late ~/ 3)`.
  int get computedAbsent => absent + (late ~/ 3);

  /// Attendance rate as a 0.0–1.0 fraction (present / total days).
  double get attendanceRate => totalDays == 0 ? 0 : present / totalDays;

  /// Risk tier derived from the converted-absence count and rate. Thresholds
  /// are intentionally conservative so managers see early warnings:
  ///   - 위험: 환산 결석 ≥ 3 (or rate < 70%)
  ///   - 주의: 환산 결석 ≥ 1 (or rate < 90%)
  ///   - 정상: otherwise
  RiskTier get tier {
    if (computedAbsent >= 3 || (totalDays > 0 && attendanceRate < 0.70)) {
      return RiskTier.danger;
    }
    if (computedAbsent >= 1 || (totalDays > 0 && attendanceRate < 0.90)) {
      return RiskTier.warning;
    }
    return RiskTier.normal;
  }

  /// True when this row should be highlighted as at-risk in the roster table.
  bool get isAtRisk => tier != RiskTier.normal;
}

/// Overall period stats shown above the roster table.
class AttendanceRosterSummary {
  const AttendanceRosterSummary({
    required this.studentCount,
    required this.totalRecords,
    required this.overallRate,
    required this.lateTotal,
    required this.absentTotal,
    required this.atRiskCount,
  });

  /// Number of distinct students with at least one record in the period.
  final int studentCount;

  /// Total per-date records aggregated.
  final int totalRecords;

  /// Overall attendance rate (sum present / sum total) as a 0.0–1.0 fraction.
  final double overallRate;

  /// Total 지각 across all students.
  final int lateTotal;

  /// Total 결석 across all students.
  final int absentTotal;

  /// Number of students flagged 주의 or 위험.
  final int atRiskCount;
}

/// How the roster table is ordered.
enum RosterSort {
  /// By student id ascending (stable "이름" order — names aren't available).
  name,

  /// By attendance rate ascending (worst first — surfaces at-risk students).
  rateAsc,

  /// By attendance rate descending (best first).
  rateDesc;

  /// Korean user-facing label for the sort dropdown.
  String get label {
    switch (this) {
      case RosterSort.name:
        return '이름순';
      case RosterSort.rateAsc:
        return '출석률 낮은순';
      case RosterSort.rateDesc:
        return '출석률 높은순';
    }
  }
}

/// The fully-aggregated roster for one cohort + period: per-student rows plus
/// the overall [summary]. Produced by [AttendanceRoster.fromRecords].
class AttendanceRoster {
  const AttendanceRoster({required this.students, required this.summary});

  final List<StudentAttendanceRoster> students;
  final AttendanceRosterSummary summary;

  bool get isEmpty => students.isEmpty;

  /// Returns a copy of [students] ordered by [sort].
  List<StudentAttendanceRoster> sorted(RosterSort sort) {
    final list = [...students];
    switch (sort) {
      case RosterSort.name:
        list.sort((a, b) => a.userId.compareTo(b.userId));
      case RosterSort.rateAsc:
        list.sort((a, b) => a.attendanceRate.compareTo(b.attendanceRate));
      case RosterSort.rateDesc:
        list.sort((a, b) => b.attendanceRate.compareTo(a.attendanceRate));
    }
    return list;
  }

  /// Aggregates flat per-date [records] into a per-student roster.
  ///
  /// Records are grouped by `user_id`; each group's per-type counts feed a
  /// [StudentAttendanceRoster]. Within a student, records are sorted newest
  /// first for the drill-down detail. The overall [summary] sums across groups.
  factory AttendanceRoster.fromRecords(List<AttendanceRecord> records) {
    final byUser = <int, List<AttendanceRecord>>{};
    for (final r in records) {
      byUser.putIfAbsent(r.userId, () => []).add(r);
    }

    final students = <StudentAttendanceRoster>[];
    var presentSum = 0;
    var totalSum = 0;
    var lateSum = 0;
    var absentSum = 0;
    var atRisk = 0;

    for (final entry in byUser.entries) {
      final rows = entry.value..sort((a, b) => b.date.compareTo(a.date));
      var present = 0, late = 0, absent = 0, early = 0, medical = 0, official = 0;
      var cohortId = 0;
      for (final r in rows) {
        cohortId = r.cohortId;
        switch (r.type) {
          case AttendanceType.present:
            present++;
          case AttendanceType.late:
            late++;
          case AttendanceType.absent:
            absent++;
          case AttendanceType.earlyLeave:
            early++;
          case AttendanceType.medical:
            medical++;
          case AttendanceType.official:
            official++;
          case AttendanceType.unknown:
            break;
        }
      }
      final total = present + late + absent + early + medical + official;
      final student = StudentAttendanceRoster(
        userId: entry.key,
        cohortId: cohortId,
        totalDays: total,
        present: present,
        late: late,
        absent: absent,
        earlyLeave: early,
        medical: medical,
        official: official,
        records: rows,
      );
      students.add(student);

      presentSum += present;
      totalSum += total;
      lateSum += late;
      absentSum += absent;
      if (student.isAtRisk) atRisk++;
    }

    students.sort((a, b) => a.userId.compareTo(b.userId));

    return AttendanceRoster(
      students: students,
      summary: AttendanceRosterSummary(
        studentCount: students.length,
        totalRecords: records.length,
        overallRate: totalSum == 0 ? 0 : presentSum / totalSum,
        lateTotal: lateSum,
        absentTotal: absentSum,
        atRiskCount: atRisk,
      ),
    );
  }
}
