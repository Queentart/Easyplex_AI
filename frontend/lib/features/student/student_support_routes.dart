import 'package:go_router/go_router.dart';

import 'presentation/screens/student_support_screen.dart';

/// Student 지원·문의 route (absolute path).
///
/// The orchestrator nests this inside the authenticated `ShellRoute` so the
/// screen inherits the app shell chrome (side nav + top bar). This REPLACES the
/// placeholder previously mounted at `/student/support`.
///
///   - `/student/support` → [StudentSupportScreen]
///
/// The "지원 · 문의" side-nav item already points at `/student/support`.
final List<RouteBase> studentSupportRoutes = [
  GoRoute(
    path: '/student/support',
    builder: (context, state) => const StudentSupportScreen(),
  ),
];
