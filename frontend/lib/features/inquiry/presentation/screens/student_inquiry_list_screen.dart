import '../../../../core/app_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../domain/inquiry_model.dart';
import '../inquiry_provider.dart';
import 'inquiry_list_screen.dart' show statusTone, priorityTone;

/// Base path for the student-facing inquiry area. Threaded into row taps so
/// navigation stays under `/student`.
const String studentInquiryBase = '/student/inquiries';

/// Student "내 문의" list — the answers/replies view that complements the
/// create-only support flow. The student sees ONLY their own inquiries because
/// `GET /inquiries/` auto-scopes by role server-side (students are filtered to
/// `author_id == self`).
///
/// Mobile-first card layout (students are mobile-first per the UX guide). Row
/// taps open [InquiryDetailScreen], which already renders the message thread in
/// read + reply mode for the author and hides the handler controls.
class StudentInquiryListScreen extends ConsumerWidget {
  const StudentInquiryListScreen({super.key});

  /// No filters → everything the student is allowed to see (their own).
  static const _args = InquiryListArgs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inquiries = ref.watch(inquiryListProvider(_args));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListHeader(
              title: AppLabels.myInquiries,
              action: AppButton(
                label: '문의하기',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () => context.push('$studentInquiryBase/new'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: _InquiryChannelBanner(),
            ),
            Expanded(
              child: inquiries.when(
                loading: () => const LoadingView(message: '문의 내역을 불러오는 중입니다'),
                error: (e, _) => ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.read(inquiryListProvider(_args).notifier).refresh(),
                ),
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        icon: Icons.support_agent_outlined,
                        title: '등록한 문의가 없습니다',
                        description: '궁금한 점이나 문제가 있으면 문의를 남겨보세요.\n'
                            '답변이 등록되면 이곳에서 확인할 수 있습니다.',
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => ref
                            .read(inquiryListProvider(_args).notifier)
                            .refresh(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, i) =>
                              _StudentInquiryCard(inquiry: items[i]),
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

/// Clarifies that 내 문의 is the operations/support channel (운영·지원팀), handled
/// as tickets — distinct from 상담(counseling), which is a private channel to the
/// assigned instructor.
class _InquiryChannelBanner extends StatelessWidget {
  const _InquiryChannelBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '운영·지원팀에 전달되는 문의입니다.',
                  style: AppTypography.labelMd
                      .copyWith(color: AppColors.onSurface),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '행정·기술 문제를 티켓으로 접수합니다. '
                  '개인적인 학습·진로 고민은 «상담»을 이용해 주세요.',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentInquiryCard extends StatelessWidget {
  const _StudentInquiryCard({required this.inquiry});

  final Inquiry inquiry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('$studentInquiryBase/${inquiry.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inquiry.title,
                  style: AppTypography.headlineSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: inquiry.statusEnum.label,
                tone: statusTone(inquiry.statusEnum),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            inquiry.content,
            style:
                AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              StatusChip(label: inquiry.typeEnum.label),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: inquiry.priorityEnum.label,
                tone: priorityTone(inquiry.priorityEnum),
              ),
              const Spacer(),
              Text(
                DateFormatter.relative(inquiry.createdAt),
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
