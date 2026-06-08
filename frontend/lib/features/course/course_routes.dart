import 'package:go_router/go_router.dart';

import 'domain/course_model.dart';
import 'presentation/screens/course_day_detail_screen.dart';
import 'presentation/screens/course_detail_screen.dart';
import 'presentation/screens/course_form_screen.dart';
import 'presentation/screens/course_list_screen.dart';

/// Instructor course (수업/코스) + video routes (absolute paths).
///
/// Nested inside the authenticated `ShellRoute` so they inherit the app shell
/// chrome. All intra-feature navigation uses `context.push` against these paths.
///
///   - `/instructor/courses`            → [CourseListScreen]
///   - `/instructor/courses/new`        → [CourseFormScreen] (create)
///   - `/instructor/courses/:id`        → [CourseDetailScreen]
///   - `/instructor/courses/:id/edit`   → [CourseFormScreen] (edit)
///   - `/instructor/courses/:id/day/:date` → [CourseDayDetailScreen]
///     (`:date` is `YYYY-MM-DD`)
///
/// Route ordering note: the literal `/instructor/courses/new` is declared before
/// the `/:id` param route so it matches first.
final List<RouteBase> courseRoutes = [
  GoRoute(
    path: '/instructor/courses',
    builder: (context, state) => const CourseListScreen(),
  ),
  GoRoute(
    path: '/instructor/courses/new',
    builder: (context, state) => const CourseFormScreen(),
  ),
  GoRoute(
    path: '/instructor/courses/:id',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null) return const CourseListScreen();
      return CourseDetailScreen(courseId: id);
    },
  ),
  GoRoute(
    path: '/instructor/courses/:id/edit',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null) return const CourseListScreen();
      return CourseFormScreen(courseId: id);
    },
  ),
  GoRoute(
    path: '/instructor/courses/:id/day/:date',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      final date = parseDateOnly(state.pathParameters['date']);
      if (id == null || date == null) return const CourseListScreen();
      return CourseDayDetailScreen(courseId: id, date: date);
    },
  ),
];
