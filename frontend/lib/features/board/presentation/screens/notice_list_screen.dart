import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../domain/board_model.dart';
import '../board_provider.dart';
import 'post_list_screen.dart';

/// Student 공지사항 screen (`/student/notices`).
///
/// Shows ONLY notice-type board content — i.e. posts from boards whose
/// free-form `type == 'notice'` (see [noticeBoardListProvider]) — kept separate
/// from the general 커뮤니티 tab. When a single notice board exists its posts are
/// shown directly; multiple notice boards are split into tabs (one per board).
/// Reuses [PostListView] verbatim so post rows / search / refresh behave exactly
/// like the community. Read-only here: notices are authored by staff, so this
/// screen intentionally has no compose FAB.
class NoticeListScreen extends ConsumerWidget {
  const NoticeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(noticeBoardListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: boards.when(
          loading: () => const LoadingView(message: '공지사항을 불러오는 중입니다'),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(noticeBoardListProvider),
          ),
          data: (boards) {
            if (boards.isEmpty) {
              return const _NoticeHeaderColumn(
                child: Expanded(
                  child: EmptyState(
                    icon: Icons.campaign_outlined,
                    title: '등록된 공지사항이 없습니다',
                    description: '새로운 공지가 등록되면 이곳에 표시됩니다.',
                  ),
                ),
              );
            }
            if (boards.length == 1) {
              return _NoticeHeaderColumn(
                child: Expanded(child: PostListView(board: boards.first)),
              );
            }
            return _NoticeTabs(boards: boards);
          },
        ),
      ),
    );
  }
}

/// Page title above whatever notice content follows.
class _NoticeHeaderColumn extends StatelessWidget {
  const _NoticeHeaderColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _NoticeTitle(),
        child,
      ],
    );
  }
}

class _NoticeTitle extends StatelessWidget {
  const _NoticeTitle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        0,
      ),
      child: Text(AppLabels.notices, style: AppTypography.headlineLg),
    );
  }
}

/// One tab per notice board when more than one exists.
class _NoticeTabs extends StatefulWidget {
  const _NoticeTabs({required this.boards});

  final List<Board> boards;

  @override
  State<_NoticeTabs> createState() => _NoticeTabsState();
}

class _NoticeTabsState extends State<_NoticeTabs>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.boards.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _NoticeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boards.length != widget.boards.length) {
      _controller.dispose();
      _controller = TabController(length: widget.boards.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _NoticeTitle(),
        Material(
          color: AppColors.surface,
          child: TabBar(
            controller: _controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            tabs: [
              for (final b in widget.boards) Tab(text: b.name),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              for (final b in widget.boards) PostListView(board: b),
            ],
          ),
        ),
      ],
    );
  }
}
