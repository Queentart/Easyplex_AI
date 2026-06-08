import 'package:go_router/go_router.dart';

import 'domain/chat_model.dart';
import 'presentation/screens/chat_screen.dart';

/// Live chat routes (absolute paths).
///
/// The orchestrator nests these inside the authenticated `ShellRoute` so they
/// inherit the app shell chrome. All intra-feature navigation uses
/// `context.go` / `context.push` against these paths.
///
///   - `/chat`             → [ChatChannelListScreen] (cohort live chat channels)
///   - `/chat/:channelId`  → [ChatScreen]            (a live chat room)
///
/// The room route optionally accepts the originating [ChatChannel] via
/// go_router `extra` so the AppBar can show the channel name without an extra
/// fetch; a direct deep-link (no extra) still works — the title falls back to
/// "채팅".
final List<RouteBase> chatRoutes = [
  GoRoute(
    path: '/chat',
    builder: (context, state) => const ChatChannelListScreen(),
    routes: [
      GoRoute(
        path: ':channelId',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['channelId'] ?? '');
          if (id == null) return const ChatChannelListScreen();
          final extra = state.extra;
          final name = extra is ChatChannel ? extra.name : null;
          return ChatScreen(channelId: id, channelName: name);
        },
      ),
    ],
  ),
];
