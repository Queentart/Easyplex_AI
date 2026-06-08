import 'package:go_router/go_router.dart';

import 'presentation/screens/cohort_management_screen.dart';
import 'presentation/screens/user_management_screen.dart';

/// Operations-team user & cohort management routes (absolute paths).
///
/// The orchestrator nests these inside the authenticated `ShellRoute` in
/// `core/router/app_router.dart`, so paths are ABSOLUTE (the shell supplies the
/// top bar + side navigation; the screen renders content only). Both screens
/// guard on `admin_ops` internally and render an access notice otherwise.
///
///   - `/ops/users`   → [UserManagementScreen]   (user list, role, status)
///   - `/ops/cohorts` → [CohortManagementScreen] (cohort CRUD + members)
final List<RouteBase> adminRoutes = <RouteBase>[
  GoRoute(
    path: '/ops/users',
    builder: (context, state) => const UserManagementScreen(),
  ),
  GoRoute(
    path: '/ops/cohorts',
    builder: (context, state) => const CohortManagementScreen(),
  ),
];
