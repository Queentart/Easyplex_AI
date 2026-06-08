import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_labels.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/list_header.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/course_model.dart';
import '../course_provider.dart';

/// Instructor course-management entry: the list of courses (수업) the instructor
/// manages. Tapping a card opens the course detail. Course creation lives in the
/// header action (no FloatingActionButton).
class CourseListScreen extends ConsumerWidget {
  const CourseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseListProvider);
    final user = ref.watch(currentUserProvider);
    final canCreate = user?.role == 'instructor' || user?.role == 'admin_ops';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListHeader(
              title: AppLabels.courses,
              action: canCreate
                  ? AppButton(
                      label: '수업 생성',
                      icon: Icons.add_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: () =>
                          context.push('/instructor/courses/new'),
                    )
                  : null,
            ),
            Expanded(
              child: state.when(
                loading: () =>
                    const LoadingView(message: '수업 목록을 불러오는 중입니다'),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(courseListProvider),
                ),
                data: (courses) => courses.isEmpty
                    ? const EmptyState(
                        icon: Icons.video_library_outlined,
                        title: '등록된 수업이 없습니다',
                        description: '우측 상단 "수업 생성"으로 첫 수업을 만들어 보세요.',
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () =>
                            ref.read(courseListProvider.notifier).refresh(),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: courses.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) => _CourseCard(
                            course: courses[i],
                            onTap: () => context.push(
                              '/instructor/courses/${courses[i].id}',
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

/// Maps a [CourseStatus] to a [StatusChip] tone + Korean label.
({String label, StatusTone tone}) courseStatusChip(CourseStatus status) {
  return switch (status) {
    CourseStatus.active => (label: '진행 중', tone: StatusTone.info),
    CourseStatus.archived => (label: '보관됨', tone: StatusTone.neutral),
    CourseStatus.unknown => (label: '상태 미정', tone: StatusTone.neutral),
  };
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = courseStatusChip(course.status);
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
                  course.title,
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
              Icon(Icons.date_range_rounded,
                  size: 14, color: AppColors.outline),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${DateFormatter.date(course.startDate)} ~ ${DateFormatter.date(course.endDate)}',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          if (course.description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              course.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
