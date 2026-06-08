import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants.dart';
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
import '../../data/leave_repository.dart';
import '../../domain/leave_model.dart';
import '../leave_provider.dart';
import 'leave_status_ui.dart';

/// Reviewer detail view for one early-leave / sick-leave (조퇴·병결) request.
///
/// Shows the full request (and supporting document, when attached) and — for a
/// pending request — lets the **operations team** approve or reject it. The
/// backend requires a `review_comment` for both actions, so approve and reject
/// both go through a comment dialog (reject additionally confirms intent).
///
/// Instructors may open this screen to review, but the approve/reject controls
/// are hidden for them (the backend restricts the action to `admin_ops`).
class LeaveApprovalDetailScreen extends ConsumerWidget {
  const LeaveApprovalDetailScreen({
    super.key,
    required this.requestId,
    required this.basePath,
  });

  /// `/leave-requests/{id}` (id of the request being reviewed).
  final int requestId;

  /// Absolute base path of the owning reviewer list, used for the back button
  /// fallback, e.g. `/ops/leave-requests` or `/instructor/leave-approvals`.
  final String basePath;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(basePath);
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final comment = await _promptComment(
      context,
      title: '신청을 승인하시겠습니까?',
      hint: '승인 의견을 입력하세요 (필수)',
      confirmLabel: '승인',
      destructive: false,
    );
    if (comment == null || !context.mounted) return; // dismissed

    await _runReview(
      context,
      ref,
      action: () => ref
          .read(leaveReviewListProvider.notifier)
          .approve(requestId, comment),
      successMessage: '신청을 승인했습니다.',
    );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final comment = await _promptComment(
      context,
      title: '신청을 반려하시겠습니까?',
      hint: '반려 사유를 입력하세요 (필수)',
      confirmLabel: '반려',
      destructive: true,
    );
    if (comment == null || !context.mounted) return; // dismissed

    await _runReview(
      context,
      ref,
      action: () =>
          ref.read(leaveReviewListProvider.notifier).reject(requestId, comment),
      successMessage: '신청을 반려했습니다.',
    );
  }

  /// Runs a review [action], refreshing the detail and showing feedback.
  Future<void> _runReview(
    BuildContext context,
    WidgetRef ref, {
    required Future<LeaveRequest> Function() action,
    required String successMessage,
  }) async {
    try {
      await action();
      ref.invalidate(leaveDetailProvider(requestId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
    } on LeaveException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Shows a dialog with a required comment field. Returns the trimmed comment,
  /// or null if the reviewer dismissed it.
  Future<String?> _promptComment(
    BuildContext context, {
    required String title,
    required String hint,
    required String confirmLabel,
    required bool destructive,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _CommentDialog(
        title: title,
        hint: hint,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider)?.role;
    // Only the operations team can actually approve / reject (backend rule).
    final canDecide = role == AppRoles.adminOps;

    final detail = ref.watch(leaveDetailProvider(requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('승인 상세'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _goBack(context),
        ),
      ),
      body: detail.when(
        loading: () => const LoadingView(message: '신청 내용을 불러오는 중입니다.'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(leaveDetailProvider(requestId)),
        ),
        data: (request) => _DetailBody(
          request: request,
          canDecide: canDecide,
          onApprove: () => _approve(context, ref),
          onReject: () => _reject(context, ref),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.request,
    required this.canDecide,
    required this.onApprove,
    required this.onReject,
  });

  final LeaveRequest request;
  final bool canDecide;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ui = leaveStatusUi(request.status);
    final isPending = request.status == LeaveStatus.pending;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.type.label,
                            style: AppTypography.headlineMd,
                          ),
                        ),
                        StatusChip(label: ui.label, tone: ui.tone),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      label: '수강생',
                      value: '#${request.studentId}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      label: '신청 일자',
                      value: DateFormatter.date(request.targetDate),
                    ),
                    if (request.type == LeaveType.earlyLeave &&
                        request.startTime != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _InfoRow(
                        label: '조퇴 시각',
                        value: _trimSeconds(request.startTime!),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      label: '신청일',
                      value: DateFormatter.dateTime(request.createdAt),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _InfoBlock(label: '사유', value: request.reason),
                  ],
                ),
              ),

              // Review result (shown once processed).
              if (request.reviewComment != null &&
                  request.reviewComment!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        request.status == LeaveStatus.rejected
                            ? '반려 사유'
                            : '검토 의견',
                        style: AppTypography.labelMd,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(request.reviewComment!, style: AppTypography.bodyMd),
                      if (request.reviewedAt != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '검토 ${DateFormatter.dateTime(request.reviewedAt!)}',
                          style: AppTypography.labelSm,
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Approve / reject (operations team, pending only).
              if (canDecide && isPending) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '반려',
                        icon: Icons.close_rounded,
                        variant: AppButtonVariant.secondary,
                        expand: true,
                        onPressed: onReject,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: '승인',
                        icon: Icons.check_rounded,
                        expand: true,
                        onPressed: onApprove,
                      ),
                    ),
                  ],
                ),
              ] else if (canDecide && !isPending) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  '이미 처리된 신청입니다.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// `"HH:mm:ss"` → `"HH:mm"` for display.
  String _trimSeconds(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }
}

/// Dialog with a required comment field. Pops the trimmed comment on confirm,
/// or null on cancel. The confirm button stays disabled until the field is
/// non-empty (the backend requires `review_comment`).
class _CommentDialog extends StatefulWidget {
  const _CommentDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.destructive,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final bool destructive;

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _controller.text.trim().isNotEmpty;

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppTypography.headlineSm),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 300,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.hint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: '취소',
                  variant: AppButtonVariant.tertiary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (widget.destructive)
                  FilledButton(
                    onPressed: canConfirm
                        ? () => Navigator.of(context)
                            .pop(_controller.text.trim())
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.onError,
                      textStyle: AppTypography.labelMd,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm + 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(widget.confirmLabel),
                  )
                else
                  AppButton(
                    label: widget.confirmLabel,
                    onPressed: canConfirm
                        ? () =>
                            Navigator.of(context).pop(_controller.text.trim())
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        Expanded(child: Text(value, style: AppTypography.bodyMd)),
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTypography.bodyMd),
      ],
    );
  }
}
