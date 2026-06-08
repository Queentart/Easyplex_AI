import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/data/admin_repository.dart';
import '../../attendance/domain/attendance_model.dart';
import '../../attendance/presentation/admin_attendance_provider.dart';
import '../../inquiry/data/inquiry_repository.dart';
import '../../inquiry/domain/inquiry_model.dart';
import '../../inquiry/presentation/inquiry_provider.dart';

/// ───────────────────────────────────────────────────────────────────────────
/// Operations command-center aggregation providers.
///
/// This is a thin READ-ONLY aggregation layer for the ops home dashboard. It
/// does NOT introduce a new data layer: KPI counts are derived from the SAME
/// repositories / providers the dedicated management screens already use
/// (admin users/cohorts, inquiries, admin attendance), so the numbers stay
/// consistent with those screens.
///
/// Each KPI is its own provider so every dashboard card owns an independent
/// [AsyncValue] (one slow/failing call never blanks the whole dashboard).
/// ───────────────────────────────────────────────────────────────────────────

/// Total active users in the institution.
///
/// Reuses [adminRepositoryProvider]; reads `Pagination.total` from the first
/// page rather than materializing every row (the list endpoint reports the full
/// count in its envelope meta).
final opsUserCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final page = await ref.watch(adminRepositoryProvider).listUsers(size: 1);
  return page.pagination.total;
});

/// Total cohorts (all statuses) in the institution.
final opsCohortCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final page = await ref.watch(adminRepositoryProvider).listCohorts(size: 1);
  return page.pagination.total;
});

/// Number of OPEN (unresolved) inquiries/tickets — the ops "to-do" backlog.
///
/// Uses the inquiry repository with a `status=open` filter and reads the
/// envelope total, so a large backlog doesn't pull every row.
final opsOpenInquiryCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final page = await ref
      .watch(inquiryRepositoryProvider)
      .listInquiries(status: InquiryStatus.open.code, size: 1);
  return page.pagination.total;
});

/// Recent OPEN inquiries (newest first) for the dashboard's ticket card.
///
/// Reuses the existing [inquiryListProvider] family with an open-status filter,
/// so it shares the cache with the issues screen. The UI takes the first few.
final opsRecentOpenInquiriesProvider =
    Provider.autoDispose<AsyncValue<List<Inquiry>>>((ref) {
  return ref.watch(
    inquiryListProvider(
      const InquiryListArgs(status: 'open'),
    ),
  );
});

/// Today's attendance records, reused from the admin attendance provider with
/// an unfiltered (all-cohort) key. The summary card derives counts from these.
final opsAttendanceTodayProvider =
    Provider.autoDispose<AsyncValue<List<AttendanceRecord>>>((ref) {
  return ref.watch(
    adminAttendanceRecordsProvider(const AdminAttendanceFilter()),
  );
});

/// Counts of "anomaly" attendance types (late / absent / early-leave) limited to
/// today's date, plus the total record count. Derived purely from the reused
/// [opsAttendanceTodayProvider]; no extra network call.
class AttendanceTodaySummary {
  const AttendanceTodaySummary({
    required this.present,
    required this.late,
    required this.absent,
    required this.earlyLeave,
  });

  final int present;
  final int late;
  final int absent;
  final int earlyLeave;

  /// Attendance issues needing attention today (late + absent + early leave).
  int get anomalies => late + absent + earlyLeave;

  int get total => present + late + absent + earlyLeave;
}

/// Reduces today's reused attendance records into an [AttendanceTodaySummary].
final opsAttendanceTodaySummaryProvider =
    Provider.autoDispose<AsyncValue<AttendanceTodaySummary>>((ref) {
  final records = ref.watch(opsAttendanceTodayProvider);
  return records.whenData((list) {
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    var present = 0, late = 0, absent = 0, earlyLeave = 0;
    for (final r in list.where((r) => isToday(r.date))) {
      switch (r.type) {
        case AttendanceType.present:
          present++;
        case AttendanceType.late:
          late++;
        case AttendanceType.absent:
          absent++;
        case AttendanceType.earlyLeave:
          earlyLeave++;
        case AttendanceType.medical:
        case AttendanceType.official:
        case AttendanceType.unknown:
          break;
      }
    }
    return AttendanceTodaySummary(
      present: present,
      late: late,
      absent: absent,
      earlyLeave: earlyLeave,
    );
  });
});
