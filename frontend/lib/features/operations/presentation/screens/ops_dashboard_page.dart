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
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../attendance/domain/attendance_model.dart';
import '../../../inquiry/domain/inquiry_model.dart';
import '../ops_dashboard_provider.dart';

/// Operations / admin command center home.
///
/// Aggregated dashboard for the Operations Team (admin_ops): KPI stats, a
/// recent unprocessed-ticket list, today's attendance summary, and quick links
/// into the management screens. Every metric is sourced READ-ONLY from existing
/// providers/repositories (see [ops_dashboard_provider.dart]); the only
/// non-backed widget is the clearly-labelled MOCK infra panel.
class OpsDashboardPage extends ConsumerWidget {
  const OpsDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final greetingName = user?.name ?? '운영팀';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(name: greetingName),
          const SizedBox(height: AppSpacing.lg),
          const _KpiRow(),
          const SizedBox(height: AppSpacing.lg),
          // Ops screens are tablet/PC-first: two columns on wide viewports,
          // stacked on mobile.
          ResponsiveLayout(
            mobile: (_) => const Column(
              children: [
                _OpenTicketsCard(),
                SizedBox(height: AppSpacing.lg),
                _AttendanceSummaryCard(),
              ],
            ),
            tablet: (_) => const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _OpenTicketsCard()),
                SizedBox(width: AppSpacing.lg),
                Expanded(flex: 2, child: _AttendanceSummaryCard()),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _QuickLinksCard(),
          const SizedBox(height: AppSpacing.lg),
          const _MockInfraCard(),
        ],
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Header
/// ───────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('운영 현황 대시보드', style: AppTypography.headlineMd),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$name님, 오늘 처리할 운영 지표를 한눈에 확인하세요.',
          style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// KPI stat row — counts derived from list/pagination meta
/// ───────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context) {
    const cards = <Widget>[
      _UserKpiCard(),
      _CohortKpiCard(),
      _OpenInquiryKpiCard(),
      _AttendanceAnomalyKpiCard(),
    ];

    return ResponsiveLayout(
      // Mobile: 1 per row. Tablet: 2 per row. Desktop: 4 across.
      mobile: (_) => const _KpiGrid(crossAxisCount: 1, children: cards),
      tablet: (_) => const _KpiGrid(crossAxisCount: 2, children: cards),
      desktop: (_) => const _KpiGrid(crossAxisCount: 4, children: cards),
    );
  }
}

/// A responsive, fixed-column grid of KPI tiles that sizes to content height.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.crossAxisCount, required this.children});

  final int crossAxisCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalGutter = AppSpacing.gutter * (crossAxisCount - 1);
        final tileWidth =
            (constraints.maxWidth - totalGutter) / crossAxisCount;
        return Wrap(
          spacing: AppSpacing.gutter,
          runSpacing: AppSpacing.gutter,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Renders a [StatCard] whose value depends on an [AsyncValue<int>] count,
/// degrading to a dash on error and a hyphen-spinner glyph while loading.
class _CountStatCard extends StatelessWidget {
  const _CountStatCard({
    required this.label,
    required this.icon,
    required this.count,
    this.suffix = '',
  });

  final String label;
  final IconData icon;
  final AsyncValue<int> count;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final value = count.when(
      data: (n) => '$n$suffix',
      loading: () => '—',
      error: (_, _) => '!',
    );
    return StatCard(label: label, value: value, icon: icon);
  }
}

class _UserKpiCard extends ConsumerWidget {
  const _UserKpiCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CountStatCard(
      label: '전체 사용자 수',
      icon: Icons.people_outline,
      count: ref.watch(opsUserCountProvider),
      suffix: '명',
    );
  }
}

class _CohortKpiCard extends ConsumerWidget {
  const _CohortKpiCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CountStatCard(
      label: '기수 수',
      icon: Icons.school_outlined,
      count: ref.watch(opsCohortCountProvider),
      suffix: '개',
    );
  }
}

class _OpenInquiryKpiCard extends ConsumerWidget {
  const _OpenInquiryKpiCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CountStatCard(
      label: '미처리 문의 수',
      icon: Icons.support_agent_outlined,
      count: ref.watch(opsOpenInquiryCountProvider),
      suffix: '건',
    );
  }
}

class _AttendanceAnomalyKpiCard extends ConsumerWidget {
  const _AttendanceAnomalyKpiCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(opsAttendanceTodaySummaryProvider);
    return _CountStatCard(
      label: '출결 이상 (오늘)',
      icon: Icons.event_busy_outlined,
      count: summary.whenData((s) => s.anomalies),
      suffix: '건',
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Open tickets card → tap navigates to /ops/issues
/// ───────────────────────────────────────────────────────────────────────────

class _OpenTicketsCard extends ConsumerWidget {
  const _OpenTicketsCard();

  static const int _maxRows = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(opsRecentOpenInquiriesProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardHeader(
            icon: Icons.confirmation_number_outlined,
            title: '미처리 문의 / 티켓',
            actionLabel: '전체 보기',
            onAction: () => context.go('/ops/issues'),
          ),
          const SizedBox(height: AppSpacing.md),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(opsRecentOpenInquiriesProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  title: '미처리 문의가 없습니다',
                  description: '새로운 문의가 접수되면 이곳에 표시됩니다.',
                  icon: Icons.inbox_outlined,
                );
              }
              final rows = items.take(_maxRows).toList();
              return _TicketTable(
                items: rows,
                onRowTap: (id) => context.go('/ops/issues/$id'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TicketTable extends StatelessWidget {
  const _TicketTable({required this.items, required this.onRowTap});

  final List<Inquiry> items;
  final void Function(int id) onRowTap;

  StatusTone _priorityTone(InquiryPriority p) {
    switch (p) {
      case InquiryPriority.urgent:
        return StatusTone.danger;
      case InquiryPriority.high:
        return StatusTone.warning;
      case InquiryPriority.normal:
        return StatusTone.info;
      case InquiryPriority.low:
        return StatusTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDataTable(
      columns: const ['제목', '유형', '우선순위', '접수'],
      columnFlex: const [4, 2, 2, 2],
      rows: [
        for (final i in items)
          AppTableRow(
            highlight: i.priorityEnum == InquiryPriority.urgent,
            cells: [
              _LinkText(text: i.title, onTap: () => onRowTap(i.id)),
              Text(i.typeEnum.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: i.priorityEnum.label,
                  tone: _priorityTone(i.priorityEnum),
                ),
              ),
              Text(
                DateFormatter.relative(i.createdAt),
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySm.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Attendance summary card → tap navigates to /ops/attendance
/// ───────────────────────────────────────────────────────────────────────────

class _AttendanceSummaryCard extends ConsumerWidget {
  const _AttendanceSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(opsAttendanceTodaySummaryProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardHeader(
            icon: Icons.fact_check_outlined,
            title: '출결 현황 요약 (오늘)',
            actionLabel: '관리',
            onAction: () => context.go('/ops/attendance'),
          ),
          const SizedBox(height: AppSpacing.md),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(opsAttendanceTodayProvider),
            ),
            data: (s) {
              if (s.total == 0) {
                return const EmptyState(
                  title: '오늘 출결 기록이 없습니다',
                  description: '출결 데이터가 집계되면 이곳에 표시됩니다.',
                  icon: Icons.event_available_outlined,
                );
              }
              return _AttendanceBreakdown(summary: s);
            },
          ),
        ],
      ),
    );
  }
}

class _AttendanceBreakdown extends StatelessWidget {
  const _AttendanceBreakdown({required this.summary});

  final AttendanceTodaySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AttendanceStatRow(
          label: AttendanceType.present.label,
          count: summary.present,
          tone: StatusTone.success,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AttendanceStatRow(
          label: AttendanceType.late.label,
          count: summary.late,
          tone: StatusTone.warning,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AttendanceStatRow(
          label: AttendanceType.absent.label,
          count: summary.absent,
          tone: StatusTone.danger,
        ),
        const SizedBox(height: AppSpacing.sm),
        _AttendanceStatRow(
          label: AttendanceType.earlyLeave.label,
          count: summary.earlyLeave,
          tone: StatusTone.info,
        ),
        const Divider(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('총 기록', style: AppTypography.labelMd),
            Text('${summary.total}건', style: AppTypography.labelMd),
          ],
        ),
      ],
    );
  }
}

class _AttendanceStatRow extends StatelessWidget {
  const _AttendanceStatRow({
    required this.label,
    required this.count,
    required this.tone,
  });

  final String label;
  final int count;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        StatusChip(label: label, tone: tone),
        Text(
          '$count건',
          style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Quick links
/// ───────────────────────────────────────────────────────────────────────────

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard();

  @override
  Widget build(BuildContext context) {
    final links = <_QuickLink>[
      const _QuickLink(label: '사용자', icon: Icons.people_outline, path: '/ops/users'),
      const _QuickLink(label: '기수', icon: Icons.school_outlined, path: '/ops/cohorts'),
      const _QuickLink(
          label: '문의', icon: Icons.support_agent_outlined, path: '/ops/issues'),
      const _QuickLink(
          label: '출결', icon: Icons.fact_check_outlined, path: '/ops/attendance'),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_outlined,
                  size: 20, color: AppColors.outline),
              const SizedBox(width: AppSpacing.sm),
              Text('빠른 이동', style: AppTypography.headlineSm),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final link in links)
                AppButton(
                  label: link.label,
                  icon: link.icon,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go(link.path),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLink {
  const _QuickLink({required this.label, required this.icon, required this.path});

  final String label;
  final IconData icon;
  final String path;
}

/// ───────────────────────────────────────────────────────────────────────────
/// MOCK infra panel — NO backend endpoint exists for these metrics yet.
///
/// These values are HARD-CODED demo numbers, NOT real telemetry. They are
/// visually flagged with a "데모" chip and kept in a `_mock...` constant so they
/// can never be mistaken for live data or wired to a real provider by accident.
/// ───────────────────────────────────────────────────────────────────────────

class _MockInfraCard extends StatelessWidget {
  const _MockInfraCard();

  // MOCK: no backend for infra health / sync status / system load yet.
  static const _mockInfraMetrics = <({String label, String value})>[
    (label: '인프라 상태', value: '정상'),
    (label: '동기화 상태', value: '최신'),
    (label: '시스템 부하', value: '32%'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined,
                  size: 20, color: AppColors.outline),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('시스템 모니터링', style: AppTypography.headlineSm),
              ),
              const StatusChip(label: '데모', tone: StatusTone.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '아래 지표는 백엔드 연동 전 데모 값입니다. 실제 데이터가 아닙니다.',
            style:
                AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.gutter,
            runSpacing: AppSpacing.gutter,
            children: [
              for (final m in _mockInfraMetrics)
                _MockMetricTile(label: m.label, value: m.value),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockMetricTile extends StatelessWidget {
  const _MockMetricTile({required this.label, required this.value});

  final String label;
  final String value;

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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.labelSm),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.headlineSm),
        ],
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Shared card header with a trailing tertiary action button.
/// ───────────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.outline),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(title, style: AppTypography.headlineSm)),
        AppButton(
          label: actionLabel,
          icon: Icons.arrow_forward,
          variant: AppButtonVariant.tertiary,
          onPressed: onAction,
        ),
      ],
    );
  }
}
