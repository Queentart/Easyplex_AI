import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../domain/class_model.dart';
import '../class_provider.dart';

/// Curriculum tree + progress for the instructor's cohort.
///
/// Items are grouped by week; children (via `parent_item_id`) nest under their
/// parent. The instructor can toggle completion, which optimistically updates
/// the overall progress bar (server enforces the actual write).
class CurriculumScreen extends ConsumerWidget {
  const CurriculumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final cohortId = user?.cohortId;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('커리큘럼'),
        backgroundColor: AppColors.surface,
      ),
      body: cohortId == null
          ? const EmptyState(
              icon: Icons.school_outlined,
              title: '연결된 기수가 없습니다',
              description: '담당 기수가 배정되면 커리큘럼이 표시됩니다.',
            )
          : _CurriculumBody(cohortId: cohortId),
    );
  }
}

class _CurriculumBody extends ConsumerWidget {
  const _CurriculumBody({required this.cohortId});

  final int cohortId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(curriculumProvider(cohortId));

    return state.when(
      loading: () => const LoadingView(message: '커리큘럼을 불러오는 중입니다'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(curriculumProvider(cohortId)),
      ),
      data: (items) => items.isEmpty
          ? const EmptyState(
              icon: Icons.account_tree_outlined,
              title: '등록된 커리큘럼이 없습니다',
              description: '운영팀 또는 강사가 커리큘럼을 등록하면 이곳에 표시됩니다.',
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () =>
                  ref.read(curriculumProvider(cohortId).notifier).refresh(),
              child: _Tree(cohortId: cohortId, items: items),
            ),
    );
  }
}

class _Tree extends ConsumerWidget {
  const _Tree({required this.cohortId, required this.items});

  final int cohortId;
  final List<CurriculumItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leaf items drive progress (a parent is "done" only through its children,
    // but parents without children count as leaves too).
    final parentIds = items
        .map((e) => e.parentItemId)
        .whereType<int>()
        .toSet();
    final leaves = items.where((e) => !parentIds.contains(e.id)).toList();
    final completed = leaves.where((e) => e.isCompleted).length;
    final progress = leaves.isEmpty ? 0.0 : completed / leaves.length;

    // Group by week, preserving server order.
    final weeks = <int, List<CurriculumItem>>{};
    for (final item in items) {
      weeks.putIfAbsent(item.week, () => []).add(item);
    }
    final weekKeys = weeks.keys.toList()..sort();

    // Children grouped by parent for nesting.
    final childrenByParent = <int, List<CurriculumItem>>{};
    for (final item in items) {
      final parent = item.parentItemId;
      if (parent != null) {
        childrenByParent.putIfAbsent(parent, () => []).add(item);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('진행률', style: AppTypography.headlineSm),
                  ),
                  Text(
                    '$completed / ${leaves.length} (${(progress * 100).round()}%)',
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppProgressBar(value: progress),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final week in weekKeys) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
              top: AppSpacing.sm,
            ),
            child: Text('$week주차', style: AppTypography.headlineSm),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final item in weeks[week]!.where((e) => e.isRoot))
                  ...[
                    _CurriculumRow(
                      cohortId: cohortId,
                      item: item,
                      depth: 0,
                    ),
                    for (final child in childrenByParent[item.id] ?? const [])
                      _CurriculumRow(
                        cohortId: cohortId,
                        item: child,
                        depth: 1,
                      ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _CurriculumRow extends ConsumerWidget {
  const _CurriculumRow({
    required this.cohortId,
    required this.item,
    required this.depth,
  });

  final int cohortId;
  final CurriculumItem item;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _toggle(context, ref),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md + depth * AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: item.isCompleted ? AppColors.primary : AppColors.outline,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.topic,
                    style: AppTypography.bodyMd.copyWith(
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.isCompleted
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                    ),
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.description!,
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (item.plannedHours != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${item.plannedHours}h',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(curriculumProvider(cohortId).notifier)
          .toggleCompleted(item.id, !item.isCompleted);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}
