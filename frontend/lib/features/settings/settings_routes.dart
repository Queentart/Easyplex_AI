import 'package:go_router/go_router.dart';

import 'presentation/screens/settings_screen.dart';

/// Account settings routes (available to ALL roles).
///
/// Exposed as a list of [RouteBase] with an ABSOLUTE path so the orchestrator
/// can nest it inside the authenticated `ShellRoute` in
/// `core/router/app_router.dart`:
///
///   - `/settings` → [SettingsScreen]
///
/// The top_bar account menu's "설정" item should navigate to `/settings`.
final List<RouteBase> settingsRoutes = <RouteBase>[
  GoRoute(
    path: SettingsScreen.routePath,
    builder: (context, state) => const SettingsScreen(),
  ),
];
