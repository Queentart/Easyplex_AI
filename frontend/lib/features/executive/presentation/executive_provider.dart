import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/data/admin_repository.dart';
import '../../admin/domain/admin_model.dart';
import '../../admin/presentation/admin_provider.dart';
import '../../inquiry/domain/inquiry_model.dart';
import '../../inquiry/presentation/inquiry_provider.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Executive aggregate KPIs (READ-ONLY composition)
/// ─────────────────────────────────────────────────────────────────────────
///
/// There is no dedicated aggregate / analytics backend endpoint yet, so the
/// executive home derives its REAL headline counts from the same list/paged
/// providers the operations screens already use:
///
///   - total users     → [userListProvider] pagination `total` (server count,
///                        independent of the loaded page size)
///   - cohort count     → length of [cohortListProvider]
///   - license count    → length of [licenseListProvider]
///
/// Each metric is exposed as its OWN provider so the dashboard can render a
/// per-card [AsyncValue] (one card failing/loading never blocks the others).
/// These providers only WATCH the upstream providers — they own no data layer
/// and trigger no extra network calls beyond what those providers already make.

/// Unfiltered user-list key used purely to read the institution-wide total.
const _allUsersArgs = UserListArgs();

/// REAL: institution-wide user count, read from the `/users` pagination meta.
///
/// We watch the unfiltered [userListProvider] page and surface its
/// `pagination.total` (the server's full count) rather than the loaded rows,
/// so the KPI is accurate even though only the first page is fetched.
final executiveUserCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(userListProvider(_allUsersArgs)).whenData(
        (UserPage page) => page.pagination.total,
      );
});

/// REAL: number of cohorts for the institution (length of the cohort list).
final executiveCohortCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(cohortListProvider).whenData(
        (List<Cohort> cohorts) => cohorts.length,
      );
});

/// REAL: number of software licenses (length of the license list).
final executiveLicenseCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(licenseListProvider).whenData(
        (List<SoftwareLicense> licenses) => licenses.length,
      );
});

/// Refreshes every REAL aggregate by re-running its upstream provider.
///
/// Invalidation (rather than calling each notifier's `refresh`) keeps this seam
/// independent of the upstream notifier APIs and works for the family key too.
void refreshExecutiveAggregates(WidgetRef ref) {
  ref.invalidate(userListProvider(_allUsersArgs));
  ref.invalidate(cohortListProvider);
  ref.invalidate(licenseListProvider);
}

/// ─────────────────────────────────────────────────────────────────────────
/// MOCK: strategic finance / risk metrics (NO backend yet — demo only)
/// ─────────────────────────────────────────────────────────────────────────
//
// MOCK: ROI / revenue / cost / churn-risk have NO backing endpoint in the
// current API surface. These are static demo figures so the executive layout
// can be reviewed end-to-end; they are rendered behind a visible "데모" label
// and MUST be replaced once an analytics endpoint exists. Do not treat any
// value below as real data.

/// A single mocked strategic metric for the "데모" section.
class MockExecutiveMetric {
  const MockExecutiveMetric({
    required this.label,
    required this.value,
    required this.delta,
    this.deltaPositive = true,
  });

  final String label;
  final String value;
  final String delta;
  final bool deltaPositive;
}

/// MOCK: headline strategic stat tiles (revenue / cost / ROI).
const List<MockExecutiveMetric> mockStrategicMetrics = [
  // MOCK: no revenue endpoint — illustrative figure only.
  MockExecutiveMetric(
    label: '월 매출 (MOCK)',
    value: '₩ 128,400,000',
    delta: '+8.2% MoM',
  ),
  // MOCK: no cost endpoint — illustrative figure only.
  MockExecutiveMetric(
    label: '운영 비용 (MOCK)',
    value: '₩ 74,900,000',
    delta: '+2.1% MoM',
    deltaPositive: false,
  ),
  // MOCK: no ROI endpoint — derived illustrative figure only.
  MockExecutiveMetric(
    label: 'ROI (MOCK)',
    value: '71.4%',
    delta: '+4.3%p',
  ),
];

/// A mocked churn-risk cohort row for the demo risk panel.
class MockChurnRisk {
  const MockChurnRisk({
    required this.cohortName,
    required this.riskRatio,
    required this.atRiskCount,
  });

  final String cohortName;

  /// 0.0 – 1.0 predicted churn ratio (drives the progress bar).
  final double riskRatio;
  final int atRiskCount;
}

/// MOCK: predicted churn-risk by cohort. No prediction service exists yet.
const List<MockChurnRisk> mockChurnRisks = [
  // MOCK: illustrative churn prediction — replace with model output.
  MockChurnRisk(cohortName: 'AI 개발 1기', riskRatio: 0.12, atRiskCount: 3),
  MockChurnRisk(cohortName: '데이터 분석 2기', riskRatio: 0.31, atRiskCount: 7),
  MockChurnRisk(cohortName: '클라우드 1기', riskRatio: 0.18, atRiskCount: 4),
];
