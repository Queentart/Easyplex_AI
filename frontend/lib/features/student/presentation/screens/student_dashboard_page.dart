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
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../assignment/domain/assignment_model.dart';
import '../../../assignment/presentation/assignment_provider.dart';
import '../../../attendance/domain/attendance_model.dart';
import '../../../attendance/presentation/attendance_provider.dart';
import '../../../board/domain/board_model.dart';
import '../../../board/presentation/board_provider.dart';
import '../../../leave/domain/leave_model.dart';
import '../../../leave/presentation/leave_provider.dart';
import '../../../notification/domain/notification_model.dart';
import '../../../notification/presentation/notification_provider.dart';

/// 수강생 홈 대시보드.
///
/// Aggregates the student's most actionable information into one screen by
/// reusing the existing feature providers (attendance / assignment / board /
/// leave / notification). Each card watches its OWN provider's [AsyncValue], so
/// a single failing endpoint degrades only that card — the rest of the
/// dashboard keeps working (per-card loading / error / empty).
///
/// Rendered inside the authenticated app shell, so this returns scrollable page
/// content only (no Scaffold / AppBar of its own).
///
/// NOTE: class name + const constructor are kept stable so the router import
/// (`student_dashboard_page.dart`) stays valid.
class StudentDashboardPage extends ConsumerWidget {
  const StudentDashboardPage({super.key});

  /// How many imminent assignments to surface.
  static const int _maxAssignments = 4;

  /// How many recent community posts to surface.
  static const int _maxPosts = 4;

  /// How many recent notifications to surface.
  static const int _maxNotifications = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    Future<void> onRefresh() async {
      ref.invalidate(leaveBalanceProvider);
      await Future.wait([
        ref.read(studentAttendanceSummaryProvider.notifier).refresh(),
        ref.read(assignmentListProvider.notifier).refresh(),
        ref.read(boardListProvider.notifier).refresh(),
        ref.read(leaveListProvider.notifier).refresh(),
        ref.read(notificationListProvider.notifier).refresh(),
      ]);
    }

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _GreetingHeader(name: user?.name),
            const SizedBox(height: AppSpacing.lg),
            const _QuickActions(),
            const SizedBox(height: AppSpacing.lg),
            // Responsive: wide → 2-column grid; narrow → single column.
            ResponsiveLayout(
              mobile: (_) => const _DashboardColumn(),
              tablet: (_) => const _DashboardGrid(),
              desktop: (_) => const _DashboardGrid(),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Header + quick actions
/// ─────────────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final displayName = (name != null && name!.trim().isNotEmpty)
        ? name!.trim()
        : '수강생';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('안녕하세요, $displayName님 👋', style: AppTypography.headlineMd),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '오늘의 출결, 과제, 공지를 한눈에 확인하세요.',
          style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Quick-action buttons that jump to the student's primary destinations.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppButton(
          label: '출결 현황',
          icon: Icons.fact_check_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.go('/student/attendance'),
        ),
        AppButton(
          label: '과제',
          icon: Icons.assignment_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.go('/student/assignments'),
        ),
        AppButton(
          label: '커뮤니티',
          icon: Icons.forum_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.go('/student/community'),
        ),
        AppButton(
          label: '조퇴·병결 신청',
          icon: Icons.event_busy_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.go('/student/leave-requests'),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Layout: single column (mobile) vs. 2-column grid (tablet / desktop)
/// ─────────────────────────────────────────────────────────────────────────

/// The dashboard cards, in priority order. Shared by both layouts.
const List<Widget> _cards = [
  _AttendanceCard(),
  _LeaveBalanceCard(),
  _AssignmentsCard(),
  _PostsCard(),
  _LeaveCard(),
  _NotificationsCard(),
];

class _DashboardColumn extends StatelessWidget {
  const _DashboardColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _cards.length; i++) ...[
          _cards[i],
          if (i != _cards.length - 1) const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid();

  @override
  Widget build(BuildContext context) {
    // Two balanced columns; cards distributed round-robin to keep heights even.
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < _cards.length; i++) {
      (i.isEven ? left : right).add(_cards[i]);
    }

    Widget column(List<Widget> children) => Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                const SizedBox(height: AppSpacing.lg),
            ],
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left)),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: column(right)),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Card: 출석률 요약 (ring + 분류 카운트)
/// ─────────────────────────────────────────────────────────────────────────

class _AttendanceCard extends ConsumerWidget {
  const _AttendanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentAttendanceSummaryProvider);
    return _DashboardCard(
      title: '출석률 요약',
      icon: Icons.insights_outlined,
      onSeeAll: () => context.go('/student/attendance'),
      child: async.when(
        loading: () => const _CardLoading(message: '출결 요약을 불러오는 중입니다…'),
        error: (e, _) => _CardError(
          message: e.toString(),
          onRetry: () =>
              ref.read(studentAttendanceSummaryProvider.notifier).refresh(),
        ),
        data: (summary) => summary.totalDays == 0
            ? const EmptyState(
                title: '집계할 출결 기록이 없습니다',
                description: '수업이 시작되면 출석률이 표시됩니다.',
                icon: Icons.insights_outlined,
              )
            : _AttendanceBody(summary: summary),
      ),
    );
  }
}

class _AttendanceBody extends StatelessWidget {
  const _AttendanceBody({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppProgressRing(
              value: summary.attendanceRate.clamp(0.0, 1.0),
              size: 96,
              label: '출석률',
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniStat(label: '총 수업일', value: '${summary.totalDays}일'),
                  const SizedBox(height: AppSpacing.sm),
                  // DISPLAY ONLY: server-derived "3 지각 = 1 결석" value.
                  _MiniStat(
                    label: '환산 결석',
                    value: '${summary.computedAbsent}회',
                    danger: summary.computedAbsent > 0,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            StatusChip(
              label: '${AttendanceType.present.label} ${summary.present}회',
              tone: StatusTone.success,
            ),
            StatusChip(
              label: '${AttendanceType.late.label} ${summary.late}회',
              tone: StatusTone.warning,
            ),
            StatusChip(
              label: '${AttendanceType.absent.label} ${summary.absent}회',
              tone: StatusTone.danger,
            ),
            StatusChip(
              label: '${AttendanceType.earlyLeave.label} ${summary.earlyLeave}회',
              tone: StatusTone.warning,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.headlineSm.copyWith(
            color: danger ? AppColors.error : AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Card: 잔여 휴가 (allowance / used / remaining)
/// ─────────────────────────────────────────────────────────────────────────

class _LeaveBalanceCard extends ConsumerWidget {
  const _LeaveBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaveBalanceProvider);
    return _DashboardCard(
      title: '잔여 휴가',
      icon: Icons.beach_access_outlined,
      child: async.when(
        loading: () => const _CardLoading(message: '휴가 정보를 불러오는 중입니다…'),
        error: (e, _) => _CardError(
          message: e.toString(),
          onRetry: () => ref.invalidate(leaveBalanceProvider),
        ),
        data: (balance) => _LeaveBalanceBody(balance: balance),
      ),
    );
  }
}

class _LeaveBalanceBody extends StatelessWidget {
  const _LeaveBalanceBody({required this.balance});

  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    if (!balance.hasAllowance) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '휴가 한도 미설정',
            style: AppTypography.headlineSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '기수에 휴가 한도가 설정되지 않았습니다.',
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      );
    }

    final remaining = balance.remainingDays ?? 0;
    final allowance = balance.allowanceDays ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '잔여 $remaining일',
              style: AppTypography.displayLg.copyWith(
                color: remaining <= 0 ? AppColors.error : AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '총 $allowance일 중 ${balance.usedDays}일 사용',
          style:
              AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Card: 임박 과제 (D-day)
/// ─────────────────────────────────────────────────────────────────────────

class _AssignmentsCard extends ConsumerWidget {
  const _AssignmentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(assignmentListProvider);
    return _DashboardCard(
      title: '임박 과제',
      icon: Icons.assignment_outlined,
      onSeeAll: () => context.go('/student/assignments'),
      child: async.when(
        loading: () => const _CardLoading(message: '과제를 불러오는 중입니다…'),
        error: (e, _) => _CardError(
          message: e.toString(),
          onRetry: () => ref.read(assignmentListProvider.notifier).refresh(),
        ),
        data: (items) {
          // Still-submittable assignments first (provider already sorts them
          // soonest-due first), then take the top N.
          final imminent = items
              .where((a) => a.canSubmit())
              .take(StudentDashboardPage._maxAssignments)
              .toList();
          if (imminent.isEmpty) {
            return const EmptyState(
              title: '임박한 과제가 없습니다',
              description: '제출할 과제가 생기면 여기에 표시됩니다.',
              icon: Icons.assignment_turned_in_outlined,
            );
          }
          return Column(
            children: [
              for (var i = 0; i < imminent.length; i++) ...[
                _AssignmentTile(assignment: imminent[i]),
                if (i != imminent.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment});

  final Assignment assignment;

  /// D-day label + tone from remaining time (more urgent → more alarming tone).
  ({String label, StatusTone tone}) _dDay() {
    final remaining = assignment.remaining();
    if (remaining.isNegative) {
      return (label: '마감 지남', tone: StatusTone.danger);
    }
    final days = remaining.inDays;
    if (days == 0) {
      return (label: 'D-DAY', tone: StatusTone.danger);
    }
    return (
      label: 'D-$days',
      tone: days <= 2 ? StatusTone.warning : StatusTone.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dday = _dDay();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.go('/student/assignments/${assignment.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '마감 ${DateFormatter.dateTime(assignment.dueDate)}',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          StatusChip(label: dday.label, tone: dday.tone),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Card: 최근 공지/게시글
/// ─────────────────────────────────────────────────────────────────────────

class _PostsCard extends ConsumerWidget {
  const _PostsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(boardListProvider);
    return _DashboardCard(
      title: '최근 공지 · 게시글',
      icon: Icons.forum_outlined,
      onSeeAll: () => context.go('/student/community'),
      child: boardsAsync.when(
        loading: () => const _CardLoading(message: '게시판을 불러오는 중입니다…'),
        error: (e, _) => _CardError(
          message: e.toString(),
          onRetry: () => ref.read(boardListProvider.notifier).refresh(),
        ),
        data: (boards) {
          if (boards.isEmpty) {
            return const EmptyState(
              title: '게시판이 없습니다',
              description: '접근 가능한 게시판이 아직 없습니다.',
              icon: Icons.forum_outlined,
            );
          }
          // Pull posts from the first board (notices sort first server-side).
          final primaryBoard = boards.first;
          return _RecentPostsList(board: primaryBoard);
        },
      ),
    );
  }
}

/// Loads + renders the top posts of [board] (its own AsyncValue, so a failing
/// post fetch doesn't take down the whole posts card).
class _RecentPostsList extends ConsumerWidget {
  const _RecentPostsList({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = PostListArgs(boardId: board.id);
    final async = ref.watch(postListProvider(args));
    return async.when(
      loading: () => const _CardLoading(message: '게시글을 불러오는 중입니다…'),
      error: (e, _) => _CardError(
        message: e.toString(),
        onRetry: () => ref.read(postListProvider(args).notifier).refresh(),
      ),
      data: (posts) {
        final top = posts.take(StudentDashboardPage._maxPosts).toList();
        if (top.isEmpty) {
          return const EmptyState(
            title: '게시글이 없습니다',
            description: '새 글이 올라오면 여기에 표시됩니다.',
            icon: Icons.article_outlined,
          );
        }
        return Column(
          children: [
            for (var i = 0; i < top.length; i++) ...[
              _PostTile(post: top[i]),
              if (i != top.length - 1) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    // Anonymity rule: never surface author_id; show 익명 / 작성자 only.
    final author = post.isAnonymous ? '익명' : '작성자';
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.go('/student/community/posts/${post.id}'),
      child: Row(
        children: [
          if (post.isPinned) ...[
            const Icon(Icons.push_pin_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$author · ${DateFormatter.relative(post.createdAt)}',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.outline),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Card: 내 조퇴 / 병결 상태
/// ─────────────────────────────────────────────────────────────────────────

class _LeaveCard extends ConsumerWidget {
  const _LeaveCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaveListProvider);
    return _DashboardCard(
      title: '내 조퇴 · 병결 상태',
      icon: Icons.event_busy_outlined,
      onSeeAll: () => context.go('/student/leave-requests'),
      child: async.when(
        loading: () => const _CardLoading(message: '신청 내역을 불러오는 중입니다…'),
        error: (e, _) => _CardError(
          message: e.toString(),
          onRetry: () => ref.read(leaveListProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              title: '신청 내역이 없습니다',
              description: '조퇴·병결이 필요하면 신청해 보세요.',
              icon: Icons.event_available_outlined,
            );
          }
          // Most recent few requests (server returns newest-first).
          final recent = items.take(3).toList();
          return Column(
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                _LeaveTile(request: recent[i]),
                if (i != recent.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LeaveTile extends StatelessWidget {
  const _LeaveTile({required this.request});

  final LeaveRequest request;

  StatusTone get _tone {
    switch (request.status) {
      case LeaveStatus.approved:
        return StatusTone.success;
      case LeaveStatus.pending:
        return StatusTone.warning;
      case LeaveStatus.rejected:
        return StatusTone.danger;
      case LeaveStatus.canceled:
        return StatusTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.go('/student/leave-requests/${request.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.type.label} · ${DateFormatter.date(request.targetDate)}',
                  style: AppTypography.bodyMd
                      .copyWith(fontWeight: FontWeight.w600),
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
          const SizedBox(width: AppSpacing.md),
          StatusChip(label: request.status.label, tone: _tone),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Card: 최근 알림
/// ─────────────────────────────────────────────────────────────────────────

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationListProvider);
    return _DashboardCard(
      title: '최근 알림',
      icon: Icons.notifications_none_rounded,
      onSeeAll: () => context.go('/notifications'),
      child: async.when(
        loading: () => const _CardLoading(message: '알림을 불러오는 중입니다…'),
        error: (e, _) => _CardError(
          message: e.toString(),
          onRetry: () =>
              ref.read(notificationListProvider.notifier).refresh(),
        ),
        data: (items) {
          final recent =
              items.take(StudentDashboardPage._maxNotifications).toList();
          if (recent.isEmpty) {
            return const EmptyState(
              title: '알림이 없습니다',
              description: '새 알림이 도착하면 여기에 표시됩니다.',
              icon: Icons.notifications_off_outlined,
            );
          }
          return Column(
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                _NotificationTile(notification: recent[i]),
                if (i != recent.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final created = notification.createdAt;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.go('/notifications'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread dot for quick scanning.
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Icon(
              notification.isRead
                  ? Icons.circle_outlined
                  : Icons.circle,
              size: 10,
              color: notification.isRead
                  ? AppColors.outlineVariant
                  : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: notification.isRead
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
                if (notification.body != null &&
                    notification.body!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    notification.body!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
                if (created != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormatter.relative(created),
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Shared card chrome + per-card loading / error states
/// ─────────────────────────────────────────────────────────────────────────

/// A titled dashboard card with an optional "전체 보기" action in the header.
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.child,
    this.onSeeAll,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.outline),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: AppTypography.headlineSm),
              ),
              if (onSeeAll != null)
                AppButton(
                  label: '전체 보기',
                  variant: AppButtonVariant.tertiary,
                  onPressed: onSeeAll,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Compact in-card loading block (keeps a stable height for layout calm).
class _CardLoading extends StatelessWidget {
  const _CardLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: LoadingView(message: message),
    );
  }
}

/// Compact in-card error block with retry, so one failing card never blocks
/// the rest of the dashboard.
class _CardError extends StatelessWidget {
  const _CardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: ErrorView(message: message, onRetry: onRetry),
    );
  }
}
