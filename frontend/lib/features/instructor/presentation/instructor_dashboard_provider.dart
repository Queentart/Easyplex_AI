/// Aggregation helpers for the INSTRUCTOR home dashboard.
///
/// This is a thin presentation-layer aggregator: it does NOT own a data layer.
/// Each dashboard card watches an EXISTING feature provider directly (so one
/// failing card never blocks the others); this file only exposes small derived
/// values the header / summary cards need:
///   - [instructorCohortIdProvider] — the instructor's cohort id (null when the
///     account is not yet assigned to a cohort → friendly empty state).
///   - [AttendanceWarnings] — derives the at-risk (late / absent) counts from an
///     already-loaded [AttendanceSummary] for the warning banner.
///
/// Reused providers (imported read-only by the screen, not here):
///   attendance:  instructorCohortSummaryProvider / instructorCohortRecordsProvider
///   assignment:  gradingAssignmentsProvider / submissionRowsProvider
///   mentoring:   mentoringLogListProvider
///   class_:      classListProvider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cohort_filter.dart';
import '../../../core/providers.dart';
import '../../attendance/domain/attendance_model.dart';

/// The current instructor's active cohort id, or null when they teach no
/// cohorts at all.
///
/// Instructors link to cohorts via the many-to-many join (surfaced as
/// [AppUser.cohortIds]); their single [AppUser.cohortId] is always null. Resolve
/// the active cohort as:
///   1. the globally selected cohort ([selectedCohortProvider]) when it is set
///      AND belongs to this instructor;
///   2. otherwise the first of their taught cohorts;
///   3. otherwise null (truly unassigned → friendly empty state).
///
/// All cohort-scoped dashboard cards key off this; null means "no cohort".
final instructorCohortIdProvider = Provider<int?>((ref) {
  final user = ref.watch(currentUserProvider);
  final cohortIds = user?.cohortIds ?? const <int>[];
  if (cohortIds.isEmpty) return null;

  final selected = ref.watch(selectedCohortProvider);
  if (selected != null && cohortIds.contains(selected)) return selected;
  return cohortIds.first;
});

/// Derived at-risk counts for the attendance warning banner.
///
/// Pure display projection over a server-provided [AttendanceSummary] — no
/// client-side recomputation of the "3 지각 = 1 결석" rule (that is
/// [AttendanceSummary.computedAbsent], surfaced verbatim).
class AttendanceWarnings {
  const AttendanceWarnings({
    required this.late,
    required this.absent,
    required this.computedAbsent,
  });

  factory AttendanceWarnings.from(AttendanceSummary summary) {
    return AttendanceWarnings(
      late: summary.late,
      absent: summary.absent,
      computedAbsent: summary.computedAbsent,
    );
  }

  final int late;
  final int absent;
  final int computedAbsent;

  /// True when there is anything worth flagging to the instructor.
  bool get hasWarnings => late > 0 || absent > 0;
}
