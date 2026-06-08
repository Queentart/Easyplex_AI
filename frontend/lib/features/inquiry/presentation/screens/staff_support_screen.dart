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

/// "지원 · 문의" — the staff-facing self-service support screen mounted for
/// INSTRUCTOR / OPERATIONS / TECH_SUPPORT. It is the staff analogue of the
/// student "내 문의" view: a "문의하기" entry plus the list of inquiries the
/// caller has submitted, each opening the read + reply message thread.
///
/// The caller sees ONLY their own inquiries because `GET /inquiries/`
/// auto-scopes by the authenticated user server-side. This screen is distinct
/// from the ops/tech ticket-management screens (`/ops/issues`, `/tech/issues`)
/// which manage ALL tickets.
///
/// [basePath] differs per area (`/instructor/support`, `/ops/support`,
/// `/tech/support`) so intra-feature navigation (`context.push`) and back
/// navigation stay within the area the user entered from. Create + detail
/// reuse the shared [InquiryFormScreen] / [InquiryDetailScreen] with the same
/// [basePath].
class StaffSupportListScreen extends ConsumerWidget {
  const StaffSupportListScreen({super.key, required this.basePath});

  /// Area root (e.g. `/ops/support`). `/new` and `/:id` hang off it.
  final String basePath;

  /// No filters → everything the caller is allowed to see (their own).
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
              title: AppLabels.support,
              subtitle: '문의를 등록하고 답변을 확인할 수 있습니다.',
              action: AppButton(
                label: '문의하기',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () => context.push('$basePath/new'),
              ),
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
                          itemBuilder: (context, i) => _StaffInquiryCard(
                            inquiry: items[i],
                            basePath: basePath,
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

class _StaffInquiryCard extends StatelessWidget {
  const _StaffInquiryCard({required this.inquiry, required this.basePath});

  final Inquiry inquiry;
  final String basePath;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('$basePath/${inquiry.id}'),
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
