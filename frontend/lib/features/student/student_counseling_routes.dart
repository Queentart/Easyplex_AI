import 'package:go_router/go_router.dart';

import 'presentation/screens/student_counseling_screen.dart';

/// Student 상담(counseling) route (absolute path).
///
/// The orchestrator nests this inside the authenticated `ShellRoute` so the
/// screen inherits the app shell chrome (side nav + top bar), matching the
/// other student routes (`/student/support`, dashboard).
///
///   - `/student/counseling` → [StudentCounselingScreen]
///
/// Orchestrator: add a student side-nav item "상담" → `/student/counseling`
/// and wire [studentCounselingRoutes] into the student ShellRoute.
final List<RouteBase> studentCounselingRoutes = [
  GoRoute(
    path: '/student/counseling',
    builder: (context, state) => const StudentCounselingScreen(),
  ),
];
