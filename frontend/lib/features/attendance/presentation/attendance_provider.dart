import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/attendance_repository.dart';
import '../domain/attendance_model.dart';

/// A calendar month (year + month) used to scope the per-date record list.
///
/// Immutable and equatable so it can key a Riverpod `family` provider cleanly.
class AttendanceMonth {
  const AttendanceMonth(this.year, this.month);

  factory AttendanceMonth.current() {
    final now = DateTime.now();
    return AttendanceMonth(now.year, now.month);
  }

  final int year;
  final int month;

  /// First day of this month (00:00, local).
  DateTime get firstDay => DateTime(year, month, 1);

  /// Last day of this month (handles 28/29/30/31 automatically).
  DateTime get lastDay => DateTime(year, month + 1, 0);

  /// The previous calendar month.
  AttendanceMonth get previous =>
      month == 1 ? AttendanceMonth(year - 1, 12) : AttendanceMonth(year, month - 1);

  /// The next calendar month.
  AttendanceMonth get next =>
      month == 12 ? AttendanceMonth(year + 1, 1) : AttendanceMonth(year, month + 1);

  /// True if this month is in the future relative to the current month
  /// (used to disable "next" navigation — there are no future records).
  bool get isAfterCurrent {
    final now = AttendanceMonth.current();
    return year > now.year || (year == now.year && month > now.month);
  }

  /// `YYYY-MM-DD` for the first day (backend `from_date` query param).
  String get fromDateParam =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';

  /// `YYYY-MM-DD` for the last day (backend `to_date` query param).
  String get toDateParam {
    final d = lastDay;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Korean label, e.g. `2026년 5월`.
  String get label => '$year년 $month월';

  @override
  bool operator ==(Object other) =>
      other is AttendanceMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// The month currently selected in the per-date record list. Defaults to the
/// current month; navigating prev/next or picking from the dropdown updates it.
class AttendanceSelectedMonthNotifier extends Notifier<AttendanceMonth> {
  @override
  AttendanceMonth build() => AttendanceMonth.current();

  void select(AttendanceMonth month) {
    // Never allow navigating into the future (no records can exist there).
    if (month.isAfterCurrent) return;
    state = month;
  }

  void previous() => select(state.previous);
  void next() => select(state.next);
}

final attendanceSelectedMonthProvider =
    NotifierProvider<AttendanceSelectedMonthNotifier, AttendanceMonth>(
  AttendanceSelectedMonthNotifier.new,
);

/// Loads the current student's attendance summary (`GET /attendance/summary`).
///
/// The student is scoped to their own cohort/records server-side, so this
/// notifier passes no explicit cohort/user filter. Errors surface as the
/// [AsyncError] state carrying an [AttendanceException].
class StudentAttendanceSummaryNotifier
    extends AsyncNotifier<AttendanceSummary> {
  @override
  Future<AttendanceSummary> build() => _fetch();

  Future<AttendanceSummary> _fetch() {
    return ref.read(attendanceRepositoryProvider).getSummary();
  }

  /// Re-fetches the summary, flipping to loading first for explicit feedback.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// The current student's attendance summary.
final studentAttendanceSummaryProvider =
    AsyncNotifierProvider<StudentAttendanceSummaryNotifier, AttendanceSummary>(
  StudentAttendanceSummaryNotifier.new,
);

/// Returns true for "특이사항" record types — anything that is NOT a normal
/// present day. The per-date list only surfaces these so students immediately
/// see the days that may need a 조퇴·병결 document submitted.
bool _isException(AttendanceRecord r) =>
    r.type != AttendanceType.present && r.type != AttendanceType.unknown;

/// The current student's ALL records for the selected month
/// (`GET /attendance/?from_date=…&to_date=…`), newest first.
///
/// Scoped server-side to the month via `from_date`/`to_date`. Server-side RLS
/// scopes a student to their own records. This is the single source the
/// month-scoped summary AND the exception-only list are both derived from, so
/// only ONE network call is made per month.
///
/// Follows the F2 family pattern (Riverpod 3.x non-codegen): the family
/// argument ([month]) is captured in the constructor by the provider factory;
/// [build] takes no argument.
class StudentMonthRecordsNotifier
    extends AsyncNotifier<List<AttendanceRecord>> {
  StudentMonthRecordsNotifier(this.month);

  final AttendanceMonth month;

  @override
  Future<List<AttendanceRecord>> build() => _fetch();

  Future<List<AttendanceRecord>> _fetch() async {
    final page = await ref.read(attendanceRepositoryProvider).getRecords(
          fromDate: month.fromDateParam,
          toDate: month.toDateParam,
          size: 100,
        );
    final records = [...page.records]
      ..sort((a, b) => b.date.compareTo(a.date)); // newest first
    return records;
  }

  /// Re-fetches the current month, flipping to loading first for feedback.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// The current student's ALL month records, keyed by [AttendanceMonth].
final studentMonthRecordsProvider = AsyncNotifierProvider.family<
    StudentMonthRecordsNotifier,
    List<AttendanceRecord>,
    AttendanceMonth>(
  StudentMonthRecordsNotifier.new,
);

/// The current student's EXCEPTION-only records for the selected month,
/// derived from [studentMonthRecordsProvider] (no extra network call).
///
/// Filtered to non-present rows so the per-date list shows only 특이사항
/// (지각/결석/조퇴/병결/공결). Newest first.
final studentAttendanceRecordsProvider = Provider.family<
    AsyncValue<List<AttendanceRecord>>, AttendanceMonth>((ref, month) {
  return ref.watch(studentMonthRecordsProvider(month)).whenData(
        (records) => records.where(_isException).toList(),
      );
});

/// Month-scoped counts derived from [studentMonthRecordsProvider].
///
/// Recomputed CLIENT-SIDE from the SELECTED MONTH's records so the ring % and
/// per-type counts reflect that month only (the server `/attendance/summary`
/// endpoint is cumulative and cannot be month-scoped). The "3 지각 = 1 결석"
/// conversion is applied here for the selected month's display.
class MonthlyAttendanceStats {
  const MonthlyAttendanceStats({
    required this.totalDays,
    required this.present,
    required this.late,
    required this.absent,
    required this.earlyLeave,
    required this.medical,
    required this.official,
  });

  final int totalDays;
  final int present;
  final int late;
  final int absent;
  final int earlyLeave;
  final int medical;
  final int official;

  /// Converted absence for the month: `absent + (late ~/ 3)`.
  int get computedAbsent => absent + (late ~/ 3);

  /// Attendance rate for the month as a 0.0–1.0 fraction.
  double get attendanceRate => totalDays == 0 ? 0 : present / totalDays;

  /// True when the month has no records at all.
  bool get isEmpty => totalDays == 0;

  factory MonthlyAttendanceStats.fromRecords(List<AttendanceRecord> records) {
    var present = 0, late = 0, absent = 0, early = 0, medical = 0, official = 0;
    for (final r in records) {
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
    return MonthlyAttendanceStats(
      totalDays: present + late + absent + early + medical + official,
      present: present,
      late: late,
      absent: absent,
      earlyLeave: early,
      medical: medical,
      official: official,
    );
  }
}

/// The selected month's attendance stats, derived from
/// [studentMonthRecordsProvider] (no extra network call).
final studentMonthStatsProvider = Provider.family<
    AsyncValue<MonthlyAttendanceStats>, AttendanceMonth>((ref, month) {
  return ref
      .watch(studentMonthRecordsProvider(month))
      .whenData(MonthlyAttendanceStats.fromRecords);
});
