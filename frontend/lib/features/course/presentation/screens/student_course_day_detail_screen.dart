import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/course_repository.dart';
import '../../domain/course_model.dart';
import '../course_provider.dart';
import 'video_actions.dart';

/// Korean weekday short labels, Mon..Sun (DateTime.weekday is 1=Mon..7=Sun).
const List<String> _koWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _koWeekday(DateTime d) => _koWeekdays[(d.weekday - 1) % 7];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Student day-detail (read-only): the day's 수업 일지 + the day's videos with
/// 재생 / 다운로드. No editing or uploading.
class StudentCourseDayDetailScreen extends ConsumerWidget {
  const StudentCourseDayDetailScreen({
    super.key,
    required this.courseId,
    required this.date,
  });

  final int courseId;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('${DateFormatter.date(date)} (${_koWeekday(date)})'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _DayLogCard(courseId: courseId, date: date),
          const SizedBox(height: AppSpacing.md),
          _VideoCard(courseId: courseId, date: date),
        ],
      ),
    );
  }
}

/// Read-only 수업 일지 card. Fetches the single day's log on build.
class _DayLogCard extends ConsumerStatefulWidget {
  const _DayLogCard({required this.courseId, required this.date});

  final int courseId;
  final DateTime date;

  @override
  ConsumerState<_DayLogCard> createState() => _DayLogCardState();
}

class _DayLogCardState extends ConsumerState<_DayLogCard> {
  late Future<CourseDayLog?> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(courseRepositoryProvider)
        .getDayLog(widget.courseId, widget.date);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_outlined,
                  size: 18, color: AppColors.outline),
              const SizedBox(width: AppSpacing.sm),
              Text('수업 일지', style: AppTypography.headlineSm),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<CourseDayLog?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  snapshot.error.toString(),
                  style: AppTypography.bodySm.copyWith(color: AppColors.error),
                );
              }
              final log = snapshot.data;
              if (log == null || !log.hasContent) {
                return Text(
                  '등록된 일지가 없습니다.',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                );
              }
              return Text(log.content, style: AppTypography.bodyMd);
            },
          ),
        ],
      ),
    );
  }
}

/// Read-only video list card for one day (재생 / 다운로드).
class _VideoCard extends ConsumerWidget {
  const _VideoCard({required this.courseId, required this.date});

  final int courseId;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosState = ref.watch(courseVideosProvider(courseId));
    final videos = videosState.maybeWhen(
      data: (all) => all
          .where((v) => _sameDay(v.classDate, date))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      orElse: () => const <CourseVideo>[],
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.video_library_outlined,
                  size: 18, color: AppColors.outline),
              const SizedBox(width: AppSpacing.sm),
              Text('영상', style: AppTypography.headlineSm),
              const Spacer(),
              if (videos.isNotEmpty)
                Text(
                  '영상 ${videos.length}개',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (videosState.isLoading && videos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (videos.isEmpty)
            Text(
              '등록된 영상이 없습니다.',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            )
          else
            for (final video in videos) _VideoRow(video: video),
        ],
      ),
    );
  }
}

/// One read-only video row with 재생 / 다운로드.
class _VideoRow extends ConsumerStatefulWidget {
  const _VideoRow({required this.video});

  final CourseVideo video;

  @override
  ConsumerState<_VideoRow> createState() => _VideoRowState();
}

class _VideoRowState extends ConsumerState<_VideoRow> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    await VideoActions.download(context, ref, widget.video);
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(Icons.play_circle_outline_rounded,
                size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.video.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMd,
              ),
            ),
            IconButton(
              tooltip: '재생',
              icon: const Icon(Icons.play_arrow_rounded),
              color: AppColors.primary,
              iconSize: 22,
              onPressed: () => VideoActions.play(context, ref, widget.video),
            ),
            IconButton(
              tooltip: '다운로드',
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              color: AppColors.onSurfaceVariant,
              iconSize: 20,
              onPressed: _downloading ? null : _download,
            ),
          ],
        ),
      ),
    );
  }
}
