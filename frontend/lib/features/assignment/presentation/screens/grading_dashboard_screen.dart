/// INSTRUCTOR assignment-grading dashboard (tablet / PC-first).
///
/// Left: a list of the instructor's assignments (picker). Right: the submission
/// table for the selected assignment (status, submitted time, score) plus a
/// feedback/score editor opened per row. A "새 과제" action opens an
/// assignment-create dialog.
///
/// Reuses design-system tokens + components only (no hardcoded colors / magic
/// numbers): [AppDataTable], [StatusChip], [AppButton], [AppProgressBar],
/// [AppCard]/[AppSectionCard], loading/error/empty views.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../data/grading_repository.dart';
import '../../domain/assignment_model.dart';
import '../grading_provider.dart';

/// Maps a [SubmissionStatus] to its Korean label + chip tone.
({String label, StatusTone tone}) _statusChip(SubmissionStatus status) {
  switch (status) {
    case SubmissionStatus.reviewed:
      return (label: '평가 완료', tone: StatusTone.success);
    case SubmissionStatus.resubmitRequested:
      return (label: '재제출 요청', tone: StatusTone.warning);
    case SubmissionStatus.submitted:
      return (label: '평가 대기', tone: StatusTone.info);
    case SubmissionStatus.unknown:
      return (label: '알 수 없음', tone: StatusTone.neutral);
  }
}

class GradingDashboardScreen extends ConsumerStatefulWidget {
  const GradingDashboardScreen({super.key, this.selectedAssignmentId});

  /// Optional assignment id (from `/instructor/assignments/:id/submissions`).
  final int? selectedAssignmentId;

  @override
  ConsumerState<GradingDashboardScreen> createState() =>
      _GradingDashboardScreenState();
}

class _GradingDashboardScreenState
    extends ConsumerState<GradingDashboardScreen> {
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedAssignmentId;
  }

  void _select(int id) => setState(() => _selectedId = id);

  Future<void> _openCreate() async {
    final cohortId = ref.read(currentUserProvider)?.cohortId;
    if (cohortId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('소속 기수 정보가 없어 과제를 생성할 수 없습니다.')),
      );
      return;
    }
    final created = await showDialog<Assignment>(
      context: context,
      builder: (_) => _AssignmentCreateDialog(cohortId: cohortId),
    );
    if (created != null && mounted) {
      ref.read(gradingAssignmentsProvider.notifier).refresh();
      _select(created.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('과제 "${created.title}"가 생성되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(gradingAssignmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: assignmentsAsync.when(
        loading: () => const LoadingView(message: '과제 목록을 불러오는 중입니다…'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.read(gradingAssignmentsProvider.notifier).refresh(),
        ),
        data: (assignments) {
          if (assignments.isEmpty) {
            return EmptyState(
              icon: Icons.assignment_outlined,
              title: '등록된 과제가 없습니다',
              description: '새 과제를 등록하면 제출물을 평가할 수 있습니다.',
              action: AppButton(
                label: '새 과제',
                icon: Icons.add_rounded,
                onPressed: _openCreate,
              ),
            );
          }

          // Default-select the first assignment when nothing is chosen yet.
          final selectedId = _selectedId ??
              (assignments.isNotEmpty ? assignments.first.id : null);
          final selected = assignments
              .where((a) => a.id == selectedId)
              .cast<Assignment?>()
              .firstWhere((_) => true, orElse: () => null);

          final picker = _AssignmentPicker(
            assignments: assignments,
            selectedId: selectedId,
            onSelect: _select,
            onCreate: _openCreate,
          );

          final detail = selected == null
              ? const EmptyState(
                  icon: Icons.touch_app_outlined,
                  title: '과제를 선택하세요',
                  description: '왼쪽 목록에서 평가할 과제를 선택하면 제출 현황이 표시됩니다.',
                )
              : _SubmissionsPanel(assignment: selected);

          return ResponsiveLayout(
            // Mobile: stack picker above the panel (picker collapses to a
            // horizontal selector via the same widget's compact rendering).
            mobile: (_) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 220, child: picker),
                const Divider(height: 1),
                Expanded(child: detail),
              ],
            ),
            tablet: (_) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 320, child: picker),
                const VerticalDivider(width: 1),
                Expanded(child: detail),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Left column: list of assignments + a create button.
class _AssignmentPicker extends StatelessWidget {
  const _AssignmentPicker({
    required this.assignments,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
  });

  final List<Assignment> assignments;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text('과제', style: AppTypography.headlineSm),
              ),
              AppButton(
                label: '새 과제',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: onCreate,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: assignments.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final a = assignments[i];
              final selected = a.id == selectedId;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => onSelect(a.id),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.secondaryContainer
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title,
                          style: AppTypography.labelMd,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '마감 ${DateFormatter.dateTime(a.dueDate)}',
                          style: AppTypography.labelSm
                              .copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Right column: submission summary + table for one assignment.
class _SubmissionsPanel extends ConsumerWidget {
  const _SubmissionsPanel({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(submissionRowsProvider(assignment.id));

    return rowsAsync.when(
      loading: () => const LoadingView(message: '제출물을 불러오는 중입니다…'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () =>
            ref.read(submissionRowsProvider(assignment.id).notifier).refresh(),
      ),
      data: (rows) {
        final graded =
            rows.where((r) => r.status == SubmissionStatus.reviewed).length;
        final progress = rows.isEmpty ? 0.0 : graded / rows.length;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Header card: title + grading progress.
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(assignment.title, style: AppTypography.headlineMd),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    assignment.description,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(Icons.event_outlined,
                          size: 16, color: AppColors.outline),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '마감 ${DateFormatter.dateTime(assignment.dueDate)}',
                        style: AppTypography.labelSm,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      if (assignment.maxScore != null)
                        Text(
                          '배점 ${assignment.maxScore}점',
                          style: AppTypography.labelSm,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text(
                        '평가 진행 $graded / ${rows.length}',
                        style: AppTypography.labelSm,
                      ),
                      const Spacer(),
                      Text('${(progress * 100).round()}%',
                          style: AppTypography.labelSm),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppProgressBar(value: progress),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: EmptyState(
                  icon: Icons.inbox_outlined,
                  title: '아직 제출물이 없습니다',
                  description: '수강생이 과제를 제출하면 이곳에서 평가할 수 있습니다.',
                ),
              )
            else
              _SubmissionsTable(
                assignmentId: assignment.id,
                rows: rows,
              ),
          ],
        );
      },
    );
  }
}

/// Submission rows rendered with the design-system [AppDataTable].
class _SubmissionsTable extends ConsumerWidget {
  const _SubmissionsTable({required this.assignmentId, required this.rows});

  final int assignmentId;
  final List<SubmissionRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppDataTable(
      columns: const ['수강생', '상태', '제출 시각', '점수', ''],
      columnFlex: const [3, 2, 3, 1, 2],
      rows: [
        for (final row in rows)
          AppTableRow(
            highlight: row.isLate &&
                row.status != SubmissionStatus.reviewed,
            cells: [
              Text(
                row.studentName ?? '수강생 #${row.studentId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Builder(builder: (_) {
                final chip = _statusChip(row.status);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(label: chip.label, tone: chip.tone),
                );
              }),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      DateFormatter.dateTime(row.submittedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (row.isLate) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const StatusChip(label: '지각', tone: StatusTone.danger),
                  ],
                ],
              ),
              Text(row.score?.toString() ?? '-'),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: row.isGraded ? '수정' : '평가',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _openEditor(context, ref, row),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    SubmissionRow row,
  ) async {
    final updated = await showModalBottomSheet<Submission>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _FeedbackEditorSheet(row: row),
    );
    if (updated != null && context.mounted) {
      ref
          .read(submissionRowsProvider(assignmentId).notifier)
          .applyGraded(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('평가가 저장되었습니다.')),
      );
    }
  }
}

/// ── Editor bottom sheet ─────────────────────────────────────────────────────

class _FeedbackEditorSheet extends ConsumerStatefulWidget {
  const _FeedbackEditorSheet({required this.row});

  final SubmissionRow row;

  @override
  ConsumerState<_FeedbackEditorSheet> createState() =>
      _FeedbackEditorSheetState();
}

class _FeedbackEditorSheetState
    extends ConsumerState<_FeedbackEditorSheet> {
  late final TextEditingController _scoreCtrl;
  late final TextEditingController _feedbackCtrl;

  @override
  void initState() {
    super.initState();
    _scoreCtrl =
        TextEditingController(text: widget.row.score?.toString() ?? '');
    _feedbackCtrl = TextEditingController();
    // Seed the score field into the form notifier once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(feedbackFormProvider(widget.row.id).notifier)
          .seed(score: widget.row.score);
    });
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.row.id;
    final form = ref.watch(feedbackFormProvider(id));
    final notifier = ref.read(feedbackFormProvider(id).notifier);

    // Close + return result once saved.
    ref.listen(feedbackFormProvider(id).select((s) => s.saved), (_, saved) {
      if (saved != null) Navigator.of(context).pop(saved);
    });

    final detailAsync = ref.watch(submissionDetailProvider(id));

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.row.studentName ?? '수강생'} 제출물 평가',
                    style: AppTypography.headlineSm,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Submission content (read-only) — loaded lazily.
            detailAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: LoadingView(message: '제출 내용을 불러오는 중입니다…'),
              ),
              error: (e, _) => ErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(submissionDetailProvider(id)),
              ),
              data: (submission) => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  (submission.content == null ||
                          submission.content!.trim().isEmpty)
                      ? '(첨부 파일 제출 — 본문 없음)'
                      : submission.content!,
                  style: AppTypography.bodySm,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('점수', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _scoreCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '점수 입력 (선택)',
                suffixText: '점',
              ),
              onChanged: notifier.setScore,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('피드백', style: AppTypography.labelMd),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _feedbackCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '피드백을 입력하세요 (필수)',
              ),
              onChanged: notifier.setFeedback,
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('재제출 요청', style: AppTypography.bodyMd),
              subtitle: Text(
                '켜면 수강생에게 재제출을 요청합니다.',
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              value: form.requestResubmit,
              activeThumbColor: AppColors.primary,
              onChanged: notifier.setRequestResubmit,
            ),
            if (form.error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                form.error!,
                style: AppTypography.bodySm.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: form.requestResubmit ? '재제출 요청 보내기' : '평가 저장',
              icon: Icons.check_rounded,
              expand: true,
              loading: form.isSubmitting,
              onPressed: form.isValid ? notifier.submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// ── Assignment-create dialog ────────────────────────────────────────────────

class _AssignmentCreateDialog extends ConsumerStatefulWidget {
  const _AssignmentCreateDialog({required this.cohortId});

  final int cohortId;

  @override
  ConsumerState<_AssignmentCreateDialog> createState() =>
      _AssignmentCreateDialogState();
}

class _AssignmentCreateDialogState
    extends ConsumerState<_AssignmentCreateDialog> {
  Future<void> _pickDueDate(AssignmentCreateNotifier notifier) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    if (!mounted) return;
    notifier.setDueDate(DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 23,
      time?.minute ?? 59,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.cohortId;
    final form = ref.watch(assignmentCreateProvider(id));
    final notifier = ref.read(assignmentCreateProvider(id).notifier);

    ref.listen(
        assignmentCreateProvider(id).select((s) => s.created), (_, created) {
      if (created != null) Navigator.of(context).pop(created);
    });

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('새 과제 등록', style: AppTypography.headlineSm),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                decoration: const InputDecoration(labelText: '제목'),
                onChanged: notifier.setTitle,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                maxLines: 4,
                decoration: const InputDecoration(labelText: '설명'),
                onChanged: notifier.setDescription,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      form.dueDate == null
                          ? '마감일을 선택하세요'
                          : '마감 ${DateFormatter.dateTime(form.dueDate!)}',
                      style: AppTypography.bodySm.copyWith(
                        color: form.dueDate == null
                            ? AppColors.onSurfaceVariant
                            : AppColors.onSurface,
                      ),
                    ),
                  ),
                  AppButton(
                    label: '마감일 선택',
                    icon: Icons.event_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _pickDueDate(notifier),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '배점 (선택)',
                  suffixText: '점',
                ),
                onChanged: notifier.setMaxScore,
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('지각 제출 허용', style: AppTypography.bodyMd),
                value: form.allowLateSubmission,
                activeThumbColor: AppColors.primary,
                onChanged: notifier.setAllowLate,
              ),
              if (form.error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  form.error!,
                  style: AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: '취소',
                    variant: AppButtonVariant.tertiary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: '등록',
                    loading: form.isSubmitting,
                    onPressed: form.isValid ? notifier.submit : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
