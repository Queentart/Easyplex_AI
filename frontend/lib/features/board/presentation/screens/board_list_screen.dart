import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/board_model.dart';
import '../board_provider.dart';
import 'post_list_screen.dart';

/// A single board paired with the cohort group it belongs to, used to render
/// grouped tabs (one tab per board, headed by its cohort) in the community.
class _GroupedBoard {
  const _GroupedBoard({required this.board, required this.group});

  final Board board;
  final BoardGroup group;
}

/// Flattens [groups] into an ordered list of (group, board) pairs for the tab
/// strip while preserving the group sequence (institution-wide first).
List<_GroupedBoard> _flatten(List<BoardGroup> groups) => [
      for (final group in groups)
        for (final board in group.boards)
          _GroupedBoard(board: board, group: group),
    ];

/// True when more than one labelled group is present, i.e. the staff "기수 전체"
/// aggregated view — drives whether per-board cohort headers are shown.
bool _isGrouped(List<BoardGroup> groups) =>
    groups.length > 1 || (groups.length == 1 && groups.first.title.isNotEmpty);

/// Community entry screen (`/student/community`, `/instructor/community`,
/// `/ops/community`).
///
/// Loads the boards the user can see and renders one tab per board. For staff
/// viewing "기수 전체" the boards are aggregated across every role-scoped cohort
/// and grouped by cohort (each board's tab is headed by its cohort name);
/// students and staff with a specific cohort selected see a single flat group.
/// A floating action button opens the compose screen for the selected board.
class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupedBoardListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: groups.when(
        loading: () => const LoadingView(message: '게시판을 불러오는 중입니다'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(groupedBoardListProvider),
        ),
        data: (groups) {
          final flat = _flatten(groups);
          if (flat.isEmpty) {
            return const EmptyState(
              icon: Icons.dashboard_customize_outlined,
              title: '이용 가능한 게시판이 없습니다',
              description: '게시판이 개설되면 이곳에 표시됩니다.',
            );
          }
          return _BoardTabs(
            entries: flat,
            showCohortHeader: _isGrouped(groups),
          );
        },
      ),
    );
  }
}

class _BoardTabs extends StatefulWidget {
  const _BoardTabs({required this.entries, required this.showCohortHeader});

  final List<_GroupedBoard> entries;
  final bool showCohortHeader;

  @override
  State<_BoardTabs> createState() => _BoardTabsState();
}

class _BoardTabsState extends State<_BoardTabs>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: widget.entries.length, vsync: this);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant _BoardTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) {
      _controller.dispose();
      _controller = TabController(length: widget.entries.length, vsync: this);
      _controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = _controller.index.clamp(0, widget.entries.length - 1);
    final selected = widget.entries[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            0,
          ),
          child: Text('커뮤니티', style: AppTypography.headlineLg),
        ),
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
              for (final e in widget.entries) Tab(text: e.board.name),
            ],
          ),
        ),
        // Cohort section header for the selected board — only shown in the
        // aggregated ("기수 전체") view so single-cohort/student views stay clean.
        if (widget.showCohortHeader)
          _CohortGroupHeader(group: selected.group),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              for (final e in widget.entries) PostListView(board: e.board),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small cohort subtitle/section header shown above the post list in the
/// aggregated community view, identifying which cohort the selected board
/// belongs to (e.g. "1기" or "기수 전체").
class _CohortGroupHeader extends StatelessWidget {
  const _CohortGroupHeader({required this.group});

  final BoardGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          StatusChip(
            label: group.title,
            tone: group.isInstitution ? StatusTone.info : StatusTone.neutral,
            icon: group.isInstitution
                ? Icons.groups_outlined
                : Icons.school_outlined,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '게시판',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
