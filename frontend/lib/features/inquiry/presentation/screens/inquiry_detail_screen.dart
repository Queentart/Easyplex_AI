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
import '../../../../shared/widgets/chat_bubble.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../domain/inquiry_model.dart';
import '../inquiry_provider.dart';
import 'inquiry_list_screen.dart' show statusTone, priorityTone;

/// Inquiry/ticket detail (`{basePath}/:id`): the request body, handler actions
/// (status change, assign-to-me, close), and the REST message thread rendered
/// with [ChatBubble]. Handler controls are shown only to support/operations
/// roles; the author always sees the thread + composer.
class InquiryDetailScreen extends ConsumerWidget {
  const InquiryDetailScreen({
    super.key,
    required this.inquiryId,
    required this.basePath,
  });

  final int inquiryId;
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(inquiryDetailProvider(inquiryId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: TopBar(
        title: '문의 상세',
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.onSurface,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(basePath),
          ),
        ],
      ),
      body: SafeArea(
        child: detail.when(
          loading: () => const LoadingView(message: '문의를 불러오는 중입니다'),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () =>
                ref.read(inquiryDetailProvider(inquiryId).notifier).refresh(),
          ),
          data: (inquiry) => _DetailBody(inquiry: inquiry, basePath: basePath),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.inquiry, required this.basePath});

  final Inquiry inquiry;
  final String basePath;

  bool _isHandler(String? role) =>
      role == AppRoles.adminOps || role == AppRoles.techSupport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isHandler = _isHandler(user?.role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _InquiryHeaderCard(inquiry: inquiry),
              if (isHandler) ...[
                const SizedBox(height: AppSpacing.md),
                _HandlerActionsCard(
                  inquiry: inquiry,
                  currentUserId: user?.id,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('대화 내역', style: AppTypography.headlineSm),
              const SizedBox(height: AppSpacing.sm),
              _MessageThread(
                inquiryId: inquiry.id,
                viewerId: user?.id,
              ),
            ],
          ),
        ),
        if (!inquiry.isClosed)
          _MessageComposer(inquiryId: inquiry.id)
        else
          const _ClosedNotice(),
      ],
    );
  }
}

class _InquiryHeaderCard extends StatelessWidget {
  const _InquiryHeaderCard({required this.inquiry});

  final Inquiry inquiry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(inquiry.title, style: AppTypography.headlineSm),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip(label: inquiry.typeEnum.label),
              StatusChip(
                label: inquiry.priorityEnum.label,
                tone: priorityTone(inquiry.priorityEnum),
              ),
              StatusChip(
                label: inquiry.statusEnum.label,
                tone: statusTone(inquiry.statusEnum),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(inquiry.content, style: AppTypography.bodyMd),
          const SizedBox(height: AppSpacing.md),
          Text(
            '등록일 ${DateFormatter.dateTime(inquiry.createdAt)}',
            style:
                AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Handler-only controls: status transition, assign-to-me, and close.
class _HandlerActionsCard extends ConsumerStatefulWidget {
  const _HandlerActionsCard({required this.inquiry, required this.currentUserId});

  final Inquiry inquiry;
  final int? currentUserId;

  @override
  ConsumerState<_HandlerActionsCard> createState() =>
      _HandlerActionsCardState();
}

class _HandlerActionsCardState extends ConsumerState<_HandlerActionsCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inquiry = widget.inquiry;
    final notifier = ref.read(inquiryDetailProvider(inquiry.id).notifier);
    final assignedToMe = inquiry.assignedTo != null &&
        inquiry.assignedTo == widget.currentUserId;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  size: 20, color: AppColors.outline),
              const SizedBox(width: AppSpacing.sm),
              Text('처리', style: AppTypography.headlineSm),
              const Spacer(),
              if (_busy)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '상태 변경',
            style: AppTypography.labelMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in InquiryStatus.values)
                if (s != InquiryStatus.closed)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: inquiry.statusEnum == s,
                    onSelected: _busy
                        ? null
                        : (_) =>
                            _run(() => notifier.applyUpdate(status: s.code)),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: assignedToMe ? '담당자 (나)' : '나에게 배정',
                  icon: Icons.person_add_alt_1_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: (_busy || assignedToMe || widget.currentUserId == null)
                      ? null
                      : () => _run(
                            () => notifier.applyUpdate(
                                assignedTo: widget.currentUserId),
                          ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: inquiry.isClosed ? '종료됨' : '문의 종료',
                  icon: Icons.lock_outline_rounded,
                  variant: AppButtonVariant.tertiary,
                  onPressed: (_busy || inquiry.isClosed)
                      ? null
                      : () => _confirmClose(notifier),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClose(InquiryDetailNotifier notifier) async {
    final ok = await showConfirmDialog(
      context,
      title: '문의를 종료하시겠습니까?',
      message: '종료된 문의에는 더 이상 메시지를 보낼 수 없습니다.',
      confirmLabel: '종료',
      destructive: true,
    );
    if (!ok) return;
    await _run(notifier.close);
  }
}

/// REST message thread rendered with [ChatBubble]. Manual-refresh model until
/// the WebSocket transport lands in F5.
class _MessageThread extends ConsumerWidget {
  const _MessageThread({required this.inquiryId, required this.viewerId});

  final int inquiryId;
  final int? viewerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(inquiryMessagesProvider(inquiryId));

    return messages.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: LoadingView(message: '대화를 불러오는 중입니다'),
      ),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () =>
            ref.read(inquiryMessagesProvider(inquiryId).notifier).refresh(),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.forum_outlined,
            title: '아직 대화가 없습니다',
            description: '아래 입력창으로 첫 메시지를 보내보세요.',
          );
        }
        return Column(
          children: [
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: m.isSentBy(viewerId)
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    ChatBubble.text(m.content, isUser: m.isSentBy(viewerId)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      DateFormatter.relative(m.createdAt),
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.outline),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MessageComposer extends ConsumerStatefulWidget {
  const _MessageComposer({required this.inquiryId});

  final int inquiryId;

  @override
  ConsumerState<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<_MessageComposer> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(inquiryMessagesProvider(widget.inquiryId).notifier)
          .send(text);
      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(hintText: '메시지를 입력하세요'),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SafeArea(
        top: false,
        child: Text(
          '종료된 문의입니다. 더 이상 메시지를 보낼 수 없습니다.',
          textAlign: TextAlign.center,
          style:
              AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }
}
