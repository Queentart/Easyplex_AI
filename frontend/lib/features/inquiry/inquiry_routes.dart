import 'package:go_router/go_router.dart';

import 'presentation/screens/inquiry_detail_screen.dart';
import 'presentation/screens/inquiry_form_screen.dart';
import 'presentation/screens/inquiry_list_screen.dart';
import 'presentation/screens/license_management_screen.dart';
import 'presentation/screens/staff_support_screen.dart';
import 'presentation/screens/student_inquiry_list_screen.dart';

/// Inquiry / ticket + software-license routes (absolute paths).
///
/// The orchestrator nests these inside the authenticated `ShellRoute` so they
/// inherit the app shell chrome. The SAME screens are mounted under BOTH the
/// Operations (`/ops`) and Tech Support (`/tech`) areas; [basePath] is threaded
/// through so intra-feature navigation (`context.push`) stays within the area
/// the user entered from.
///
///   Operations:
///     - `/ops/issues`        → [InquiryListScreen]   (ticket list)
///     - `/ops/issues/new`    → [InquiryFormScreen]   (create)
///     - `/ops/issues/:id`    → [InquiryDetailScreen] (thread + actions)
///   Tech Support:
///     - `/tech/issues`       → [InquiryListScreen]
///     - `/tech/issues/new`   → [InquiryFormScreen]
///     - `/tech/issues/:id`   → [InquiryDetailScreen]
///     - `/tech/licenses`     → [LicenseManagementScreen] (Tech Support area)
///   Student ("내 문의"):
///     - `/student/inquiries`      → [StudentInquiryListScreen] (own tickets)
///     - `/student/inquiries/new`  → [InquiryFormScreen]        (create)
///     - `/student/inquiries/:id`  → [InquiryDetailScreen]      (read + reply)
///
/// Note: the more specific `/new` route is declared before `/:id` so it is not
/// captured by the dynamic segment.
const String _opsBase = '/ops/issues';
const String _techBase = '/tech/issues';
const String _studentBase = studentInquiryBase; // '/student/inquiries'

List<RouteBase> _issueRoutes(String base) => [
      GoRoute(
        path: base,
        builder: (context, state) => InquiryListScreen(basePath: base),
      ),
      GoRoute(
        path: '$base/new',
        builder: (context, state) => InquiryFormScreen(basePath: base),
      ),
      GoRoute(
        path: '$base/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return InquiryListScreen(basePath: base);
          return InquiryDetailScreen(inquiryId: id, basePath: base);
        },
      ),
    ];

/// Student "내 문의" routes. The list uses the dedicated, mobile-first
/// [StudentInquiryListScreen]; create + detail reuse the shared form/detail
/// screens with the student [_studentBase] so intra-area navigation stays under
/// `/student`. The detail screen shows the thread in read + reply mode and
/// hides handler controls for the student role.
List<RouteBase> _studentInquiryRoutes() => [
      GoRoute(
        path: _studentBase,
        builder: (context, state) => const StudentInquiryListScreen(),
      ),
      GoRoute(
        path: '$_studentBase/new',
        builder: (context, state) =>
            const InquiryFormScreen(basePath: _studentBase),
      ),
      GoRoute(
        path: '$_studentBase/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return const StudentInquiryListScreen();
          return InquiryDetailScreen(inquiryId: id, basePath: _studentBase);
        },
      ),
    ];

/// Staff "지원 · 문의" self-service routes for INSTRUCTOR / OPERATIONS /
/// TECH_SUPPORT. Mirrors the student "내 문의" flow: the list shows the caller's
/// OWN submitted inquiries (`GET /inquiries/` auto-scopes server-side), create
/// + detail reuse the shared [InquiryFormScreen] / [InquiryDetailScreen]. The
/// detail thread renders replies in read + reply mode.
///
/// This is SEPARATE from the ops/tech ticket-management screens
/// (`/ops/issues`, `/tech/issues`) which manage ALL tickets. [base] differs per
/// area so navigation stays within the area the user entered from:
///   - `/instructor/support`
///   - `/ops/support`
///   - `/tech/support`
List<RouteBase> _staffSupportRoutes(String base) => [
      GoRoute(
        path: base,
        builder: (context, state) => StaffSupportListScreen(basePath: base),
      ),
      GoRoute(
        path: '$base/new',
        builder: (context, state) => InquiryFormScreen(basePath: base),
      ),
      GoRoute(
        path: '$base/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return StaffSupportListScreen(basePath: base);
          return InquiryDetailScreen(inquiryId: id, basePath: base);
        },
      ),
    ];

/// Exported staff-support routes. The orchestrator nests these inside the
/// authenticated `ShellRoute` alongside [inquiryRoutes]. Mounts the SAME screen
/// for the three staff areas; the per-area [base] keeps nav/back scoped.
final List<RouteBase> staffSupportRoutes = [
  ..._staffSupportRoutes('/instructor/support'),
  ..._staffSupportRoutes('/ops/support'),
  ..._staffSupportRoutes('/tech/support'),
];

final List<RouteBase> inquiryRoutes = [
  ..._issueRoutes(_opsBase),
  ..._issueRoutes(_techBase),
  ..._studentInquiryRoutes(),
  GoRoute(
    path: '/tech/licenses',
    builder: (context, state) => const LicenseManagementScreen(),
  ),
];
