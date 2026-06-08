import 'package:go_router/go_router.dart';

import 'presentation/screens/notification_list_screen.dart';

/// Notification routes (absolute paths).
///
/// The orchestrator nests these inside the authenticated `ShellRoute` so they
/// inherit the app shell chrome. The AppBar bell badge (see `top_bar.dart`)
/// should navigate here via `context.go('/notifications')`.
///
///   - `/notifications` → [NotificationListScreen] (list + mark-read actions)
final List<RouteBase> notificationRoutes = [
  GoRoute(
    path: '/notifications',
    builder: (context, state) => const NotificationListScreen(),
  ),
];
