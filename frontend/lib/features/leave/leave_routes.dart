import 'package:go_router/go_router.dart';

import 'domain/leave_model.dart';
import 'presentation/screens/leave_approval_detail_screen.dart';
import 'presentation/screens/leave_approval_list_screen.dart';
import 'presentation/screens/leave_request_detail_screen.dart';
import 'presentation/screens/leave_request_form_screen.dart';
import 'presentation/screens/leave_request_list_screen.dart';

/// Student early-leave / sick-leave (조퇴·병결) routes.
///
/// Exposed as a list of [RouteBase] with ABSOLUTE paths so the orchestrator can
/// nest them inside the authenticated `ShellRoute` in `core/router/app_router.dart`:
///
///   - `/student/leave-requests`      → list   ([LeaveRequestListScreen])
///   - `/student/leave-requests/new`  → form   ([LeaveRequestFormScreen])
///   - `/student/leave-requests/:id`  → detail ([LeaveRequestDetailScreen])
///
/// `/new` is declared before `/:id` so it is never captured as an id.
final List<RouteBase> leaveRoutes = <RouteBase>[
  GoRoute(
    path: '/student/leave-requests',
    builder: (context, state) => const LeaveRequestListScreen(),
  ),
  GoRoute(
    path: '/student/leave-requests/new',
    // Optional prefill is carried in QUERY PARAMETERS (not `extra`) so a hard
    // browser reload of e.g. `/student/leave-requests/new?date=2026-05-12`
    // still reconstructs the prefilled form. `extra` would be lost on reload.
    builder: (context, state) => LeaveRequestFormScreen(
      prefill: LeaveFormPrefill.fromQuery(state.uri.queryParameters),
    ),
  ),
  GoRoute(
    path: '/student/leave-requests/:id',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
      return LeaveRequestDetailScreen(requestId: id);
    },
  ),
];

/// Reviewer (operations-team / instructor) approval routes.
///
/// The SAME screens back both reviewer areas; each gets its own absolute base
/// path so navigation and the back button stay within the right area:
///
///   Operations team:
///   - `/ops/leave-requests`           → list   ([LeaveApprovalListScreen])
///   - `/ops/leave-requests/:id`       → detail ([LeaveApprovalDetailScreen])
///
///   Instructor:
///   - `/instructor/leave-approvals`       → list   ([LeaveApprovalListScreen])
///   - `/instructor/leave-approvals/:id`   → detail ([LeaveApprovalDetailScreen])
///
/// Nest these inside the authenticated `ShellRoute` alongside [leaveRoutes].
/// The screens themselves role-gate (운영팀/강사 may view; only 운영팀 may
/// approve/reject, matching the backend `admin_ops`-only rule).
final List<RouteBase> leaveApprovalRoutes = <RouteBase>[
  // Operations team.
  GoRoute(
    path: '/ops/leave-requests',
    builder: (context, state) =>
        const LeaveApprovalListScreen(basePath: '/ops/leave-requests'),
  ),
  GoRoute(
    path: '/ops/leave-requests/:id',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
      return LeaveApprovalDetailScreen(
        requestId: id,
        basePath: '/ops/leave-requests',
      );
    },
  ),
  // Instructor.
  GoRoute(
    path: '/instructor/leave-approvals',
    builder: (context, state) => const LeaveApprovalListScreen(
      basePath: '/instructor/leave-approvals',
    ),
  ),
  GoRoute(
    path: '/instructor/leave-approvals/:id',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
      return LeaveApprovalDetailScreen(
        requestId: id,
        basePath: '/instructor/leave-approvals',
      );
    },
  ),
];
