import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../executive_provider.dart';

/// Executive / owner center home — aggregate KPI dashboard.
///
/// Reference mockup: `owner_executive_center_dashboard`.
///
/// Composition only: the REAL headline counts are derived (read-only) from the
/// operations list/paged providers via the executive aggregate providers; the
/// strategic finance / churn metrics are clearly-labelled MOCKs until an
/// analytics endpoint exists (see [executive_provider.dart]).
///
/// The executive area is surfaced to `admin_ops` today (no dedicated backend
/// role), so this renders for whoever lands here.
class ExecutiveDashboardPage extends ConsumerWidget {
  const ExecutiveDashboardPage({super.key});

  /// AI co-pilot destination. The mockup labels this "/executive/ai", but only
  /// the area-scoped agent routes are registered (`/ops/ai` etc., see
  /// `ai_agent_routes.dart`); since the executive area is surfaced to
  /// `admin_ops`, we enter the agent through the registered ops route.
  static const _aiRoute = '/ops/ai';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => refreshExecutiveAggregates(ref),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GreetingHeader(name: user?.name),
                    const SizedBox(height: AppSpacing.lg),
                    const _RealKpiSection(),
                    const SizedBox(height: AppSpacing.xl),
                    const _MockStrategicSection(),
                    const SizedBox(height: AppSpacing.xl),
                    _AiCopilotCard(
                      onEnter: () => context.go(_aiRoute),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Greeting header with the platform context line.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final greeting = (name != null && name!.trim().isNotEmpty)
        ? '$name님, 환영합니다'
        : '경영 대시보드';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: AppTypography.headlineLg),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '핵심 운영 지표와 전략 인사이트를 한 곳에서 확인하세요.',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// REAL aggregate KPIs (derived from list / pagination meta)
/// ─────────────────────────────────────────────────────────────────────────
class _RealKpiSection extends ConsumerWidget {
  const _RealKpiSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCount = ref.watch(executiveUserCountProvider);
    final cohortCount = ref.watch(executiveCohortCountProvider);
    final licenseCount = ref.watch(executiveLicenseCountProvider);

    final cards = <Widget>[
      _KpiStat(
        label: '전체 사용자 수',
        icon: Icons.groups_outlined,
        value: userCount,
        onRetry: () => refreshExecutiveAggregates(ref),
      ),
      _KpiStat(
        label: '기수 수',
        icon: Icons.school_outlined,
        value: cohortCount,
        onRetry: () => refreshExecutiveAggregates(ref),
      ),
      _KpiStat(
        label: '라이선스 수',
        icon: Icons.vpn_key_outlined,
        value: licenseCount,
        onRetry: () => refreshExecutiveAggregates(ref),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('집계 KPI', style: AppTypography.headlineMd),
            const SizedBox(width: AppSpacing.sm),
            const StatusChip(
              label: '실데이터',
              tone: StatusTone.success,
              icon: Icons.verified_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ResponsiveCardGrid(children: cards),
      ],
    );
  }
}

/// A single REAL KPI tile. Renders a per-metric [AsyncValue]: a placeholder
/// while loading, a [StatCard] with the count on success, and an inline retry
/// affordance on error (so one failing metric never blocks the dashboard).
class _KpiStat extends StatelessWidget {
  const _KpiStat({
    required this.label,
    required this.icon,
    required this.value,
    required this.onRetry,
  });

  final String label;
  final IconData icon;
  final AsyncValue<int> value;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => _LoadingStat(label: label, icon: icon),
      error: (error, stack) =>
          _ErrorStat(label: label, icon: icon, onRetry: onRetry),
      data: (count) => StatCard(
        label: label,
        value: _formatCount(count),
        icon: icon,
      ),
    );
  }
}

/// Loading variant of a KPI tile — same card frame, value replaced by a small
/// spinner + "불러오는 중" so the layout doesn't jump.
class _LoadingStat extends StatelessWidget {
  const _LoadingStat({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatLabelRow(label: label, icon: icon),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '불러오는 중',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Error variant of a KPI tile with an inline retry button.
class _ErrorStat extends StatelessWidget {
  const _ErrorStat({
    required this.label,
    required this.icon,
    required this.onRetry,
  });

  final String label;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatLabelRow(label: label, icon: icon),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '불러오지 못했습니다.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: '다시 시도',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.tertiary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Shared label + icon row matching the [StatCard] header.
class _StatLabelRow extends StatelessWidget {
  const _StatLabelRow({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// MOCK strategic section (clearly flagged "데모")
/// ─────────────────────────────────────────────────────────────────────────
class _MockStrategicSection extends StatelessWidget {
  const _MockStrategicSection();

  @override
  Widget build(BuildContext context) {
    final metricCards = [
      for (final m in mockStrategicMetrics)
        StatCard(
          label: m.label,
          value: m.value,
          delta: m.delta,
          deltaPositive: m.deltaPositive,
          icon: Icons.insights_outlined,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('전략 지표', style: AppTypography.headlineMd),
            const SizedBox(width: AppSpacing.sm),
            const StatusChip(
              label: '데모',
              tone: StatusTone.warning,
              icon: Icons.science_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '매출 · 비용 · ROI · 이탈 예측은 연동 전 샘플 데이터입니다.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ResponsiveCardGrid(children: metricCards),
        const SizedBox(height: AppSpacing.md),
        const _MockChurnPanel(),
      ],
    );
  }
}

/// MOCK churn-risk panel: a labelled card listing predicted-churn cohorts with
/// a progress bar per row. Purely illustrative until a prediction service ships.
class _MockChurnPanel extends StatelessWidget {
  const _MockChurnPanel();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '이탈 예측',
      icon: Icons.warning_amber_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: Column(
        children: [
          for (final risk in mockChurnRisks) ...[
            _ChurnRiskRow(risk: risk),
            if (risk != mockChurnRisks.last)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _ChurnRiskRow extends StatelessWidget {
  const _ChurnRiskRow({required this.risk});

  final MockChurnRisk risk;

  @override
  Widget build(BuildContext context) {
    final isHigh = risk.riskRatio >= 0.25;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(risk.cohortName, style: AppTypography.labelMd),
            ),
            Text(
              '${(risk.riskRatio * 100).round()}% · ${risk.atRiskCount}명',
              style: AppTypography.bodySm.copyWith(
                color: isHigh ? AppColors.error : AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgressBar(
          value: risk.riskRatio,
          color: isHigh ? AppColors.error : AppColors.primary,
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// AI co-pilot entry
/// ─────────────────────────────────────────────────────────────────────────
class _AiCopilotCard extends StatelessWidget {
  const _AiCopilotCard({required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onEnter,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 코파일럿', style: AppTypography.headlineSm),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '운영 데이터를 자연어로 질문하고 리포트를 생성하세요.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppButton(
            label: '열기',
            icon: Icons.arrow_forward_rounded,
            onPressed: onEnter,
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Responsive card grid
/// ─────────────────────────────────────────────────────────────────────────
///
/// Lays cards out in a column on mobile and an even row on tablet/desktop
/// (executive screens are PC-first). Uses [ResponsiveLayout] + design-system
/// spacing tokens — no magic numbers.
class _ResponsiveCardGrid extends StatelessWidget {
  const _ResponsiveCardGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const SizedBox(height: AppSpacing.gutter),
          ],
        ],
      ),
      tablet: (_) => _row(),
    );
  }

  Widget _row() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1)
            const SizedBox(width: AppSpacing.gutter),
        ],
      ],
    );
  }
}

/// Formats an integer count with thousands separators (e.g. 1234 → "1,234").
String _formatCount(int n) {
  final digits = n.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return n < 0 ? '-$buffer' : buffer.toString();
}
