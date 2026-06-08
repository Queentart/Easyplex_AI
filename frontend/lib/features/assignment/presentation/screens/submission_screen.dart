import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/utils/file_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/assignment_model.dart';
import '../assignment_provider.dart';

/// Standalone submission screen for an assignment id. Thin wrapper that loads
/// the assignment then renders [SubmissionPanel]. The combined detail route
/// embeds [SubmissionPanel] directly, so this is offered for direct deep-links.
class SubmissionScreen extends ConsumerWidget {
  const SubmissionScreen({super.key, required this.assignmentId});

  final int assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(assignmentDetailProvider(assignmentId));
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: detail.when(
        loading: () => const LoadingView(message: '과제 정보를 불러오는 중입니다…'),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (assignment) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SubmissionPanel(assignment: assignment),
        ),
      ),
    );
  }
}

/// The student's OWN submission area: text body + multiple file attachments,
/// initial submission, and resubmission. Shows the confirmed receipt once a
/// submission succeeds in this session.
///
/// This panel only ever reflects the signed-in student's own work; it never
/// fetches or displays another student's submission.
class SubmissionPanel extends ConsumerWidget {
  const SubmissionPanel({super.key, required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(submissionFormProvider(assignment.id));
    final notifier = ref.read(submissionFormProvider(assignment.id).notifier);
    final canSubmit = assignment.canSubmit();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('내 제출물', style: AppTypography.headlineSm),
              const Spacer(),
              if (form.submitted != null)
                _SubmissionStatusChip(submission: form.submitted!),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (form.submitted != null) ...[
            _SubmittedReceipt(submission: form.submitted!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!canSubmit) ...[
            _ClosedNotice(assignment: assignment),
          ] else ...[
            _SubmissionEditor(
              assignment: assignment,
              form: form,
              notifier: notifier,
            ),
          ],
        ],
      ),
    );
  }
}

class _SubmissionEditor extends ConsumerStatefulWidget {
  const _SubmissionEditor({
    required this.assignment,
    required this.form,
    required this.notifier,
  });

  final Assignment assignment;
  final SubmissionFormState form;
  final SubmissionFormNotifier notifier;

  @override
  ConsumerState<_SubmissionEditor> createState() => _SubmissionEditorState();
}

class _SubmissionEditorState extends ConsumerState<_SubmissionEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.form.content);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  SubmissionFormState get form => widget.form;
  SubmissionFormNotifier get notifier => widget.notifier;

  @override
  Widget build(BuildContext context) {
    final isResubmit = form.submitted != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          minLines: 4,
          maxLines: 8,
          enabled: !form.isSubmitting,
          controller: _controller,
          onChanged: notifier.setContent,
          decoration: const InputDecoration(
            hintText: '제출 내용을 입력하세요. (텍스트 또는 첨부파일 중 하나 이상 필요)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _AttachmentList(form: form, notifier: notifier),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: '파일 첨부',
          icon: Icons.attach_file_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: form.isSubmitting ? null : _pickFiles,
        ),
        if (form.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            form.errorMessage!,
            style: AppTypography.bodySm.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: isResubmit ? '재제출' : '제출하기',
          icon: Icons.send_rounded,
          expand: true,
          loading: form.isSubmitting,
          onPressed: form.canSubmit && !form.isSubmitting ? _submit : null,
        ),
      ],
    );
  }

  Future<void> _pickFiles() async {
    final picker = ref.read(assignmentFilePickerProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await picker();
      for (final file in picked) {
        if (!FileUtils.isWithinSizeLimit(file.size)) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '${file.fileName}: 최대 '
                '${FileUtils.humanSize(FileUtils.maxUploadBytes)}까지 첨부할 수 있습니다.',
              ),
            ),
          );
          continue;
        }
        notifier.addFile(file);
      }
    } on FilePickerUnavailable catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } catch (_) {
      messenger
          .showSnackBar(const SnackBar(content: Text('파일을 불러오지 못했습니다.')));
    }
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await notifier.submit();
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('제출이 완료되었습니다.')),
      );
    }
    // Failure messages are surfaced inline via form.errorMessage.
  }
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList({required this.form, required this.notifier});

  final SubmissionFormState form;
  final SubmissionFormNotifier notifier;

  @override
  Widget build(BuildContext context) {
    if (form.files.isEmpty) {
      return Text(
        '첨부된 파일이 없습니다.',
        style:
            AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < form.files.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      size: 18, color: AppColors.outline),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      form.files[i].fileName,
                      style: AppTypography.bodySm,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    FileUtils.humanSize(form.files[i].size),
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.outline,
                    onPressed:
                        form.isSubmitting ? null : () => notifier.removeFileAt(i),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SubmittedReceipt extends StatelessWidget {
  const _SubmittedReceipt({required this.submission});

  final Submission submission;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '제출 완료 · ${DateFormatter.dateTime(submission.submittedAt)}',
                style: AppTypography.labelMd,
              ),
            ],
          ),
          if (submission.isLate) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '지각 제출로 기록되었습니다.',
              style:
                  AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
          if (submission.score != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '점수 ${submission.score}점',
              style: AppTypography.labelMd.copyWith(color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubmissionStatusChip extends StatelessWidget {
  const _SubmissionStatusChip({required this.submission});

  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (submission.status) {
      SubmissionStatus.submitted => ('제출됨', StatusTone.info),
      SubmissionStatus.reviewed => ('검토 완료', StatusTone.success),
      SubmissionStatus.resubmitRequested => ('재제출 요청', StatusTone.warning),
      SubmissionStatus.unknown => ('제출됨', StatusTone.neutral),
    };
    return StatusChip(label: label, tone: tone);
  }
}

class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final overdue = assignment.isOverdue();
    final message = overdue
        ? '제출 마감일이 지나 제출할 수 없습니다.'
        : '현재 제출할 수 없는 과제입니다.';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
