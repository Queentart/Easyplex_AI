import 'package:go_router/go_router.dart';

import 'presentation/screens/ai_agent_screen.dart';

/// AI co-pilot routes (absolute paths).
///
/// The orchestrator nests these inside the authenticated `ShellRoute` so they
/// inherit the app shell chrome. The SAME [AiAgentScreen] is mounted under each
/// staff area so intra-area navigation stays within the area the user entered
/// from:
///
///   - `/instructor/ai` → [AiAgentScreen] (Instructors)
///   - `/ops/ai`        → [AiAgentScreen] (Operations team)
///   - `/tech/ai`       → [AiAgentScreen] (Tech support)
///
/// Role guard: per PRD-07 only `admin_ops` / `instructor` / `tech_support` may
/// use the agent. [AiAgentScreen] reads the live role from `currentUserProvider`
/// and shows "접근 권한이 없습니다." for anyone else (students), so these routes are
/// safe to register without a redirect.
final List<RouteBase> aiAgentRoutes = [
  GoRoute(
    path: '/instructor/ai',
    builder: (context, state) => const AiAgentScreen(),
  ),
  GoRoute(
    path: '/ops/ai',
    builder: (context, state) => const AiAgentScreen(),
  ),
  GoRoute(
    path: '/tech/ai',
    builder: (context, state) => const AiAgentScreen(),
  ),
];
