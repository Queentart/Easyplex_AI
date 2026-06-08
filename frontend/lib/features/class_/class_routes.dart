import 'package:go_router/go_router.dart';

import 'presentation/screens/career_form_screen.dart';
import 'presentation/screens/career_posting_screen.dart';
import 'presentation/screens/class_detail_screen.dart';
import 'presentation/screens/class_evaluation_form_screen.dart';
import 'presentation/screens/class_form_screen.dart';
import 'presentation/screens/class_list_screen.dart';
import 'presentation/screens/curriculum_screen.dart';
import 'presentation/screens/training_log_form_screen.dart';

/// Instructor class-management routes (absolute paths).
///
/// The orchestrator nests these inside the authenticated `ShellRoute` so they
/// inherit the app shell chrome. All intra-feature navigation uses
/// `context.go` / `context.push` against these paths.
///
///   - `/instructor/classes`                    → [ClassListScreen]
///   - `/instructor/classes/new`                → [ClassFormScreen] (create)
///   - `/instructor/classes/:id`                → [ClassDetailScreen]
///   - `/instructor/classes/:id/edit`           → [ClassFormScreen] (edit)
///   - `/instructor/classes/:id/training-log`   → [TrainingLogFormScreen]
///   - `/instructor/curriculum`                 → [CurriculumScreen]
///   - `/instructor/career`                     → [CareerPostingScreen]
///   - `/instructor/career/new`                 → [CareerFormScreen] (admin_ops)
///   - `/student/evaluations`                   → [StudentEvaluationListScreen]
///   - `/student/evaluations/:classId`          → [ClassEvaluationFormScreen]
///
/// Route ordering note: the literal `/instructor/classes/new` is declared
/// before the `/:id` param route so it matches first; likewise the career
/// create route lives under the existing `/instructor/career` tree (chosen over
/// a separate `/ops/...` shell so it inherits the same nav entry — see report).
final List<RouteBase> classRoutes = [
  GoRoute(
    path: '/instructor/classes',
    builder: (context, state) => const ClassListScreen(),
  ),
  GoRoute(
    path: '/instructor/classes/new',
    builder: (context, state) => const ClassFormScreen(),
  ),
  GoRoute(
    path: '/instructor/classes/:id',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null) return const ClassListScreen();
      return ClassDetailScreen(classId: id);
    },
  ),
  GoRoute(
    path: '/instructor/classes/:id/edit',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null) return const ClassListScreen();
      return ClassFormScreen(classId: id);
    },
  ),
  GoRoute(
    path: '/instructor/classes/:id/training-log',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['id'] ?? '');
      if (id == null) return const ClassListScreen();
      return TrainingLogFormScreen(classId: id);
    },
  ),
  GoRoute(
    path: '/instructor/curriculum',
    builder: (context, state) => const CurriculumScreen(),
  ),
  GoRoute(
    path: '/instructor/career',
    builder: (context, state) => const CareerPostingScreen(),
  ),
  GoRoute(
    path: '/instructor/career/new',
    builder: (context, state) => const CareerFormScreen(),
  ),
  GoRoute(
    path: '/student/evaluations',
    builder: (context, state) => const StudentEvaluationListScreen(),
  ),
  GoRoute(
    path: '/student/evaluations/:classId',
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['classId'] ?? '');
      if (id == null) return const StudentEvaluationListScreen();
      return ClassEvaluationFormScreen(classId: id);
    },
  ),
];
