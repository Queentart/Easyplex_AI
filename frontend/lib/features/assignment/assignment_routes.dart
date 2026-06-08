import 'package:go_router/go_router.dart';

import 'presentation/screens/assignment_detail_screen.dart';
import 'presentation/screens/assignment_list_screen.dart';

/// Student assignment routes, with ABSOLUTE paths so they can be dropped into
/// the authenticated `ShellRoute` by the orchestrator without re-nesting:
///
///   - `/student/assignments`      → [AssignmentListScreen]
///   - `/student/assignments/:id`  → [AssignmentDetailScreen] (detail + own
///                                    submission, combined in one screen)
///
/// The `:id` route hosts both the assignment brief and the student's OWN
/// submission area (see [AssignmentDetailScreen] / `SubmissionPanel`).
final List<RouteBase> assignmentRoutes = <RouteBase>[
  GoRoute(
    path: '/student/assignments',
    builder: (context, state) => const AssignmentListScreen(),
    routes: [
      GoRoute(
        path: ':id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return AssignmentDetailScreen(assignmentId: id);
        },
      ),
    ],
  ),
];
