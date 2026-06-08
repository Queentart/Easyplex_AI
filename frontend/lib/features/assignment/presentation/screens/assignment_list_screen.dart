import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/assignment_model.dart';
import '../assignment_provider.dart';

/// Student assignment list. Mobile-first card layout with the due date strongly
/// emphasized (D-day badge + colored deadline line). Tapping a card opens the
/// detail + submission screen.
class AssignmentListScreen extends ConsumerWidget {
  const AssignmentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assignmentListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: state.when(
        loading: () => const LoadingView(message: '과제를 불러오는 중입니다…'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(assignmentListProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_outlined,
              title: '등록된 과제가 없습니다',
              description: '새 과제가 등록되면 이곳에 표시됩니다.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () =>
                ref.read(assignmentListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _AssignmentTile(assignment: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final dueLabel = _DueDateInfo.from(assignment);

    return AppCard(
      onTap: () => context.push('/student/assignments/${assignment.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assignment.title,
                  style: AppTypography.headlineSm,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(label: dueLabel.badge, tone: dueLabel.tone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            assignment.description,
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 16,
                color: dueLabel.tone == StatusTone.danger
                    ? AppColors.error
                    : AppColors.outline,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '마감 ${DateFormatter.dateTime(assignment.dueDate)}',
                style: AppTypography.labelSm.copyWith(
                  color: dueLabel.tone == StatusTone.danger
                      ? AppColors.error
                      : AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (assignment.allowLateSubmission &&
                  assignment.isOverdue())
                Text(
                  '지각 제출 허용',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Computes the D-day badge + tone for an assignment's due date.
class _DueDateInfo {
  const _DueDateInfo({required this.badge, required this.tone});

  final String badge;
  final StatusTone tone;

  factory _DueDateInfo.from(Assignment a) {
    if (a.status == AssignmentStatus.closed ||
        a.status == AssignmentStatus.archived) {
      return const _DueDateInfo(badge: '마감', tone: StatusTone.neutral);
    }
    final remaining = a.remaining();
    if (remaining.isNegative) {
      return _DueDateInfo(
        badge: a.allowLateSubmission ? '기한 초과' : '마감',
        tone: StatusTone.danger,
      );
    }
    final days = remaining.inDays;
    if (days >= 1) {
      return _DueDateInfo(
        badge: 'D-$days',
        tone: days <= 2 ? StatusTone.warning : StatusTone.info,
      );
    }
    final hours = remaining.inHours;
    return _DueDateInfo(
      badge: hours >= 1 ? 'D-DAY · $hours시간' : 'D-DAY',
      tone: StatusTone.warning,
    );
  }
}
