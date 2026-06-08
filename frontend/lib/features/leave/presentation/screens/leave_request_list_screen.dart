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
import '../../domain/leave_model.dart';
import '../leave_provider.dart';
import 'leave_status_ui.dart';

/// Student's own early-leave / sick-leave (조퇴·병결) request list.
///
/// Mobile-first card list (students are mobile-first). Each card shows the
/// type, target date and a status chip; tapping opens the detail screen. A
/// primary CTA opens the new-request form.
class LeaveRequestListScreen extends ConsumerWidget {
  const LeaveRequestListScreen({super.key});

  static const String routePath = '/student/leave-requests';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leaveListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHeader(
            title: '조퇴·병결 신청',
            action: AppButton(
              label: '신청하기',
              icon: Icons.add_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () => context.go('$routePath/new'),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(leaveListProvider.notifier).refresh(),
              child: state.when(
          loading: () => const LoadingView(message: '조퇴·병결 신청 내역을 불러오는 중입니다.'),
          error: (e, _) => ListView(
            // Keep RefreshIndicator usable while in an error state.
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.7,
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.read(leaveListProvider.notifier).refresh(),
                ),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.7,
                      child: Center(
                        child: EmptyState(
                          icon: Icons.event_busy_outlined,
                          title: '신청 내역이 없습니다',
                          description: '조퇴 또는 병결이 필요할 때 신청을 등록하세요.',
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _LeaveListItem(request: items[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveListItem extends StatelessWidget {
  const _LeaveListItem({required this.request});

  final LeaveRequest request;

  @override
  Widget build(BuildContext context) {
    final ui = leaveStatusUi(request.status);
    return AppCard(
      onTap: () => context.go(
        '${LeaveRequestListScreen.routePath}/${request.id}',
      ),
      child: Row(
        children: [
          _TypeBadge(type: request.type),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.type.label, style: AppTypography.headlineSm),
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
        ],
      ),
    );
  }
}

/// Square leading badge keyed on the leave type.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final LeaveType type;

  IconData get _icon => switch (type) {
        LeaveType.earlyLeave => Icons.logout_rounded,
        LeaveType.medical => Icons.healing_outlined,
        LeaveType.official => Icons.verified_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(_icon, size: 22, color: AppColors.onSecondaryContainer),
    );
  }
}
