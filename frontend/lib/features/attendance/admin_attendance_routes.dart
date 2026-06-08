import 'package:go_router/go_router.dart';

import 'presentation/screens/admin_attendance_screen.dart';
import 'presentation/screens/csv_upload_screen.dart';

/// Route table for the OPERATIONS-TEAM (admin_ops) attendance feature.
///
/// The orchestrator nests these inside the authenticated `ShellRoute` in
/// `core/router/app_router.dart`, so paths are ABSOLUTE (the shell supplies the
/// top bar + side navigation; the screens render content only).
///
///   - `/ops/attendance`        → [AdminAttendanceScreen] (full management table)
///   - `/ops/attendance/import` → [CsvUploadScreen]        (CSV import + rollback)
///
/// Access is ops-only; the backend enforces `require_roles("admin_ops")` and a
/// 403 surfaces as "접근 권한이 없습니다." in the screens.
final List<RouteBase> adminAttendanceRoutes = <RouteBase>[
  GoRoute(
    path: '/ops/attendance',
    builder: (context, state) => const AdminAttendanceScreen(),
  ),
  GoRoute(
    path: '/ops/attendance/import',
    builder: (context, state) => const CsvUploadScreen(),
  ),
];
