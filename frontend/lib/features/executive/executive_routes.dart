import 'package:go_router/go_router.dart';

import 'presentation/screens/analytics_screen.dart';
import 'presentation/screens/governance_screen.dart';
import 'presentation/screens/kpi_roi_screen.dart';

/// Executive analytics MOCK routes (absolute paths).
///
/// These REPLACE the three placeholder routes currently registered inline in
/// `core/router/app_router.dart`:
///   - `/executive/kpis`       → [KpiRoiScreen]
///   - `/executive/governance` → [GovernanceScreen]
///   - `/executive/analytics`  → [AnalyticsScreen]
///
/// The orchestrator should wire this list into the authenticated `ShellRoute`
/// (which supplies the top bar + side navigation) in place of the placeholder
/// `GoRoute`s. The executive side-nav already exposes kpis / governance /
/// analytics items, so no nav change is needed.
///
/// IMPORTANT: every screen renders STATIC MOCK data behind a visible "데모
/// 데이터" banner — there is no `/analytics/*` backend yet. See each screen's
/// `TODO(...-api)` for the future integration seam.
final List<RouteBase> executiveMockRoutes = <RouteBase>[
  GoRoute(
    path: '/executive/kpis',
    builder: (context, state) => const KpiRoiScreen(),
  ),
  GoRoute(
    path: '/executive/governance',
    builder: (context, state) => const GovernanceScreen(),
  ),
  GoRoute(
    path: '/executive/analytics',
    builder: (context, state) => const AnalyticsScreen(),
  ),
];
