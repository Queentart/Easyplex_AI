import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/instructor_attendance_repository.dart';
import '../domain/attendance_model.dart';

/// Instructor attendance presentation layer.
///
/// The roster (수강생별) management state lives in
/// `attendance_management_provider.dart` ([instructorRosterProvider]); the
/// instructor management SCREEN drives manual correction + notify directly
/// through [instructorAttendanceRepositoryProvider] and then refreshes the
/// roster.
///
/// This file additionally keeps the cohort SUMMARY provider that the instructor
/// DASHBOARD consumes ([instructorCohortSummaryProvider]) — same public API as
/// before the roster refactor — implemented on the instructor repo's
/// `GET /attendance/summary?cohort_id=` call.

/// Loads a cohort's aggregate attendance summary
/// (`GET /attendance/summary?cohort_id=`), keyed by cohort id.
///
/// Returns the same [AttendanceSummary] shape as before
/// (present/late/absent/computed_absent/attendance_rate). The dashboard's
/// `_AttendanceSummaryCard` watches this family and calls [refresh] on retry.
class InstructorCohortSummaryNotifier extends AsyncNotifier<AttendanceSummary> {
  InstructorCohortSummaryNotifier(this.cohortId);

  final int cohortId;

  @override
  Future<AttendanceSummary> build() => _fetch();

  Future<AttendanceSummary> _fetch() {
    return ref
        .read(instructorAttendanceRepositoryProvider)
        .getCohortSummary(cohortId: cohortId);
  }

  /// Re-fetches the summary, flipping to loading first for explicit feedback.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// A cohort's aggregate attendance summary, keyed by cohort id.
final instructorCohortSummaryProvider = AsyncNotifierProvider.family<
    InstructorCohortSummaryNotifier, AttendanceSummary, int>(
  InstructorCohortSummaryNotifier.new,
);
