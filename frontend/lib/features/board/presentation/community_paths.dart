import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Resolves the role-scoped base path for the community (board) screens so the
/// SAME screens can be mounted under several locations:
///
///   - `/student/community`
///   - `/instructor/community`
///   - `/ops/community`
///
/// All intra-feature navigation (post detail, write, edit) must derive its
/// target from [CommunityPaths.of] instead of hard-coding `/student/community`,
/// otherwise an instructor/ops viewer would be bounced into the student tree.
///
/// The base is read from the current go_router location (the prefix up to and
/// including `/community`). It falls back to the student tree when the location
/// doesn't contain a known community prefix (e.g. a deep-link edge case), which
/// keeps existing behavior intact.
class CommunityPaths {
  const CommunityPaths(this.base);

  /// The base path WITHOUT a trailing slash, e.g. `/instructor/community`.
  final String base;

  static const _knownBases = <String>[
    '/student/community',
    '/instructor/community',
    '/ops/community',
  ];

  /// Derives the active community base from the current router location.
  factory CommunityPaths.of(BuildContext context) {
    final location =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    for (final base in _knownBases) {
      if (location == base || location.startsWith('$base/')) {
        return CommunityPaths(base);
      }
    }
    return const CommunityPaths('/student/community');
  }

  String get root => base;
  String get write => '$base/write';
  String postDetail(int postId) => '$base/posts/$postId';
  String postEdit(int postId) => '$base/posts/$postId/edit';
}
