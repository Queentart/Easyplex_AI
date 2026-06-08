import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/status_chip.dart';
import '_executive_mock_scaffold.dart';

/// Executive · AI analytics & reports screen (MOCK).
///
/// Combines three reference mockups into a single tabbed screen, replacing the
/// `/executive/analytics` placeholder:
///   - `ai_analytics_reports_dashboard`            → "AI 리포트" tab
///   - `ai_predictive_analytics_intelligence_dashboard` → "예측 분석" tab
///   - `ai_automation_asset_generation_dashboard`  → "자동화 자산" tab
///
/// Everything is static demo data and all actions (report generation, asset
/// generation, Q&A registration) are deliberate NO-OPs that only surface a
/// SnackBar. Flagged with the "데모 데이터" banner + `// MOCK:` comments and
/// `_mock` locals.
///
/// TODO(analytics-api): wire to `GET/POST /reports`,
/// `GET /analytics/predictive/dropout-risk`, `GET /analytics/curriculum-fit`,
/// `POST /ai/assets/generate`, `GET /ai/assets` once those exist, then drop the
/// [ExecutiveMockBanner], the `_mock*` locals and the no-op handlers.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExecutiveMockScaffold(
      title: 'AI 분석 · 리포트',
      subtitle: 'AI 리포트 생성 · 이탈 위험 예측 · 자동화 자산 생성을 한 곳에서 다룹니다.',
      children: [
        const ExecutiveMockBanner(),
        const SizedBox(height: AppSpacing.lg),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'AI 리포트'),
              Tab(text: '예측 분석'),
              Tab(text: '자동화 자산'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Tab views are unbounded inside a scroll view, so render the selected
        // section directly via an AnimatedBuilder rather than a TabBarView.
        AnimatedBuilder(
          animation: _tab,
          builder: (context, _) => switch (_tab.index) {
            0 => const _ReportsTab(),
            1 => const _PredictiveTab(),
            _ => const _AutomationTab(),
          },
        ),
      ],
    );
  }
}

/// Shows the shared "데모" no-op feedback for a tapped action.
void _noOp(BuildContext context, String message) {
  // MOCK: no backend — surface clear demo feedback instead of performing work.
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$message (데모 — 연동 전)')));
}

// ───────────────────────────────────────────────────────────────────────────
// Tab 1 · AI Reports
// ───────────────────────────────────────────────────────────────────────────

class _MockReportKpi {
  const _MockReportKpi({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
}

// MOCK: report summary KPIs. Illustrative only.
const List<_MockReportKpi> _mockReportKpis = [
  _MockReportKpi(
    label: '총 리포트 수',
    value: '124',
    caption: '누적 생성',
    icon: Icons.folder_open_outlined,
  ),
  _MockReportKpi(
    label: '평균 학업 성취도',
    value: '88%',
    caption: '+2.4%',
    icon: Icons.trending_up_outlined,
  ),
  _MockReportKpi(
    label: '취업 준비도',
    value: '75%',
    caption: '목표 80%',
    icon: Icons.work_outline,
  ),
];

class _MockReport {
  const _MockReport({
    required this.title,
    required this.date,
    required this.statusLabel,
    required this.statusTone,
  });

  final String title;
  final String date;
  final String statusLabel;
  final StatusTone statusTone;
}

// MOCK: recently generated reports. Illustrative only.
const List<_MockReport> _mockReports = [
  _MockReport(
    title: 'CS_2024가을_김민수_프로필.pdf',
    date: '10월 24일 09:41',
    statusLabel: '완료',
    statusTone: StatusTone.success,
  ),
  _MockReport(
    title: '데이터분석_3기_종합리포트.pdf',
    date: '10월 23일 17:02',
    statusLabel: '완료',
    statusTone: StatusTone.success,
  ),
  _MockReport(
    title: 'AI엔지니어링_2기_스킬갭분석.pdf',
    date: '10월 22일 11:18',
    statusLabel: '생성 중',
    statusTone: StatusTone.warning,
  ),
];

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExecutiveMockCardGrid(
          children: [
            for (final k in _mockReportKpis)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(k.label, style: AppTypography.labelSm),
                        ),
                        Icon(k.icon, size: 18, color: AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      k.value,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      k.caption,
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _GenerateReportCard(),
        const SizedBox(height: AppSpacing.xl),
        const _RecentReportsCard(),
      ],
    );
  }
}

class _GenerateReportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '새 AI 리포트 생성',
      icon: Icons.smart_toy_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MockDropdown(label: '대상 선택', value: '3기 · 전체 코호트'),
          const SizedBox(height: AppSpacing.md),
          const _MockDropdown(label: '데이터 소스', value: '출결 + LMS 데이터'),
          const SizedBox(height: AppSpacing.md),
          const _MockDropdown(label: '리포트 유형', value: '종합 개요'),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'AI 리포트 생성',
            icon: Icons.auto_awesome_outlined,
            expand: true,
            // MOCK: no /reports endpoint — no-op with demo feedback.
            onPressed: () => _noOp(context, 'AI 리포트 생성을 요청했습니다'),
          ),
        ],
      ),
    );
  }
}

class _RecentReportsCard extends StatelessWidget {
  const _RecentReportsCard();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '최근 생성된 리포트',
      icon: Icons.description_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: _mockReports.isEmpty
          ? const EmptyReportsState()
          : AppDataTable(
              columns: const ['리포트', '생성일', '상태', '동작'],
              columnFlex: const [4, 2, 2, 1],
              rows: [
                for (final r in _mockReports)
                  AppTableRow(
                    cells: [
                      Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              r.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(r.date),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(
                          label: r.statusLabel,
                          tone: r.statusTone,
                        ),
                      ),
                      Builder(
                        builder: (context) => IconButton(
                          tooltip: '다운로드',
                          icon: const Icon(Icons.download_outlined, size: 18),
                          // MOCK: no asset store — no-op with demo feedback.
                          onPressed: () => _noOp(context, '리포트 다운로드'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

/// Empty-state guidance for the reports list (kept for the future API seam).
class EmptyReportsState extends StatelessWidget {
  const EmptyReportsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: AppColors.outline),
          const SizedBox(height: AppSpacing.sm),
          Text('아직 생성된 리포트가 없습니다', style: AppTypography.labelMd),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '위에서 대상을 선택해 첫 AI 리포트를 생성해 보세요.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Tab 2 · Predictive analytics (dropout risk + radar)
// ───────────────────────────────────────────────────────────────────────────

class _MockRiskStudent {
  const _MockRiskStudent({
    required this.name,
    required this.reason,
    required this.level,
    required this.tone,
  });

  final String name;
  final String reason;
  final String level;
  final StatusTone tone;
}

// MOCK: high-risk students. Illustrative only.
const List<_MockRiskStudent> _mockRiskStudents = [
  _MockRiskStudent(
    name: '김철수',
    reason: '최근 2주간 지각 3회',
    level: '높음',
    tone: StatusTone.danger,
  ),
  _MockRiskStudent(
    name: '이영희',
    reason: '최근 모듈 과제 점수 저조',
    level: '중간',
    tone: StatusTone.warning,
  ),
  _MockRiskStudent(
    name: '박지민',
    reason: '특이 위험 신호 없음',
    level: '낮음',
    tone: StatusTone.success,
  ),
];

/// One axis of the curriculum-fit radar (0.0 – 1.0).
class _MockRadarAxis {
  const _MockRadarAxis({required this.label, required this.value});

  final String label;
  final double value;
}

// MOCK: curriculum vs. job-market fit by skill axis. Illustrative only.
const List<_MockRadarAxis> _mockRadarAxes = [
  _MockRadarAxis(label: '프로그래밍', value: 0.94),
  _MockRadarAxis(label: '데이터', value: 0.82),
  _MockRadarAxis(label: 'MLOps', value: 0.68),
  _MockRadarAxis(label: '커뮤니케이션', value: 0.76),
  _MockRadarAxis(label: '협업', value: 0.88),
];

class _PredictiveTab extends StatelessWidget {
  const _PredictiveTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          title: '중도 탈락 위험 예측',
          icon: Icons.warning_amber_outlined,
          trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
          dividerUnderTitle: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '3.2%',
                style: AppTypography.displayLg.copyWith(color: AppColors.error),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '전체 탈락 위험 수준 — 10% 임계값을 크게 밑돌고 있습니다.',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSectionCard(
          title: '고위험 학생 레이더',
          icon: Icons.radar_outlined,
          trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
          dividerUnderTitle: true,
          child: Column(
            children: [
              for (final s in _mockRiskStudents) ...[
                _RiskStudentRow(student: s),
                if (s != _mockRiskStudents.last) const Divider(),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSectionCard(
          title: '커리큘럼 · 취업 시장 적합도',
          icon: Icons.work_outline,
          trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
          dividerUnderTitle: true,
          child: Column(
            children: [
              Center(
                child: CustomPaint(
                  size: const Size(240, 240),
                  painter: _RadarPainter(axes: _mockRadarAxes),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final a in _mockRadarAxes)
                    Text(
                      '${a.label} ${(a.value * 100).round()}%',
                      style: AppTypography.labelSm,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RiskStudentRow extends StatelessWidget {
  const _RiskStudentRow({required this.student});

  final _MockRiskStudent student;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(student.name, style: AppTypography.labelMd),
              const SizedBox(height: AppSpacing.xs),
              Text(
                student.reason,
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        StatusChip(label: student.level, tone: student.tone),
      ],
    );
  }
}

/// Lightweight radar (spider) chart for the curriculum-fit axes.
///
/// MOCK: draws [_mockRadarAxes] only — no chart package, no live data.
class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.axes});

  final List<_MockRadarAxis> axes;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final n = axes.length;
    if (n < 3) return;

    final gridPaint = Paint()
      ..color = AppColors.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Concentric rings.
    for (var ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final path = Path();
      for (var i = 0; i <= n; i++) {
        final angle = -math.pi / 2 + 2 * math.pi * (i % n) / n;
        final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, gridPaint);
    }

    // Spokes.
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      final p = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawLine(center, p, gridPaint);
    }

    // Data polygon.
    final dataPath = Path();
    for (var i = 0; i <= n; i++) {
      final idx = i % n;
      final angle = -math.pi / 2 + 2 * math.pi * idx / n;
      final r = radius * axes[idx].value.clamp(0.0, 1.0);
      final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      i == 0 ? dataPath.moveTo(p.dx, p.dy) : dataPath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.axes != axes;
}

// ───────────────────────────────────────────────────────────────────────────
// Tab 3 · Automation asset generation
// ───────────────────────────────────────────────────────────────────────────

class _MockQa {
  const _MockQa({required this.query});

  final String query;
}

// MOCK: recent chatbot queries. Illustrative only.
const List<_MockQa> _mockQaPairs = [
  _MockQa(query: '외출 몇 시간까지 가능한가요?'),
  _MockQa(query: '출석 체크는 언제 하나요?'),
  _MockQa(query: '서류 제출 기한 연장 되나요?'),
];

class _AutomationTab extends StatelessWidget {
  const _AutomationTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          title: 'Q&A 자동 응답 학습',
          icon: Icons.forum_outlined,
          trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
          dividerUnderTitle: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('최근 24시간', style: AppTypography.labelSm),
                  const SizedBox(width: AppSpacing.sm),
                  const StatusChip(
                    label: '온라인',
                    tone: StatusTone.success,
                    icon: Icons.smart_toy_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              for (final qa in _mockQaPairs) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text('"${qa.query}"', style: AppTypography.bodySm),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: '새 Q&A 쌍 추가',
                icon: Icons.add,
                variant: AppButtonVariant.secondary,
                // MOCK: no /chatbot endpoint — no-op with demo feedback.
                onPressed: () => _noOp(context, 'Q&A 쌍 추가'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _EmploymentReportCard(),
      ],
    );
  }
}

class _EmploymentReportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '취업 분석 리포트 생성',
      icon: Icons.precision_manufacturing_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MockDropdown(label: '코호트 선택', value: '2024 가을 · 컴퓨터공학'),
          const SizedBox(height: AppSpacing.md),
          const _MockDropdown(label: '학생 선택', value: '전체 학생 (배치)'),
          const SizedBox(height: AppSpacing.md),
          const _MockDropdown(label: '포함 데이터', value: '전체 학업 · 활동 이력'),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: '자동화 자산 생성',
            icon: Icons.memory_outlined,
            expand: true,
            // MOCK: no /ai/assets endpoint — no-op with demo feedback.
            onPressed: () => _noOp(context, '취업 분석 리포트 생성을 요청했습니다'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Shared mock form control
// ───────────────────────────────────────────────────────────────────────────

/// A read-only faux dropdown showing a preset MOCK selection.
///
/// MOCK: purely presentational — there is nothing to select against yet.
class _MockDropdown extends StatelessWidget {
  const _MockDropdown({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSm),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value, style: AppTypography.bodyMd)),
              const Icon(
                Icons.expand_more,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
