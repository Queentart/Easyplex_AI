import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'domain/board_model.dart';
import 'presentation/board_provider.dart';
import 'presentation/screens/board_list_screen.dart';
import 'presentation/screens/board_management_screen.dart';
import 'presentation/screens/notice_list_screen.dart';
import 'presentation/screens/post_detail_screen.dart';
import 'presentation/screens/post_write_screen.dart';

/// Community (board) routes for ALL roles (absolute paths).
///
/// The orchestrator nests these inside the authenticated `ShellRoute` so they
/// inherit the app shell chrome. The SAME screens are mounted under three
/// role-scoped prefixes so students, instructors and operations all read/post
/// in the community; the screens derive their navigation targets from the
/// current location via `CommunityPaths.of` (never hard-coded), so a viewer
/// stays inside their own prefix.
///
/// For each of `/student/community`, `/instructor/community`, `/ops/community`:
///   - `<base>`            → [BoardListScreen] (boards + post list)
///   - `<base>/posts/:id`  → [PostDetailScreen] (post + comments)
///   - `<base>/write`      → [PostWriteScreen]   (compose)
///   - `<base>/posts/:id/edit` → [PostWriteScreen] (edit)
///
/// The write route expects the target [Board] passed via go_router `extra`
/// (see the compose FAB in [BoardListScreen]); a direct hit without it falls
/// back to that prefix's community entry.
List<RouteBase> _communityRoutesFor(String base) => [
      GoRoute(
        path: base,
        builder: (context, state) => const BoardListScreen(),
      ),
      GoRoute(
        path: '$base/posts/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) return const BoardListScreen();
          return PostDetailScreen(postId: id);
        },
      ),
      GoRoute(
        path: '$base/write',
        builder: (context, state) {
          final board = state.extra;
          if (board is! Board) return const BoardListScreen();
          return PostWriteScreen(board: board);
        },
      ),
      GoRoute(
        path: '$base/posts/:id/edit',
        builder: (context, state) {
          final post = state.extra;
          if (post is! Post) return const BoardListScreen();
          return _PostEditEntry(post: post);
        },
      ),
    ];

/// Student community routes (kept as a separate export for backward
/// compatibility with existing router wiring). The instructor/ops community
/// routes live in [communityRoutes].
final List<RouteBase> boardRoutes = _communityRoutesFor('/student/community');

/// Dedicated student 공지사항 route. Shows ONLY notice-type board content (boards
/// where `type == 'notice'`), isolated from the general 커뮤니티 tab. Post detail
/// navigation reuses the community post-detail routes ([boardRoutes]) via
/// `CommunityPaths` (the student fallback), so no extra detail route is needed.
final List<RouteBase> noticeRoutes = [
  GoRoute(
    path: '/student/notices',
    builder: (context, state) => const NoticeListScreen(),
  ),
];

/// Instructor + operations community routes (#10/#11 — expose read/post to
/// instructors and ops, not just board management). Wire these into the
/// authenticated shell alongside [boardRoutes]:
///
///   - `/instructor/community`(+ `/posts/:id`, `/write`, `/posts/:id/edit`)
///   - `/ops/community`        (+ `/posts/:id`, `/write`, `/posts/:id/edit`)
final List<RouteBase> communityRoutes = [
  ..._communityRoutesFor('/instructor/community'),
  ..._communityRoutesFor('/ops/community'),
];

/// Resolves the [Board] for an edit deep-link from the post's `board_id` so the
/// reused [PostWriteScreen] can show the board name. Falls back to a minimal
/// board (name unknown) when the board list isn't loaded — edit mode hides the
/// board-dependent option toggles anyway, so only the title is affected.
class _PostEditEntry extends ConsumerWidget {
  const _PostEditEntry({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(boardListProvider).value;
    final board = boards?.cast<Board?>().firstWhere(
              (b) => b?.id == post.boardId,
              orElse: () => null,
            ) ??
        Board(id: post.boardId, name: '게시글', type: '');
    return PostWriteScreen(board: board, editPost: post);
  }
}

/// Board management routes for operations team and instructors (absolute
/// paths). The orchestrator nests these inside the authenticated `ShellRoute`
/// and wires the matching nav items. Both paths render the same
/// [BoardManagementScreen]; the screen itself role-gates the controls.
///
///   - `/ops/boards`        → [BoardManagementScreen] (운영팀)
///   - `/instructor/boards` → [BoardManagementScreen] (강사)
final List<RouteBase> boardManagementRoutes = [
  GoRoute(
    path: '/ops/boards',
    builder: (context, state) => const BoardManagementScreen(),
  ),
  GoRoute(
    path: '/instructor/boards',
    builder: (context, state) => const BoardManagementScreen(),
  ),
];
