import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/board_model.dart';
import '../board_provider.dart';
import '../community_paths.dart';

/// Scrollable post list for a single [board]. Used inside the community tab
/// view. Owns its own search field and pull-to-refresh.
class PostListView extends ConsumerStatefulWidget {
  const PostListView({super.key, required this.board});

  final Board board;

  @override
  ConsumerState<PostListView> createState() => _PostListViewState();
}

class _PostListViewState extends ConsumerState<PostListView> {
  final _searchController = TextEditingController();
  String? _activeSearch;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  PostListArgs get _args =>
      PostListArgs(boardId: widget.board.id, search: _activeSearch);

  void _applySearch() {
    final text = _searchController.text.trim();
    setState(() => _activeSearch = text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    final state = ref.watch(postListProvider(args));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          // IntrinsicHeight lets the search field keep its natural height while
          // CrossAxisAlignment.stretch makes the 글쓰기 button match it EXACTLY
          // (verified pixel-equal via the design-gallery probe). A fixed
          // SizedBox(48) instead left the field's filled box shorter than the
          // button; letting the field define the height and stretching the
          // button to it removes the gap.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _applySearch(),
                    decoration: InputDecoration(
                      hintText: '제목·내용 검색',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _activeSearch == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: '검색 초기화',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _activeSearch = null);
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: '글쓰기',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.primary,
                  // Fill the full 48px stretch slot so the visible green fill
                  // matches the search field's height (drops the padded tap
                  // target that would otherwise paint only ~40px).
                  dense: true,
                  onPressed: () => context.push(
                    CommunityPaths.of(context).write,
                    extra: widget.board,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: state.when(
            loading: () => const LoadingView(message: '게시글을 불러오는 중입니다'),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(postListProvider(args)),
            ),
            data: (posts) => posts.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () =>
                        ref.read(postListProvider(args).notifier).refresh(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: posts.length,
                      separatorBuilder: (context, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _PostCard(
                        post: posts[i],
                        onTap: () => context.push(
                          CommunityPaths.of(context).postDetail(posts[i].id),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    if (_activeSearch != null) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: '검색 결과가 없습니다',
        description: '"$_activeSearch"에 해당하는 게시글을 찾지 못했습니다.',
      );
    }
    return const EmptyState(
      icon: Icons.forum_outlined,
      title: '아직 게시글이 없습니다',
      description: '첫 글을 작성해 커뮤니티를 시작해보세요.',
    );
  }
}

/// Single post row card: pin badge, title, anonymity/private markers, meta.
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (post.isPinned) ...[
                const StatusChip(
                  label: '공지',
                  tone: StatusTone.info,
                  icon: Icons.push_pin_rounded,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (post.isPrivate) ...[
                const StatusChip(
                  label: '비밀',
                  tone: StatusTone.neutral,
                  icon: Icons.lock_outline_rounded,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSm,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 14, color: AppColors.outline),
              const SizedBox(width: AppSpacing.xs),
              Text(
                post.isAnonymous ? '익명' : '작성자 #${post.authorId}',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.schedule_rounded,
                  size: 14, color: AppColors.outline),
              const SizedBox(width: AppSpacing.xs),
              Text(
                DateFormatter.relative(post.createdAt),
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const Spacer(),
              if (post.attachments.isNotEmpty) ...[
                Icon(Icons.attach_file_rounded,
                    size: 14, color: AppColors.outline),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${post.attachments.length}',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Icon(Icons.visibility_outlined,
                  size: 14, color: AppColors.outline),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${post.viewCount}',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
