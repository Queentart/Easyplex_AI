/// App-wide constants: API configuration, role codes, and role→home routing.
///
/// Breakpoints are intentionally NOT defined here — reuse [AppBreakpoints]
/// from `core/theme/app_spacing.dart` instead.
library;

/// Base URL for the FastAPI backend (`/api/v1`).
///
/// Resolved at build time from the `API_BASE_URL` compile-time environment
/// value, defaulting to localhost for local dev so the existing dev flow is
/// unchanged. Deployed (Docker/nginx) builds inject a relative path:
///   `flutter build web --dart-define=API_BASE_URL=/api/v1`
/// which makes API calls same-origin (no CORS, single tunnel URL).
///
/// When building for the Android emulator, pass
/// `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1` (the emulator maps
/// the host loopback to 10.0.2.2). A real device needs the host LAN IP instead.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/api/v1',
);

/// Android-emulator equivalent of [apiBaseUrl] (kept for easy reference).
const String apiBaseUrlAndroidEmulator = 'http://10.0.2.2:8000/api/v1';

/// HTTP timeouts (milliseconds).
class ApiTimeouts {
  ApiTimeouts._();

  static const int connectMs = 10000;
  static const int receiveMs = 30000;
  static const int sendMs = 30000;
}

/// Canonical backend role codes. These strings match the `role` field returned
/// by `/auth/login` and `/auth/me`.
class AppRoles {
  AppRoles._();

  static const String adminOps = 'admin_ops';
  static const String techSupport = 'tech_support';
  static const String instructor = 'instructor';
  static const String student = 'student';

  /// The "executive / owner" area is mockup-driven and has no dedicated backend
  /// role yet; it is surfaced to [adminOps] today. Kept as a constant so the
  /// router and nav can reference it without magic strings.
  static const String executive = 'executive';

  static const Set<String> all = {
    adminOps,
    techSupport,
    instructor,
    student,
  };
}

/// Route paths used by the router and navigation widgets.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String student = '/student';
  static const String instructor = '/instructor';
  static const String ops = '/ops';
  static const String tech = '/tech';
  static const String executive = '/executive';

  /// Dev-only design system gallery.
  static const String design = '/design';
}

/// Maps a backend role code to that role's home route.
///
/// admin_ops → /ops, tech_support → /tech, instructor → /instructor,
/// student → /student.
const Map<String, String> roleHomeRoute = {
  AppRoles.adminOps: AppRoutes.ops,
  AppRoles.techSupport: AppRoutes.tech,
  AppRoles.instructor: AppRoutes.instructor,
  AppRoles.student: AppRoutes.student,
};

/// Resolves a role's home route, falling back to [AppRoutes.login] for
/// unknown / null roles.
String homeRouteForRole(String? role) {
  if (role == null) return AppRoutes.login;
  return roleHomeRoute[role] ?? AppRoutes.login;
}
