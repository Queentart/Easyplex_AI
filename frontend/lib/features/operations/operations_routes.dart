import 'package:go_router/go_router.dart';

import 'presentation/screens/data_sync_screen.dart';
import 'presentation/screens/server_logs_screen.dart';
import 'presentation/screens/system_settings_screen.dart';
import 'presentation/screens/system_status_screen.dart';

/// Operations infra / system-monitoring routes (MOCK-DATA phase).
///
/// These four screens are Stream-2 "목업 있으나 백엔드 부족 → mock 먼저" screens:
/// every value they render is hard-coded demo data because there is no
/// `/system/*` / `/sync/*` backend yet (see
/// study/memo/0529/mockup_backend_gap_analysis.md §1).
///
/// Exposed as a list of [RouteBase] with ABSOLUTE paths so the orchestrator can
/// nest it inside the authenticated `ShellRoute` in
/// `core/router/app_router.dart`:
///
///   - `/ops/status`   → [SystemStatusScreen]
///   - `/ops/logs`     → [ServerLogsScreen]
///   - `/ops/settings` → [SystemSettingsScreen]  (REPLACES the placeholder route)
///   - `/ops/sync`     → [DataSyncScreen]
///
/// Wiring note for the orchestrator: REMOVE the current placeholder
/// `GoRoute(path: '/ops/settings', ...)` in app_router.dart and spread
/// `...operationsMockRoutes` in its place; add side-nav items
/// "시스템 상태"→/ops/status, "서버 로그"→/ops/logs, "데이터 동기화"→/ops/sync
/// ("설정"→/ops/settings already exists in the ops nav).
final List<RouteBase> operationsMockRoutes = <RouteBase>[
  GoRoute(
    path: SystemStatusScreen.routePath,
    builder: (context, state) => const SystemStatusScreen(),
  ),
  GoRoute(
    path: ServerLogsScreen.routePath,
    builder: (context, state) => const ServerLogsScreen(),
  ),
  GoRoute(
    path: SystemSettingsScreen.routePath,
    builder: (context, state) => const SystemSettingsScreen(),
  ),
  GoRoute(
    path: DataSyncScreen.routePath,
    builder: (context, state) => const DataSyncScreen(),
  ),
];
