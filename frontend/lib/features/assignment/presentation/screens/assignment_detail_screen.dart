import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/assignment_model.dart';
import '../assignment_provider.dart';
import 'submission_screen.dart';

/// Student assignment detail + submission. Shows the assignment brief and the
/// student's OWN submission area below it. Never renders other students'
/// submissions — the student view only ever knows about its own work.
class AssignmentDetailScreen extends ConsumerWidget {
  const AssignmentDetailScreen({super.key, required this.assignmentId});

  final int assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(assignmentDetailProvider(assignmentId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: detail.when(
        loading: () => const LoadingView(message: '과제 정보를 불러오는 중입니다…'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(assignmentDetailProvider(assignmentId)),
        ),
        data: (assignment) => _DetailBody(assignment: assignment),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final brief = _AssignmentBrief(assignment: assignment);
    final submission = SubmissionPanel(assignment: assignment);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsiveLayout(
        mobile: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            brief,
            const SizedBox(height: AppSpacing.lg),
            submission,
          ],
        ),
        desktop: (_) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: brief),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: 2, child: submission),
          ],
        ),
      ),
    );
  }
}

class _AssignmentBrief extends StatelessWidget {
  const _AssignmentBrief({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final overdue = assignment.isOverdue();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(assignment.title, style: AppTypography.headlineMd),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: _statusLabel(assignment.status),
                tone: _statusTone(assignment.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DueBanner(assignment: assignment, overdue: overdue),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text('과제 설명', style: AppTypography.headlineSm),
          const SizedBox(height: AppSpacing.sm),
          Text(
            assignment.description,
            style: AppTypography.bodyMd.copyWith(height: 1.5),
          ),
          if (assignment.maxScore != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Icon(Icons.grade_outlined,
                    size: 16, color: AppColors.outline),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '배점 ${assignment.maxScore}점',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(AssignmentStatus s) => switch (s) {
        AssignmentStatus.open => '진행 중',
        AssignmentStatus.closed => '마감',
        AssignmentStatus.archived => '보관',
        AssignmentStatus.unknown => '상태 미정',
      };

  static StatusTone _statusTone(AssignmentStatus s) => switch (s) {
        AssignmentStatus.open => StatusTone.success,
        AssignmentStatus.closed => StatusTone.neutral,
        AssignmentStatus.archived => StatusTone.neutral,
        AssignmentStatus.unknown => StatusTone.neutral,
      };
}

class _DueBanner extends StatelessWidget {
  const _DueBanner({required this.assignment, required this.overdue});

  final Assignment assignment;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final danger = overdue;
    final bg = danger ? AppColors.errorContainer : AppColors.surfaceContainerLow;
    final fg = danger ? AppColors.onErrorContainer : AppColors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            danger ? Icons.warning_amber_rounded : Icons.schedule_rounded,
            size: 18,
            color: danger ? AppColors.error : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '마감 ${DateFormatter.dateTime(assignment.dueDate)}'
              '${danger ? ' · 기한이 지났습니다' : ''}',
              style: AppTypography.labelMd.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
