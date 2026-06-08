/// State for the STANDARD attendance MANAGEMENT views (operations + instructor):
/// a roster-centric layout (one row per student) scoped to a cohort + period,
/// with overall period stats and a sortable table.
///
/// The backend exposes no roster endpoint, so the roster providers here fetch a
/// cohort's per-date records for the selected month
/// (`GET /attendance/?cohort_id=&from_date=&to_date=`) and aggregate them into
/// an [AttendanceRoster] client-side (see `domain/attendance_roster.dart`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_attendance_repository.dart';
import '../data/instructor_attendance_repository.dart';
import '../domain/attendance_roster.dart';
import 'attendance_provider.dart' show AttendanceMonth;

/// ─────────────────────────────────────────────────────────────────────────
/// Selected management period (month)
/// ─────────────────────────────────────────────────────────────────────────

/// The month currently selected in the management roster views. Defaults to the
/// current month; navigating prev/next or picking from the dropdown updates it.
///
/// Kept SEPARATE from the student-facing [attendanceSelectedMonthProvider] so a
/// manager's period selection never leaks into the student screen and vice
/// versa.
class ManagementMonthNotifier extends Notifier<AttendanceMonth> {
  @override
  AttendanceMonth build() => AttendanceMonth.current();

  void select(AttendanceMonth month) {
    if (month.isAfterCurrent) return; // no future records exist
    state = month;
  }

  void previous() => select(state.previous);
  void next() => select(state.next);
}

final managementMonthProvider =
    NotifierProvider<ManagementMonthNotifier, AttendanceMonth>(
  ManagementMonthNotifier.new,
);

/// ─────────────────────────────────────────────────────────────────────────
/// Roster sort order
/// ─────────────────────────────────────────────────────────────────────────

/// The active sort applied to the roster table. Defaults to 출석률 낮은순 so the
/// students who need attention surface at the top.
class RosterSortNotifier extends Notifier<RosterSort> {
  @override
  RosterSort build() => RosterSort.rateAsc;

  void select(RosterSort sort) => state = sort;
}

final rosterSortProvider =
    NotifierProvider<RosterSortNotifier, RosterSort>(RosterSortNotifier.new);

/// ─────────────────────────────────────────────────────────────────────────
/// Roster scope (cohort + month) — family key
/// ─────────────────────────────────────────────────────────────────────────

/// Immutable, equatable key for a roster query: a [cohortId] (null = all
/// cohorts, ops only) plus the [month] to scope records to.
class RosterScope {
  const RosterScope({required this.cohortId, required this.month});

  /// `null` means "all cohorts" (operations cross-cohort view). The instructor
  /// view always passes a concrete cohort id.
  final int? cohortId;
  final AttendanceMonth month;

  @override
  bool operator ==(Object other) =>
      other is RosterScope &&
      other.cohortId == cohortId &&
      other.month == month;

  @override
  int get hashCode => Object.hash(cohortId, month);
}

/// ─────────────────────────────────────────────────────────────────────────
/// OPS roster (all cohorts or one cohort) — `AdminAttendanceRepository`
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the operations-team roster for a [RosterScope]: fetches the period's
/// records (optionally cohort-filtered) and aggregates them per student.
///
/// Follows the F2 family pattern (Riverpod 3.x non-codegen): the family
/// argument is captured in the ctor ([scope]) by the provider factory — the
/// no-arg [build] reads it from there. A generous page size (500) is requested
/// so a month of a cohort's records aggregates in a single call.
class AdminRosterNotifier extends AsyncNotifier<AttendanceRoster> {
  AdminRosterNotifier(this.scope);

  final RosterScope scope;

  @override
  Future<AttendanceRoster> build() => _fetch();

  Future<AttendanceRoster> _fetch() async {
    final page = await ref.read(adminAttendanceRepositoryProvider).getRecords(
          cohortId: scope.cohortId,
          fromDate: scope.month.fromDateParam,
          toDate: scope.month.toDateParam,
          size: 500,
        );
    return AttendanceRoster.fromRecords(page.records);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final adminRosterProvider = AsyncNotifierProvider.family<AdminRosterNotifier,
    AttendanceRoster, RosterScope>(AdminRosterNotifier.new);

/// ─────────────────────────────────────────────────────────────────────────
/// INSTRUCTOR roster (one cohort) — `InstructorAttendanceRepository`
/// ─────────────────────────────────────────────────────────────────────────

/// Loads the instructor roster for a [RosterScope] whose cohort id is required
/// (an instructor is always scoped to a concrete cohort). Aggregates the
/// period's cohort records per student.
class InstructorRosterNotifier extends AsyncNotifier<AttendanceRoster> {
  InstructorRosterNotifier(this.scope);

  final RosterScope scope;

  @override
  Future<AttendanceRoster> build() => _fetch();

  Future<AttendanceRoster> _fetch() async {
    final page = await ref
        .read(instructorAttendanceRepositoryProvider)
        .getCohortRecords(
          cohortId: scope.cohortId!,
          fromDate: scope.month.fromDateParam,
          toDate: scope.month.toDateParam,
          size: 500,
        );
    return AttendanceRoster.fromRecords(page.records);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final instructorRosterProvider = AsyncNotifierProvider.family<
    InstructorRosterNotifier, AttendanceRoster, RosterScope>(
  InstructorRosterNotifier.new,
);
