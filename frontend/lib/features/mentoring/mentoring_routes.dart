import 'package:go_router/go_router.dart';

import 'presentation/screens/class_evaluation_screen.dart';
import 'presentation/screens/mentoring_log_screen.dart';

/// Instructor mentoring / counseling routes (absolute paths).
///
/// The orchestrator nests these inside the authenticated `ShellRoute` so they
/// inherit the app shell chrome (top bar + side nav). All intra-feature
/// navigation uses `context.go` against these paths.
///
///   - `/instructor/counseling`             → [MentoringLogScreen]
///       Counseling-record list + compose sheet.
///   - `/instructor/counseling/evaluations` → [ClassEvaluationScreen]
///       Anonymous course-evaluation results. The target class is passed via
///       the `classId` query parameter (e.g. `…/evaluations?classId=12`); a hit
///       without it shows a "pick a class" prompt.
final List<RouteBase> mentoringRoutes = [
  GoRoute(
    path: MentoringLogScreen.routePath,
    builder: (context, state) => const MentoringLogScreen(),
  ),
  GoRoute(
    path: ClassEvaluationScreen.routePath,
    builder: (context, state) {
      final raw = state.uri.queryParameters['classId'];
      return ClassEvaluationScreen(classId: int.tryParse(raw ?? ''));
    },
  ),
];
