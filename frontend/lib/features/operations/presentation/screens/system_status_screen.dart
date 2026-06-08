import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../widgets/mock_demo_banner.dart';

/// Operations · 시스템 상태 / 인프라 모니터링 (MOCK-ONLY).
///
/// Faithful to the `system_status_infra_monitoring_1` / `_2` Stitch mockups:
/// uptime / incident / latency KPIs, server & AI-engine resource gauges
/// (CPU / 메모리 / GPU VRAM), and a recent infrastructure-event stream.
///
/// ── DATA SOURCE ────────────────────────────────────────────────────────────
/// EVERY value on this screen is HARD-CODED demo data. There is no backend for
/// system telemetry yet. When the future `/system/status`, `/system/metrics`
/// and `/system/events` endpoints land, replace the `_mock*` constants below
/// with a repository/provider read. See the repository seam at the bottom of
/// this file. Until then a visible "데모 데이터" banner flags the mock state.
class SystemStatusScreen extends StatelessWidget {
  const SystemStatusScreen({super.key});

  static const String routePath = '/ops/status';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const SizedBox(height: AppSpacing.md),
          const MockDemoBanner(),
          const SizedBox(height: AppSpacing.lg),
          const _KpiRow(),
          const SizedBox(height: AppSpacing.lg),
          // Ops screens are tablet/PC-first: resources beside the event stream
          // on wide viewports, stacked on mobile.
          ResponsiveLayout(
            mobile: (_) => const Column(
              children: [
                _ResourcesCard(),
                SizedBox(height: AppSpacing.lg),
                _EventStreamCard(),
              ],
            ),
            tablet: (_) => const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _ResourcesCard()),
                SizedBox(width: AppSpacing.lg),
                Expanded(flex: 3, child: _EventStreamCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// Header
/// ───────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('시스템 상태 · 인프라 모니터링', style: AppTypography.headlineMd),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'EduAI 플랫폼의 가동률과 서버 · AI 엔진 리소스를 한눈에 확인하세요.',
          style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// KPI row — uptime / incidents / latency
/// ───────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context) {
    const cards = <Widget>[
      // MOCK: global uptime over the past 30 days.
      StatCard(
        label: '전체 가동률',
        value: '99.98%',
        icon: Icons.public_outlined,
        delta: '최근 30일',
      ),
      // MOCK: active infrastructure incidents.
      StatCard(
        label: '활성 인시던트',
        value: '0건',
        icon: Icons.crisis_alert_outlined,
        delta: '모든 시스템 정상',
      ),
      // MOCK: average API latency (US-East region).
      StatCard(
        label: '평균 API 지연',
        value: '45ms',
        icon: Icons.speed_outlined,
        delta: '정상 범위',
      ),
    ];

    return ResponsiveLayout(
      mobile: (_) => const _KpiGrid(crossAxisCount: 1, children: cards),
      tablet: (_) => const _KpiGrid(crossAxisCount: 3, children: cards),
    );
  }
}

/// Responsive fixed-column grid that sizes to content height.
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

/// ───────────────────────────────────────────────────────────────────────────
/// Server & AI engine resource gauges
/// ───────────────────────────────────────────────────────────────────────────

/// A single resource gauge: label + percentage + a tinted [AppProgressBar].
typedef _ResourceMetric = ({String label, IconData icon, double value});

// MOCK: server / AI-engine resource utilization (0.0–1.0). No backend yet.
const _mockResources = <_ResourceMetric>[
  (label: '메인 DB CPU 사용률', icon: Icons.dns_outlined, value: 0.35),
  (label: '메모리 할당', icon: Icons.memory_outlined, value: 0.62),
  (label: 'AI 모델 GPU VRAM 사용률', icon: Icons.developer_board_outlined, value: 0.85),
];

class _ResourcesCard extends StatelessWidget {
  const _ResourcesCard();

  /// Teal → amber → red as load increases (mirrors the mockup tones).
  static Color _toneFor(double value) {
    if (value >= 0.8) return AppColors.error;
    if (value >= 0.6) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '서버 · AI 엔진 리소스',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _mockResources.length; i++) ...[
            if (i != 0) const SizedBox(height: AppSpacing.lg),
            _ResourceGauge(
              metric: _mockResources[i],
              color: _toneFor(_mockResources[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResourceGauge extends StatelessWidget {
  const _ResourceGauge({required this.metric, required this.color});

  final _ResourceMetric metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = '${(metric.value * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(metric.icon, size: 18, color: AppColors.outline),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(metric.label, style: AppTypography.labelMd),
            ),
            Text(
              percent,
              style: AppTypography.labelMd.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgressBar(value: metric.value, color: color),
      ],
    );
  }
}

/// ───────────────────────────────────────────────────────────────────────────
/// System event stream (recent infra alerts)
/// ───────────────────────────────────────────────────────────────────────────

enum _Severity { critical, warning, info }

extension _SeverityX on _Severity {
  String get label => switch (this) {
        _Severity.critical => '심각',
        _Severity.warning => '경고',
        _Severity.info => '정보',
      };

  StatusTone get tone => switch (this) {
        _Severity.critical => StatusTone.danger,
        _Severity.warning => StatusTone.warning,
        _Severity.info => StatusTone.info,
      };

  IconData get icon => switch (this) {
        _Severity.critical => Icons.error_outline,
        _Severity.warning => Icons.warning_amber_outlined,
        _Severity.info => Icons.info_outline,
      };
}

typedef _SystemEvent = ({String name, String time, _Severity severity});

// MOCK: recent system events. No `/system/events` endpoint yet.
const _mockEvents = <_SystemEvent>[
  (name: 'LangGraph 에이전트 타임아웃', time: '2분 전', severity: _Severity.critical),
  (name: '노드 오토스케일링 발생', time: '15분 전', severity: _Severity.warning),
  (name: 'DB 백업 완료', time: '1시간 전', severity: _Severity.info),
  (name: '사용자 동기화 루틴 시작', time: '2시간 전', severity: _Severity.info),
];

class _EventStreamCard extends StatelessWidget {
  const _EventStreamCard();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '시스템 이벤트 스트림',
      icon: Icons.stream_outlined,
      child: AppDataTable(
        columns: const ['이벤트', '시각', '심각도'],
        columnFlex: const [5, 2, 2],
        rows: [
          for (final e in _mockEvents)
            AppTableRow(
              highlight: e.severity == _Severity.critical,
              cells: [
                Row(
                  children: [
                    Icon(
                      e.severity.icon,
                      size: 16,
                      color: switch (e.severity) {
                        _Severity.critical => AppColors.error,
                        _Severity.warning => AppColors.warning,
                        _Severity.info => AppColors.onSurfaceVariant,
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  e.time,
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(label: e.severity.label, tone: e.severity.tone),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── REPOSITORY SEAM ──────────────────────────────────────────────────────────
// TODO(backend): replace the `_mock*` constants above with a real data source
// once system telemetry endpoints exist, e.g.:
//
//   final repo = SystemMonitoringRepository(dio);
//   final status  = await repo.getStatus();    // GET /system/status
//   final metrics = await repo.getMetrics();    // GET /system/metrics
//   final events  = await repo.getEvents();     // GET /system/events
//
// Wrap this screen's body in an AsyncValue.when(...) (loading / error+retry /
// data) exactly like ops_dashboard_page.dart does for backed providers.
