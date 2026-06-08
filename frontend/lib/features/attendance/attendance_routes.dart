import 'package:go_router/go_router.dart';

import 'presentation/screens/student_attendance_screen.dart';

/// Route table for the attendance feature.
///
/// The orchestrator nests these inside the authenticated `ShellRoute` in
/// `core/router/app_router.dart`, so paths are ABSOLUTE (the shell supplies the
/// top bar + side navigation; the screen renders content only).
///
///   - `/student/attendance` → [StudentAttendanceScreen]
final List<RouteBase> attendanceRoutes = <RouteBase>[
  GoRoute(
    path: '/student/attendance',
    builder: (context, state) => const StudentAttendanceScreen(),
  ),
];
