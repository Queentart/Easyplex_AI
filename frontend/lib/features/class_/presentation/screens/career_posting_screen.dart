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
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/class_model.dart';
import '../class_provider.dart';

/// Career postings: job openings, certifications, and special lectures shared
/// with the institution. Read-only for instructors / students; admin_ops also
/// gets a compose action (a FAB → `/instructor/career/new`), matching the
/// `POST /career-postings` RBAC.
class CareerPostingScreen extends ConsumerWidget {
  const CareerPostingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(careerPostingListProvider);
    final user = ref.watch(currentUserProvider);
    final canCreate = user?.role == 'admin_ops';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('취업·자격 공지'),
        backgroundColor: AppColors.surface,
        actions: [
          if (canCreate) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: AppButton(
                label: '공지 등록',
                icon: Icons.campaign_outlined,
                variant: AppButtonVariant.primary,
                onPressed: () => context.push('/instructor/career/new'),
              ),
            ),
          ],
        ],
      ),
      body: state.when(
        loading: () => const LoadingView(message: '공지를 불러오는 중입니다'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(careerPostingListProvider),
        ),
        data: (postings) => postings.isEmpty
            ? const EmptyState(
                icon: Icons.work_outline_rounded,
                title: '등록된 공지가 없습니다',
                description: '채용·자격증·특강 공지가 등록되면 이곳에 표시됩니다.',
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () =>
                    ref.read(careerPostingListProvider.notifier).refresh(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: postings.length,
                  separatorBuilder: (context, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) =>
                      _PostingCard(posting: postings[i]),
                ),
              ),
      ),
    );
  }
}

/// Maps a posting type to a Korean label + chip tone.
({String label, StatusTone tone}) _postingTypeChip(String type) {
  return switch (type) {
    'job' => (label: '채용', tone: StatusTone.success),
    'certification' => (label: '자격증', tone: StatusTone.info),
    'special_lecture' => (label: '특강', tone: StatusTone.warning),
    _ => (label: '공지', tone: StatusTone.neutral),
  };
}

class _PostingCard extends StatelessWidget {
  const _PostingCard({required this.posting});

  final CareerPosting posting;

  @override
  Widget build(BuildContext context) {
    final chip = _postingTypeChip(posting.postingType);
    final period = _periodLabel(posting);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label: chip.label, tone: chip.tone),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  posting.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSm,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            posting.content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          if (period != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 14, color: AppColors.outline),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  period,
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ],
          if (posting.externalUrl != null &&
              posting.externalUrl!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.link_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    posting.externalUrl!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.bodySm.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _periodLabel(CareerPosting p) {
    if (p.startDate == null && p.endDate == null) return null;
    final start = p.startDate == null ? '' : DateFormatter.date(p.startDate!);
    final end = p.endDate == null ? '' : DateFormatter.date(p.endDate!);
    if (start.isNotEmpty && end.isNotEmpty) return '$start ~ $end';
    return start.isNotEmpty ? '$start ~' : '~ $end';
  }
}
