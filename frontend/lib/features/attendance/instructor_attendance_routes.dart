import 'package:go_router/go_router.dart';

import 'presentation/screens/instructor_attendance_screen.dart';

/// Route table for the instructor attendance feature.
///
/// The orchestrator nests these inside the authenticated `ShellRoute` in
/// `core/router/app_router.dart`, so paths are ABSOLUTE (the shell supplies the
/// top bar + side navigation; the screen renders content only).
///
///   - `/instructor/attendance` → [InstructorAttendanceScreen]
final List<RouteBase> instructorAttendanceRoutes = <RouteBase>[
  GoRoute(
    path: '/instructor/attendance',
    builder: (context, state) => const InstructorAttendanceScreen(),
  ),
];
