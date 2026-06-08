import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/leave_model.dart';
import '../leave_provider.dart';
import 'leave_status_ui.dart';

/// Reviewer-facing early-leave / sick-leave (조퇴·병결) approval list.
///
/// Shared by both reviewer areas:
///   - operations-team : `/ops/leave-requests`
///   - instructor      : `/instructor/leave-approvals`
///
/// The owning area is supplied via [basePath] so each row / empty CTA can route
/// back into the correct detail path. Tablet/PC-first (reviewers work on wide
/// screens): a centred, max-width column of cards with status filter chips.
///
/// Role-gated to operations-team / instructor; anyone else sees a "권한 없음"
/// notice. (Approve / reject itself is operations-team only — enforced on the
/// detail screen and by the backend — but instructors may review the list.)
class LeaveApprovalListScreen extends ConsumerWidget {
  const LeaveApprovalListScreen({super.key, required this.basePath});

  /// Absolute base path of the owning reviewer area, e.g. `/ops/leave-requests`
  /// or `/instructor/leave-approvals`. Detail is `"$basePath/:id"`.
  final String basePath;

  bool _canReview(String? role) =>
      role == AppRoles.adminOps || role == AppRoles.instructor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider)?.role;
    if (!_canReview(role)) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: EmptyState(
            icon: Icons.lock_outline,
            title: '접근 권한이 없습니다',
            description: '조퇴·병결 승인은 운영팀 또는 강사만 확인할 수 있습니다.',
          ),
        ),
      );
    }

    final filter = ref.watch(leaveReviewFilterProvider);
    final state = ref.watch(leaveReviewListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(leaveReviewListProvider.notifier).refresh(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Text('조퇴·병결 승인', style: AppTypography.headlineMd),
                ),
                _FilterBar(
                  selected: filter,
                  onSelected: (f) => ref
                      .read(leaveReviewFilterProvider.notifier)
                      .select(f),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: state.when(
                    loading: () =>
                        const LoadingView(message: '신청 내역을 불러오는 중입니다.'),
                    error: (e, _) => ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.6,
                          child: ErrorView(
                            message: e.toString(),
                            onRetry: () => ref
                                .read(leaveReviewListProvider.notifier)
                                .refresh(),
                          ),
                        ),
                      ],
                    ),
                    data: (items) => items.isEmpty
                        ? _EmptyForFilter(filter: filter)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              0,
                              AppSpacing.md,
                              AppSpacing.xl,
                            ),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, i) => _ApprovalListItem(
                              request: items[i],
                              onTap: () => context.go(
                                '$basePath/${items[i].id}',
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status filter chips: 전체 / 대기 / 승인 / 반려.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final LeaveReviewFilter selected;
  final ValueChanged<LeaveReviewFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (final f in LeaveReviewFilter.values) ...[
            ChoiceChip(
              label: Text(f.label),
              selected: f == selected,
              onSelected: (_) => onSelected(f),
              showCheckmark: false,
              selectedColor: AppColors.primaryContainer,
              labelStyle: AppTypography.labelMd.copyWith(
                color: f == selected
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurfaceVariant,
                fontWeight: f == selected ? FontWeight.w600 : FontWeight.w500,
              ),
              backgroundColor: AppColors.surfaceContainerLowest,
              side: BorderSide(
                color: f == selected ? AppColors.primary : AppColors.outline,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Empty state whose wording depends on the active filter.
class _EmptyForFilter extends StatelessWidget {
  const _EmptyForFilter({required this.filter});

  final LeaveReviewFilter filter;

  @override
  Widget build(BuildContext context) {
    final (title, description) = switch (filter) {
      LeaveReviewFilter.pending => (
          '대기 중인 신청이 없습니다',
          '새로운 조퇴·병결 신청이 접수되면 이곳에 표시됩니다.'
        ),
      LeaveReviewFilter.approved => ('승인된 신청이 없습니다', null),
      LeaveReviewFilter.rejected => ('반려된 신청이 없습니다', null),
      LeaveReviewFilter.all => ('신청 내역이 없습니다', null),
    };
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Center(
            child: EmptyState(
              icon: Icons.fact_check_outlined,
              title: title,
              description: description,
            ),
          ),
        ),
      ],
    );
  }
}

/// One request row. Pending rows are highlighted with a left accent + tinted
/// surface so reviewers spot what needs action.
class _ApprovalListItem extends StatelessWidget {
  const _ApprovalListItem({required this.request, required this.onTap});

  final LeaveRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = leaveStatusUi(request.status);
    final isPending = request.status == LeaveStatus.pending;

    final card = AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(request.type.label, style: AppTypography.headlineSm),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '수강생 #${request.studentId}',
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  DateFormatter.date(request.targetDate),
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  request.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusChip(label: ui.label, tone: ui.tone),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
        ],
      ),
    );

    if (!isPending) return card;

    // Pending highlight: a thin leading accent bar.
    return Stack(
      children: [
        card,
        Positioned(
          left: 0,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ],
    );
  }
}
