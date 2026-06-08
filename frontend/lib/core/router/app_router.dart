import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_routes.dart';
import '../../features/ai_agent/ai_agent_routes.dart';
import '../../features/assignment/assignment_routes.dart';
import '../../features/assignment/grading_routes.dart';
import '../../features/attendance/admin_attendance_routes.dart';
import '../../features/attendance/attendance_routes.dart';
import '../../features/attendance/instructor_attendance_routes.dart';
import '../../features/auth/presentation/screens/login_page.dart';
import '../../features/board/board_routes.dart';
import '../../features/chat/chat_routes.dart';
import '../../features/class_/class_routes.dart';
import '../../features/course/course_routes.dart';
import '../../features/course/student_course_routes.dart';
import '../../features/design_system/design_gallery_page.dart';
import '../../features/inquiry/inquiry_routes.dart';
import '../../features/leave/leave_routes.dart';
import '../../features/mentoring/mentoring_routes.dart';
import '../../features/executive/executive_routes.dart';
import '../../features/notification/notification_routes.dart';
import '../../features/settings/settings_routes.dart';
import '../../features/student/student_counseling_routes.dart';
import '../../features/student/student_support_routes.dart';
import '../../features/executive/presentation/screens/executive_dashboard_page.dart';
import '../../features/instructor/presentation/screens/instructor_dashboard_page.dart';
import '../../features/operations/presentation/screens/ops_dashboard_page.dart';
import '../../features/student/presentation/screens/student_dashboard_page.dart';
import '../../features/tech_support/presentation/screens/tech_dashboard_page.dart';
import '../../shared/widgets/app_shell.dart';
import '../constants.dart';
import '../providers.dart';

/// Routes that don't require authentication.
const _publicRoutes = <String>{
  AppRoutes.login,
  AppRoutes.design, // dev-only gallery; reachable without login
};

/// Builds the app [GoRouter].
///
/// Guards:
///   - While auth is still initializing, no redirect (avoids flicker).
///   - Unauthenticated user hitting a protected route → /login.
///   - Authenticated user on /welcome or /login → their role home.
///   - Authenticated user hitting a route outside their role area → role home.
///
/// The router rebuilds its redirect whenever [authStateProvider] changes via a
/// [_RouterRefresh] listenable bridged to Riverpod.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.onDispose(refresh.dispose);

  ref.listen<AuthState>(
    authStateProvider,
    (previous, next) => refresh.notify(),
  );

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: refresh,
    errorBuilder: (context, state) => const _RouteNotFoundPage(),
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final location = state.uri.path;

      // Hold redirects until session restore finishes.
      if (auth.isInitializing) return null;

      final isPublic = _publicRoutes.contains(location);

      // Not logged in → only public routes allowed.
      if (!auth.isAuthenticated) {
        return isPublic ? null : AppRoutes.login;
      }

      // Logged in: bounce away from the login screen to the role home.
      final home = homeRouteForRole(auth.role);
      if (location == AppRoutes.login) {
        return home;
      }

      // Keep a user inside their own role area (dashboards only at this stage).
      // /design stays reachable for everyone in dev.
      if (location != AppRoutes.design && !location.startsWith(home)) {
        // Only redirect when landing on another role's root area.
        if (_isRoleRoot(location)) return home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.design,
        builder: (context, state) => const DesignGalleryPage(),
      ),

      // Authenticated role areas wrapped in the app shell.
      ShellRoute(
        builder: (context, state, child) => _ShellForLocation(
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.student,
            builder: (context, state) => const StudentDashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.instructor,
            builder: (context, state) => const InstructorDashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.ops,
            builder: (context, state) => const OpsDashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.tech,
            builder: (context, state) => const TechDashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.executive,
            builder: (context, state) => const ExecutiveDashboardPage(),
          ),

          // ── Feature routes (F2: student core) ──────────────────────────
          ...attendanceRoutes,
          ...boardRoutes,
          ...noticeRoutes,
          ...assignmentRoutes,
          ...leaveRoutes,
          ...studentCourseRoutes,

          // ── Feature routes (F3: instructor) ────────────────────────────
          ...instructorAttendanceRoutes,
          ...gradingRoutes,
          ...classRoutes,
          ...courseRoutes,
          ...mentoringRoutes,

          // ── Feature routes (F4: ops / tech support) ────────────────────
          ...adminAttendanceRoutes,
          ...adminRoutes,
          ...inquiryRoutes,

          // ── Feature routes (F5: advanced — chat / AI / notifications) ──
          ...chatRoutes,
          ...aiAgentRoutes,
          ...notificationRoutes,

          // ── S1: backend-backed UI fill (board mgmt / leave approval / settings) ──
          ...boardManagementRoutes,
          ...leaveApprovalRoutes,
          ...settingsRoutes,

          // ── Batch 2/3: instructor·ops community + student counseling ──
          ...communityRoutes,
          ...studentCounselingRoutes,

          // ── Staff 지원·문의 (instructor/ops/tech: create + my inquiries) ──
          ...staffSupportRoutes,

          // ── S2: mock-data screens (analytics / student support) ──
          // NOTE: operations infra/system screens (status/logs/sync/settings)
          // belong to the future platform super_admin tier, NOT the in-house
          // class-operations team (see sources/0531 멀티테넌시 memo). Their code
          // is kept under features/operations but intentionally NOT routed here.
          ...executiveMockRoutes,
          ...studentSupportRoutes,
        ],
      ),
    ],
  );
});

/// True when [location] is a role area root (used to block cross-role roots).
bool _isRoleRoot(String location) {
  return location == AppRoutes.student ||
      location == AppRoutes.instructor ||
      location == AppRoutes.ops ||
      location == AppRoutes.tech ||
      location == AppRoutes.executive;
}

/// Picks the shell title from the current location.
class _ShellForLocation extends StatelessWidget {
  const _ShellForLocation({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppShell(title: _titleFor(location), child: child);
  }

  String _titleFor(String location) {
    if (location.startsWith(AppRoutes.student)) return '수강생';
    if (location.startsWith(AppRoutes.instructor)) return '강사';
    if (location.startsWith(AppRoutes.ops)) return '운영팀';
    if (location.startsWith(AppRoutes.tech)) return '기술지원';
    if (location.startsWith(AppRoutes.executive)) return '경영진';
    return 'DongA AI Lab';
  }
}

/// Bridges Riverpod auth changes to go_router's [refreshListenable].
class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Graceful fallback for unknown routes (instead of go_router's red error box).
class _RouteNotFoundPage extends StatelessWidget {
  const _RouteNotFoundPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text('페이지를 찾을 수 없습니다', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '요청하신 화면이 없거나 아직 준비 중입니다.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('홈으로'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
