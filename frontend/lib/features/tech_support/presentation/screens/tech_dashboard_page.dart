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
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../inquiry/domain/inquiry_model.dart';
import '../tech_dashboard_provider.dart';

/// Tech Support infra-control home dashboard.
///
/// Replaces the former placeholder. Four cards, each carrying its own
/// AsyncValue (independent loading / error / retry):
///   1. 미처리 티켓        — open-ticket count + recent feed → /tech/issues
///   2. 라이선스 현황       — total + expiring-soon            → /tech/licenses
///   3. 인프라/시스템 지표  — MOCK demo metrics (no backend)
///   4. AI 코파일럿        — entry card                       → /tech/ai
///
/// Reuses the existing inquiry / license providers via the read-only
/// aggregation layer in `tech_dashboard_provider.dart`. Data layers are NOT
/// rebuilt here.
class TechDashboardPage extends ConsumerWidget {
  const TechDashboardPage({super.key});

  // Tap destinations (routes already registered in inquiry/ai_agent routes).
  static const _issuesRoute = '/tech/issues';
  static const _licensesRoute = '/tech/licenses';
  static const _aiRoute = '/tech/ai';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(currentUserProvider)?.name ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(userName: userName),
          const SizedBox(height: AppSpacing.lg),
          ResponsiveLayout(
            mobile: (_) => const _DashboardColumn(),
            tablet: (_) => const _DashboardGrid(twoColumn: true),
            desktop: (_) => const _DashboardGrid(twoColumn: true),
          ),
        ],
      ),
    );
  }
}

/// Greeting + page subtitle.
class _Header extends StatelessWidget {
  const _Header({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    final greeting = userName.isEmpty ? '기술지원 현황' : '$userName님, 기술지원 현황';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: AppTypography.headlineMd),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '티켓 · 라이선스 · 인프라 모니터링을 한눈에 확인하세요.',
          style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Single-column stack for mobile.
class _DashboardColumn extends StatelessWidget {
  const _DashboardColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TicketCard(),
        SizedBox(height: AppSpacing.lg),
        _LicenseCard(),
        SizedBox(height: AppSpacing.lg),
        _InfraCard(),
        SizedBox(height: AppSpacing.lg),
        _AiCopilotCard(),
      ],
    );
  }
}

/// Two-column grid for tablet / desktop (operations-team first layout).
class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.twoColumn});

  final bool twoColumn;

  @override
  Widget build(BuildContext context) {
    if (!twoColumn) return const _DashboardColumn();

    const gap = SizedBox(width: AppSpacing.lg);
    const vGap = SizedBox(height: AppSpacing.lg);

    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TicketCard()),
              gap,
              Expanded(child: _LicenseCard()),
            ],
          ),
        ),
        vGap,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _InfraCard()),
              gap,
              Expanded(child: _AiCopilotCard()),
            ],
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Card (1) — 미처리 티켓 (REAL: inquiryListProvider)
/// ─────────────────────────────────────────────────────────────────────────
class _TicketCard extends ConsumerWidget {
  const _TicketCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(techTicketSummaryProvider);
    return _SectionScaffold(
      icon: Icons.confirmation_number_outlined,
      title: '미처리 티켓',
      onTap: () => context.go(TechDashboardPage._issuesRoute),
      child: async.when(
        loading: () => const _CardLoading(message: '티켓을 불러오는 중...'),
        error: (e, _) => _CardError(
          message: e.toString(),
          onRetry: () => refreshTechTickets(ref),
        ),
        data: (summary) => _TicketBody(summary: summary),
      ),
    );
  }
}

class _TicketBody extends StatelessWidget {
  const _TicketBody({required this.summary});

  final TicketSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BigStat(
          value: '${summary.openCount}',
          unit: '건',
          caption: '처리 대기 중',
          tone: summary.openCount > 0 ? StatusTone.warning : StatusTone.success,
        ),
        const SizedBox(height: AppSpacing.md),
        if (summary.recent.isEmpty)
          _InlineEmpty(
            icon: Icons.check_circle_outline,
            message: '미처리 티켓이 없습니다.',
          )
        else ...[
          Text('최근 티켓', style: AppTypography.labelMd),
          const SizedBox(height: AppSpacing.sm),
          AppDataTable(
            columns: const ['제목', '유형', '상태'],
            columnFlex: const [3, 2, 2],
            rows: [
              for (final t in summary.recent)
                AppTableRow(
                  highlight: t.priority == InquiryPriority.urgent.code,
                  cells: [
                    Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(t.typeEnum.label),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(
                        label: t.statusEnum.label,
                        tone: _ticketStatusTone(t.statusEnum),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: '티켓 전체 보기',
            icon: Icons.arrow_forward,
            variant: AppButtonVariant.tertiary,
            onPressed: () => context.go(TechDashboardPage._issuesRoute),
          ),
        ),
      ],
    );
  }
}

StatusTone _ticketStatusTone(InquiryStatus s) => switch (s) {
      InquiryStatus.open => StatusTone.info,
      InquiryStatus.inProgress => StatusTone.warning,
      InquiryStatus.resolved => StatusTone.success,
      InquiryStatus.closed => StatusTone.neutral,
    };

/// ─────────────────────────────────────────────────────────────────────────
/// Card (2) — 라이선스 현황 (REAL: licenseListProvider)
/// ─────────────────────────────────────────────────────────────────────────
class _LicenseCard extends ConsumerWidget {
  const _LicenseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(techLicenseSummaryProvider);
    return _SectionScaffold(
      icon: Icons.vpn_key_outlined,
      title: '라이선스 현황',
      onTap: () => context.go(TechDashboardPage._licensesRoute),
      child: async.when(
        loading: () => const _CardLoading(message: '라이선스를 불러오는 중...'),
        error: (e, _) => _CardError(
          message: e.toString(),
          onRetry: () => refreshTechLicenses(ref),
        ),
        data: (summary) => _LicenseBody(summary: summary),
      ),
    );
  }
}

class _LicenseBody extends StatelessWidget {
  const _LicenseBody({required this.summary});

  final LicenseSummary summary;

  @override
  Widget build(BuildContext context) {
    final expiring = summary.expiringSoon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _BigStat(
                value: '${summary.total}',
                unit: '개',
                caption: '총 라이선스',
                tone: StatusTone.info,
              ),
            ),
            Expanded(
              child: _BigStat(
                value: '${expiring.length}',
                unit: '개',
                caption: '만료 임박 ($expiringWindowDays일 내)',
                tone: expiring.isEmpty ? StatusTone.success : StatusTone.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (expiring.isEmpty)
          _InlineEmpty(
            icon: Icons.verified_outlined,
            message: '$expiringWindowDays일 내 만료 예정 라이선스가 없습니다.',
          )
        else ...[
          Text('만료 임박', style: AppTypography.labelMd),
          const SizedBox(height: AppSpacing.sm),
          AppDataTable(
            columns: const ['서비스', '만료일', '상태'],
            columnFlex: const [3, 2, 2],
            rows: [
              for (final l in expiring)
                AppTableRow(
                  highlight: true,
                  cells: [
                    Text(
                      l.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(l.expiresAt == null
                        ? '-'
                        : DateFormatter.date(l.expiresAt!)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(
                        label: _expiryLabel(l.expiresAt!),
                        tone: StatusTone.danger,
                        icon: Icons.schedule,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: '라이선스 관리',
            icon: Icons.arrow_forward,
            variant: AppButtonVariant.tertiary,
            onPressed: () => context.go(TechDashboardPage._licensesRoute),
          ),
        ),
      ],
    );
  }

  String _expiryLabel(DateTime expiresAt) {
    final days = expiresAt.difference(DateTime.now()).inDays;
    if (days <= 0) return '곧 만료';
    return 'D-$days';
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Card (3) — 인프라/시스템 지표 (MOCK: no backend endpoint)
/// ─────────────────────────────────────────────────────────────────────────
class _InfraCard extends ConsumerWidget {
  const _InfraCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // MOCK: synchronous demo metrics — no async state to handle.
    final metrics = ref.watch(techInfraMockProvider);
    return _SectionScaffold(
      icon: Icons.dns_outlined,
      title: '인프라 / 시스템 지표',
      // Visual "데모" badge to clearly separate mock data from real metrics.
      trailing: const StatusChip(label: '데모', tone: StatusTone.neutral),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '실시간 모니터링 API 연동 전까지 표시되는 예시 데이터입니다.',
            style: AppTypography.labelSm,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final g in metrics.gauges) ...[
            _GaugeRow(gauge: g),
            const SizedBox(height: AppSpacing.md),
          ],
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  icon: Icons.timer_outlined,
                  label: '가동 시간(Uptime)',
                  value: metrics.uptimeLabel,
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  icon: Icons.layers_outlined,
                  label: '작업 큐(Queue)',
                  value: '${metrics.queueDepth}건 대기',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugeRow extends StatelessWidget {
  const _GaugeRow({required this.gauge});

  final InfraGauge gauge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(gauge.label, style: AppTypography.bodySm)),
            Text(gauge.valueLabel, style: AppTypography.labelMd),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppProgressBar(
          value: gauge.ratio,
          color: gauge.warning ? AppColors.warning : AppColors.primary,
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.outline),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTypography.labelSm),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: AppTypography.labelMd),
          ],
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Card (4) — AI 코파일럿 진입
/// ─────────────────────────────────────────────────────────────────────────
class _AiCopilotCard extends StatelessWidget {
  const _AiCopilotCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go(TechDashboardPage._aiRoute),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('AI 코파일럿', style: AppTypography.headlineSm),
              ),
              const Icon(Icons.arrow_forward, color: AppColors.outline),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '로그 분석, 장애 진단, 운영 문의를 AI 코파일럿에게 바로 물어보세요.',
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'AI 코파일럿 열기',
            icon: Icons.auto_awesome,
            onPressed: () => context.go(TechDashboardPage._aiRoute),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Shared presentation helpers (file-private)
/// ─────────────────────────────────────────────────────────────────────────

/// A titled card whose header is optionally tappable (navigates to the feature
/// screen) with a trailing chevron, then renders [child] below.
class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.outline),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTypography.headlineSm)),
              ?trailing,
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right, color: AppColors.outline),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Big numeric KPI with a unit suffix + caption, tinted by [tone].
class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.value,
    required this.unit,
    required this.caption,
    required this.tone,
  });

  final String value;
  final String unit;
  final String caption;
  final StatusTone tone;

  Color get _color => switch (tone) {
        StatusTone.danger => AppColors.error,
        StatusTone.warning => AppColors.warning,
        StatusTone.success => AppColors.primary,
        StatusTone.info => AppColors.onSurface,
        StatusTone.neutral => AppColors.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppTypography.headlineLg.copyWith(color: _color)),
            const SizedBox(width: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(unit, style: AppTypography.bodySm),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(caption, style: AppTypography.labelSm),
      ],
    );
  }
}

/// Compact loading state sized for inside a card.
class _CardLoading extends StatelessWidget {
  const _CardLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: LoadingView(message: message),
    );
  }
}

/// Compact error state with retry, sized for inside a card.
class _CardError extends StatelessWidget {
  const _CardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ErrorView(message: message, onRetry: onRetry),
    );
  }
}

/// Inline "all clear" / empty hint shown inside a populated card.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
