import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../data/leave_repository.dart';
import '../../domain/leave_model.dart';
import '../leave_provider.dart';
import 'leave_status_ui.dart';

/// Detail view for one early-leave / sick-leave (조퇴·병결) request.
///
/// Shows the full request and, while it is still pending, lets the student
/// cancel it (destructive → confirmation dialog). Approve / reject are
/// operations-team actions and are intentionally absent from the student view.
class LeaveRequestDetailScreen extends ConsumerWidget {
  const LeaveRequestDetailScreen({super.key, required this.requestId});

  /// `/student/leave-requests/:id`.
  static const String routePath = '/student/leave-requests/:id';

  final int requestId;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/student/leave-requests');
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '신청을 취소하시겠습니까?',
      message: '취소한 신청은 되돌릴 수 없습니다.',
      confirmLabel: '신청 취소',
      cancelLabel: '닫기',
      destructive: true,
    );
    if (!ok) return;

    try {
      await ref.read(leaveListProvider.notifier).cancel(requestId);
      // Re-fetch this detail so the screen reflects the canceled status.
      ref.invalidate(leaveDetailProvider(requestId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('신청이 취소되었습니다.')));
    } on LeaveException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(leaveDetailProvider(requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('신청 상세'),
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
          onCancel: () => _cancel(context, ref),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.request, required this.onCancel});

  final LeaveRequest request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ui = leaveStatusUi(request.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
                      Text(
                        request.reviewComment!,
                        style: AppTypography.bodyMd,
                      ),
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

              if (request.isPending) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: '신청 취소',
                  icon: Icons.cancel_outlined,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  onPressed: onCancel,
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
        Expanded(
          child: Text(value, style: AppTypography.bodyMd),
        ),
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
