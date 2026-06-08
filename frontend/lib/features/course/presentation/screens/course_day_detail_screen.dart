import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/file_pick.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
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

/// Instructor day-detail: one calendar day of a course. Two sections:
///   (a) 수업 일지 — a multiline editor (pre-filled from the day's log) + 저장.
///   (b) 영상 — this day's videos (재생 / 다운로드 / 삭제), plus 영상 추가 (pick)
///       and drag-and-drop upload.
class CourseDayDetailScreen extends ConsumerWidget {
  const CourseDayDetailScreen({
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
          _DayLogSection(courseId: courseId, date: date),
          const SizedBox(height: AppSpacing.md),
          _VideoSection(courseId: courseId, date: date),
        ],
      ),
    );
  }
}

/// 수업 일지 editor for one day. Loads the existing log once, lets the
/// instructor edit it, and upserts on 저장.
class _DayLogSection extends ConsumerStatefulWidget {
  const _DayLogSection({required this.courseId, required this.date});

  final int courseId;
  final DateTime date;

  @override
  ConsumerState<_DayLogSection> createState() => _DayLogSectionState();
}

class _DayLogSectionState extends ConsumerState<_DayLogSection> {
  final _controller = TextEditingController();
  bool _loading = true;
  String? _loadError;

  DayLogKey get _key => (courseId: widget.courseId, date: widget.date);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final log = await ref
          .read(courseRepositoryProvider)
          .getDayLog(widget.courseId, widget.date);
      if (!mounted) return;
      _controller.text = log?.content ?? '';
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref
        .read(courseDayLogEditProvider(_key).notifier)
        .save(_controller.text.trim());
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('수업 일지를 저장했습니다.')));
    } else {
      final error = ref.read(courseDayLogEditProvider(_key)).error;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(courseDayLogEditProvider(_key));

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
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _loadError!,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.error),
                  ),
                ),
                AppButton(
                  label: '다시 시도',
                  variant: AppButtonVariant.tertiary,
                  onPressed: _load,
                ),
              ],
            )
          else ...[
            TextField(
              controller: _controller,
              minLines: 5,
              maxLines: 12,
              onChanged: (_) =>
                  ref.read(courseDayLogEditProvider(_key).notifier).clearSaved(),
              decoration: const InputDecoration(
                hintText: '오늘 수업의 진행 내용, 커리큘럼, 공지 등을 기록하세요.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (editState.saved)
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '저장되었습니다.',
                        style: AppTypography.labelSm
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                const Spacer(),
                AppButton(
                  label: '저장',
                  icon: Icons.save_outlined,
                  variant: AppButtonVariant.primary,
                  loading: editState.isSaving,
                  onPressed: editState.isSaving ? null : _save,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 영상 section for one day: list + delete + pick-upload + drag-and-drop.
class _VideoSection extends ConsumerStatefulWidget {
  const _VideoSection({required this.courseId, required this.date});

  final int courseId;
  final DateTime date;

  @override
  ConsumerState<_VideoSection> createState() => _VideoSectionState();
}

class _VideoSectionState extends ConsumerState<_VideoSection> {
  bool _dragging = false;

  Future<void> _pickUpload() async {
    final ok = await ref
        .read(courseUploadProvider(widget.courseId).notifier)
        .pickAndUpload(widget.date);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('영상을 추가했습니다.')));
    } else {
      final error = ref.read(courseUploadProvider(widget.courseId)).error;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) return;
    final file = details.files.first;
    final name = file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!kCourseVideoExtensions.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영상 파일만 업로드할 수 있습니다.')),
      );
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final ok = await ref
        .read(courseUploadProvider(widget.courseId).notifier)
        .uploadBytes(
          widget.date,
          name,
          bytes,
          contentTypeForExtension(ext),
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('영상을 추가했습니다.')));
    } else {
      final error = ref.read(courseUploadProvider(widget.courseId)).error;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(courseUploadProvider(widget.courseId));
    final isUploading = uploadState.isUploadingFor(widget.date);
    final videosState = ref.watch(courseVideosProvider(widget.courseId));
    final videos = videosState.maybeWhen(
      data: (all) => all
          .where((v) => _sameDay(v.classDate, widget.date))
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
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (videos.isEmpty)
            Text(
              '등록된 영상이 없습니다.',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            )
          else
            for (final video in videos)
              _VideoRow(courseId: widget.courseId, video: video),
          const SizedBox(height: AppSpacing.md),
          DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (details) {
              setState(() => _dragging = false);
              if (!isUploading) _onDrop(details);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: _dragging
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _dragging ? AppColors.primary : AppColors.outlineVariant,
                  width: _dragging ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 28,
                    color: _dragging
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isUploading
                        ? '업로드 중입니다...'
                        : '영상 파일을 여기로 끌어다 놓거나 아래 버튼으로 추가하세요.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: '영상 추가',
                    icon: Icons.upload_rounded,
                    variant: AppButtonVariant.secondary,
                    loading: isUploading,
                    onPressed: isUploading ? null : _pickUpload,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One video row with 재생 / 다운로드 / 삭제 (instructor).
class _VideoRow extends ConsumerStatefulWidget {
  const _VideoRow({required this.courseId, required this.video});

  final int courseId;
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('영상 삭제'),
        content: Text('"${widget.video.displayTitle}" 영상을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(courseUploadProvider(widget.courseId).notifier)
        .deleteVideo(widget.video.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('영상을 삭제했습니다.')));
    } else {
      final error = ref.read(courseUploadProvider(widget.courseId)).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? '영상 삭제 중 오류가 발생했습니다.')),
      );
    }
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
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.error,
              iconSize: 20,
              onPressed: _confirmDelete,
            ),
          ],
        ),
      ),
    );
  }
}
