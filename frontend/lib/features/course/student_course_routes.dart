import 'package:go_router/go_router.dart';

import 'domain/course_model.dart';
import 'presentation/screens/student_course_day_detail_screen.dart';
import 'presentation/screens/student_course_detail_screen.dart';
import 'presentation/screens/student_course_list_screen.dart';

/// Student course (수업/영상) routes (absolute paths).
///
/// Nested inside the authenticated `ShellRoute` so they inherit the app shell.
/// Intra-feature navigation uses `context.push` against these paths.
///
///   - `/student/courses`               → [StudentCourseListScreen]
///   - `/student/courses/:id`           → [StudentCourseDetailScreen]
///   - `/student/courses/:id/day/:date` → [StudentCourseDayDetailScreen]
///     (`:date` is `YYYY-MM-DD`; read-only 수업 일지 + 영상 재생/다운로드)
///
/// Playback is no longer a dedicated route — videos play in a dialog launched
/// from the day-detail screen (web-native `<video>`, no `video_player` plugin).
final List<RouteBase> studentCourseRoutes = [
  GoRoute(
    path: '/student/courses',
    builder: (context, state) => const StudentCourseListScreen(),
  ),
  GoRoute(
    path: '/student/courses/:id',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null) return const StudentCourseListScreen();
      return StudentCourseDetailScreen(courseId: id);
    },
  ),
  GoRoute(
    path: '/student/courses/:id/day/:date',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      final date = parseDateOnly(state.pathParameters['date']);
      if (id == null || date == null) return const StudentCourseListScreen();
      return StudentCourseDayDetailScreen(courseId: id, date: date);
    },
  ),
];
