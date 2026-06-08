import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '_executive_mock_scaffold.dart';

/// Executive · Strategic KPIs / ROI analysis screen (MOCK).
///
/// Reference mockup: `strategic_kpis_roi_analysis_dashboard`.
///
/// Replaces the `/executive/kpis` placeholder. Every figure on this screen is
/// static demo data — there is NO `/analytics/*` backend endpoint yet, so all
/// values are clearly flagged with a "데모 데이터" banner + `// MOCK:` comments
/// and `_mock` locals. See [_mockKpis], [_mockTrend], [_mockCohortPerformance]
/// and [_mockRoiRows].
///
/// TODO(analytics-api): wire to `GET /analytics/executive/kpis`,
/// `GET /analytics/roi`, `GET /analytics/cohort-performance` once those exist,
/// then drop the [ExecutiveMockBanner] and the `_mock*` locals.
class KpiRoiScreen extends StatelessWidget {
  const KpiRoiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ExecutiveMockScaffold(
      title: 'KPI · ROI 분석',
      subtitle: '매출 · 수익성 · 배치별 성과를 한 곳에서 확인하세요.',
      children: const [
        ExecutiveMockBanner(),
        SizedBox(height: AppSpacing.lg),
        _HeadlineKpiSection(),
        SizedBox(height: AppSpacing.xl),
        _TrendSection(),
        SizedBox(height: AppSpacing.xl),
        _CohortPerformanceSection(),
        SizedBox(height: AppSpacing.xl),
        _RoiInsightSection(),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// MOCK data models + fixtures (demo only — no backing endpoint)
// ───────────────────────────────────────────────────────────────────────────

/// A single mocked headline KPI tile.
class _MockKpi {
  const _MockKpi({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
  });

  final String label;
  final String value;
  final String delta;
  final IconData icon;
}

// MOCK: headline profitability / placement / ROI figures. Illustrative only.
const List<_MockKpi> _mockKpis = [
  _MockKpi(
    label: '전체 수익성',
    value: '24.5%',
    delta: '+2.1%p 전분기 대비',
    icon: Icons.trending_up_outlined,
  ),
  _MockKpi(
    label: '평균 취업률',
    value: '88.2%',
    delta: '목표 85% 초과',
    icon: Icons.school_outlined,
  ),
  _MockKpi(
    label: '글로벌 ROI',
    value: '142%',
    delta: '전망치 상회',
    icon: Icons.public_outlined,
  ),
];

/// A monthly point on the revenue / OpEx trend.
class _MockTrendPoint {
  const _MockTrendPoint({
    required this.month,
    required this.revenue,
    required this.opex,
  });

  final String month;

  /// 0.0 – 1.0 normalized against the chart ceiling (drives the bar height).
  final double revenue;
  final double opex;
}

// MOCK: revenue vs. operating-expense trend (normalized to a $5M ceiling).
const List<_MockTrendPoint> _mockTrend = [
  _MockTrendPoint(month: '4월', revenue: 0.62, opex: 0.41),
  _MockTrendPoint(month: '5월', revenue: 0.74, opex: 0.46),
  _MockTrendPoint(month: '6월', revenue: 0.86, opex: 0.49),
];

/// A cohort placement-performance row (progress bar).
class _MockCohortPerf {
  const _MockCohortPerf({required this.name, required this.rate});

  final String name;

  /// 0.0 – 1.0 placement rate.
  final double rate;
}

// MOCK: placement performance by cohort. Illustrative only.
const List<_MockCohortPerf> _mockCohortPerformance = [
  _MockCohortPerf(name: '1기 · 데이터 사이언스', rate: 0.90),
  _MockCohortPerf(name: '2기 · 머신러닝', rate: 0.85),
  _MockCohortPerf(name: '3기 · AI 엔지니어링', rate: 0.92),
];

/// A row in the ROI-by-category insight table.
class _MockRoiRow {
  const _MockRoiRow({
    required this.category,
    required this.budget,
    required this.roiRatio,
    required this.statusLabel,
    required this.statusTone,
  });

  final String category;
  final String budget;
  final String roiRatio;
  final String statusLabel;
  final StatusTone statusTone;
}

// MOCK: ROI analysis by spend category. Illustrative only.
const List<_MockRoiRow> _mockRoiRows = [
  _MockRoiRow(
    category: '마케팅',
    budget: '₩ 120,000,000',
    roiRatio: '3.2x',
    statusLabel: '우수',
    statusTone: StatusTone.success,
  ),
  _MockRoiRow(
    category: '인프라',
    budget: '₩ 45,000,000',
    roiRatio: '1.8x',
    statusLabel: '주의',
    statusTone: StatusTone.warning,
  ),
  _MockRoiRow(
    category: '운영',
    budget: '₩ 85,000,000',
    roiRatio: '2.5x',
    statusLabel: '양호',
    statusTone: StatusTone.info,
  ),
];

// ───────────────────────────────────────────────────────────────────────────
// Sections
// ───────────────────────────────────────────────────────────────────────────

class _HeadlineKpiSection extends StatelessWidget {
  const _HeadlineKpiSection();

  @override
  Widget build(BuildContext context) {
    return ExecutiveMockCardGrid(
      children: [
        for (final kpi in _mockKpis)
          StatCard(
            label: kpi.label,
            value: kpi.value,
            icon: kpi.icon,
            delta: kpi.delta,
          ),
      ],
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '수익성 · 가동률 추세',
      icon: Icons.bar_chart_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in _mockTrend)
                  Expanded(child: _TrendColumn(point: p)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LegendDot(color: AppColors.primary, label: '매출'),
              SizedBox(width: AppSpacing.lg),
              _LegendDot(color: AppColors.secondaryFixedDim, label: '운영비'),
            ],
          ),
        ],
      ),
    );
  }
}

/// One month's paired revenue / OpEx bars. Pure CSS-style bars (no chart pkg).
class _TrendColumn extends StatelessWidget {
  const _TrendColumn({required this.point});

  final _MockTrendPoint point;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Bar(fraction: point.revenue, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              _Bar(fraction: point.opex, color: AppColors.secondaryFixedDim),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(point.month, style: AppTypography.labelSm),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 140.0;
        return Container(
          width: 18,
          height: (maxH * fraction).clamp(4.0, maxH),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sm),
            ),
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.bodySm),
      ],
    );
  }
}

class _CohortPerformanceSection extends StatelessWidget {
  const _CohortPerformanceSection();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '배치별 취업 성과',
      icon: Icons.workspace_premium_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: Column(
        children: [
          for (final c in _mockCohortPerformance) ...[
            _CohortPerfRow(perf: c),
            if (c != _mockCohortPerformance.last)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _CohortPerfRow extends StatelessWidget {
  const _CohortPerfRow({required this.perf});

  final _MockCohortPerf perf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(perf.name, style: AppTypography.labelMd)),
            Text(
              '${(perf.rate * 100).round()}%',
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgressBar(value: perf.rate),
      ],
    );
  }
}

class _RoiInsightSection extends StatelessWidget {
  const _RoiInsightSection();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'AI ROI 분석 인사이트',
      icon: Icons.insights_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: AppDataTable(
        columns: const ['카테고리', '집행 예산', 'ROI 비율', '상태'],
        columnFlex: const [2, 2, 1, 1],
        rows: [
          for (final r in _mockRoiRows)
            AppTableRow(
              cells: [
                Text(r.category),
                Text(r.budget),
                Text(r.roiRatio),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(label: r.statusLabel, tone: r.statusTone),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
