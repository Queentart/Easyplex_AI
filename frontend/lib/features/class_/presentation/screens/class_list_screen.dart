import '../../../../core/app_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
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
import '../../domain/class_model.dart';
import '../class_provider.dart';

/// Instructor class-management entry: the list of class sessions assigned to /
/// visible to the current instructor. Tapping a row opens the class detail.
class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classListProvider);
    final user = ref.watch(currentUserProvider);
    final canCreate = user?.role == 'instructor' || user?.role == 'admin_ops';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(AppLabels.classManagement, style: AppTypography.headlineLg),
                  ),
                  IconButton(
                    tooltip: '커리큘럼',
                    icon: const Icon(Icons.account_tree_outlined),
                    color: AppColors.outline,
                    onPressed: () => context.push('/instructor/curriculum'),
                  ),
                  IconButton(
                    tooltip: '취업·자격 공지',
                    icon: const Icon(Icons.work_outline_rounded),
                    color: AppColors.outline,
                    onPressed: () => context.push('/instructor/career'),
                  ),
                  if (canCreate) ...[
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      label: '수업 생성',
                      icon: Icons.add_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: () =>
                          context.push('/instructor/classes/new'),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: state.when(
                loading: () => const LoadingView(message: '수업 목록을 불러오는 중입니다'),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(classListProvider),
                ),
                data: (classes) => classes.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: '등록된 수업이 없습니다',
                        description: '담당 기수에 수업이 배정되면 이곳에 표시됩니다.',
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () =>
                            ref.read(classListProvider.notifier).refresh(),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: classes.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) => _ClassCard(
                            session: classes[i],
                            onTap: () => context.push(
                              '/instructor/classes/${classes[i].id}',
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps a backend class status to a [StatusChip] tone + Korean label.
({String label, StatusTone tone}) classStatusChip(String status) {
  return switch (status) {
    'completed' => (label: '완료', tone: StatusTone.success),
    'ongoing' => (label: '진행 중', tone: StatusTone.info),
    'cancelled' => (label: '취소', tone: StatusTone.danger),
    _ => (label: '예정', tone: StatusTone.neutral),
  };
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.session, required this.onTap});

  final ClassSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = classStatusChip(session.status);
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
              Expanded(
                child: Text(
                  session.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSm,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(label: chip.label, tone: chip.tone),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppColors.outline),
              const SizedBox(width: AppSpacing.xs),
              Text(
                DateFormatter.date(session.date),
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              if (session.timeRange.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.schedule_rounded,
                    size: 14, color: AppColors.outline),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  session.timeRange,
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
              if (session.location != null &&
                  session.location!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                Icon(Icons.place_outlined, size: 14, color: AppColors.outline),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    session.location!,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
