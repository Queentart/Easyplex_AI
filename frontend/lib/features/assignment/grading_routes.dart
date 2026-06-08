import 'package:go_router/go_router.dart';

import 'presentation/screens/grading_dashboard_screen.dart';

/// INSTRUCTOR assignment-grading routes, with ABSOLUTE paths so they can be
/// dropped into the authenticated `ShellRoute` by the router without
/// re-nesting:
///
///   - `/instructor/assignments`               → [GradingDashboardScreen]
///       (assignment picker + submissions table + feedback editor + create)
///   - `/instructor/assignments/:id/submissions` → [GradingDashboardScreen]
///       pre-selected to assignment `:id`.
///
/// Both routes render the same dashboard; the second simply deep-links to a
/// specific assignment's submission view.
final List<RouteBase> gradingRoutes = <RouteBase>[
  GoRoute(
    path: '/instructor/assignments',
    builder: (context, state) => const GradingDashboardScreen(),
    routes: [
      GoRoute(
        path: ':id/submissions',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return GradingDashboardScreen(selectedAssignmentId: id);
        },
      ),
    ],
  ),
];
