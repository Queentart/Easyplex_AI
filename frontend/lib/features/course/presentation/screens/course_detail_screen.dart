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
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../data/course_repository.dart';
import '../../domain/course_model.dart';
import '../course_provider.dart';
import 'course_list_screen.dart' show courseStatusChip;

/// Korean weekday short labels, Mon..Sun (DateTime.weekday is 1=Mon..7=Sun).
const List<String> _koWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _koWeekday(DateTime d) => _koWeekdays[(d.weekday - 1) % 7];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Instructor course detail: course info header (+ 수정), then a virtualized
/// list of every calendar day in the course period. Each day row is TAPPABLE
/// and opens the day-detail screen (수업 일지 + 영상). Indicators on each row show
/// whether a 일지 exists and how many videos are registered for that day.
class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final int courseId;

  bool _canManage(String? role) => role == 'instructor' || role == 'admin_ops';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseState = ref.watch(courseDetailProvider(courseId));
    final user = ref.watch(currentUserProvider);
    final canManage = _canManage(user?.role);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('수업 상세'),
        backgroundColor: AppColors.surface,
      ),
      body: courseState.when(
        loading: () => const LoadingView(message: '수업 정보를 불러오는 중입니다'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(courseDetailProvider(courseId)),
        ),
        data: (course) => _Body(course: course, canManage: canManage),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.course, required this.canManage});

  final Course course;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = course.dayList();
    final videosState = ref.watch(courseVideosProvider(course.id));
    final dayLogsState = ref.watch(courseDayLogsProvider(course.id));

    final logDates = dayLogsState.maybeWhen(
      data: (logs) =>
          logs.where((l) => l.hasContent).map((l) => l.classDate).toList(),
      orElse: () => const <DateTime>[],
    );

    // header (index 0) + one row per calendar day.
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: days.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _CourseHeaderCard(course: course, canManage: canManage),
          );
        }
        final day = days[index - 1];
        final videoCount = videosState.maybeWhen(
          data: (videos) =>
              videos.where((v) => _sameDay(v.classDate, day)).length,
          orElse: () => 0,
        );
        final hasLog = logDates.any((d) => _sameDay(d, day));
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _DayRow(
            courseId: course.id,
            day: day,
            videoCount: videoCount,
            hasLog: hasLog,
          ),
        );
      },
    );
  }
}

class _CourseHeaderCard extends StatelessWidget {
  const _CourseHeaderCard({required this.course, required this.canManage});

  final Course course;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final chip = courseStatusChip(course.status);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(course.title, style: AppTypography.headlineLg),
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
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: '수정',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () =>
                    context.push('/instructor/courses/${course.id}/edit'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable day row → instructor day-detail (수업 일지 + 영상). Shows the date +
/// Korean weekday and small indicators (일지 / 영상 N).
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.courseId,
    required this.day,
    required this.videoCount,
    required this.hasLog,
  });

  final int courseId;
  final DateTime day;
  final int videoCount;
  final bool hasLog;

  @override
  Widget build(BuildContext context) {
    final yyyymmdd = CourseRepository.formatDate(day);
    return AppCard(
      onTap: () => context.push('/instructor/courses/$courseId/day/$yyyymmdd'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 14, color: AppColors.outline),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${DateFormatter.date(day)} (${_koWeekday(day)})',
            style: AppTypography.labelMd,
          ),
          const Spacer(),
          if (hasLog) ...[
            const StatusChip(label: '일지', tone: StatusTone.success),
            const SizedBox(width: AppSpacing.xs),
          ],
          if (videoCount > 0) ...[
            StatusChip(label: '영상 $videoCount', tone: StatusTone.info),
            const SizedBox(width: AppSpacing.sm),
          ],
          Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.outline),
        ],
      ),
    );
  }
}
