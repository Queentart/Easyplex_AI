import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/status_chip.dart';
import '_executive_mock_scaffold.dart';

/// Executive · Enterprise governance & cost-control screen (MOCK).
///
/// Reference mockup: `enterprise_governance_cost_control_dashboard`.
///
/// Replaces the `/executive/governance` placeholder. Cloud cost, token usage,
/// budget thresholds, security policies, audit logs and tenant contracts are
/// ALL static demo data — there is no billing / audit / security backend yet.
/// Flagged with the "데모 데이터" banner + `// MOCK:` comments + `_mock` locals.
///
/// TODO(governance-api): wire to `GET /billing/usage`, `PATCH /billing/budget`,
/// `GET /audit-logs`, `GET/PATCH /security/policies` once those exist, then drop
/// the [ExecutiveMockBanner] and the `_mock*` locals.
class GovernanceScreen extends StatelessWidget {
  const GovernanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ExecutiveMockScaffold(
      title: '거버넌스 · 비용 관리',
      subtitle: '클라우드 비용 · 토큰 사용량 · 보안 정책 · 감사 로그를 통합 관리하세요.',
      children: const [
        ExecutiveMockBanner(),
        SizedBox(height: AppSpacing.lg),
        _CostSection(),
        SizedBox(height: AppSpacing.xl),
        _BudgetThresholdSection(),
        SizedBox(height: AppSpacing.xl),
        _SecurityPolicySection(),
        SizedBox(height: AppSpacing.xl),
        _AuditLogSection(),
        SizedBox(height: AppSpacing.xl),
        _ContractSection(),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// MOCK data models + fixtures (demo only — no backing endpoint)
// ───────────────────────────────────────────────────────────────────────────

/// A usage / cost summary tile with an optional utilization bar.
class _MockUsage {
  const _MockUsage({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.ratio,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;

  /// 0.0 – 1.0 quota utilization, if applicable (drives the bar).
  final double? ratio;
}

// MOCK: cloud spend + LLM token usage. Illustrative only.
const List<_MockUsage> _mockUsage = [
  _MockUsage(
    label: '총 클라우드 인프라 비용',
    value: '₩ 5,525,000',
    caption: '전월 대비 +12%',
    icon: Icons.cloud_outlined,
  ),
  _MockUsage(
    label: 'LLM 에이전트 토큰 사용량',
    value: '12.4M 토큰',
    caption: '쿼터의 62% 사용',
    icon: Icons.token_outlined,
    ratio: 0.62,
  ),
];

/// A selectable monthly budget threshold.
class _MockBudgetOption {
  const _MockBudgetOption({required this.label, this.selected = false});

  final String label;
  final bool selected;
}

// MOCK: budget alert thresholds. Selection is illustrative (no-op).
const List<_MockBudgetOption> _mockBudgetOptions = [
  _MockBudgetOption(label: '월 ₩ 6,500,000'),
  _MockBudgetOption(label: '월 ₩ 13,000,000', selected: true),
  _MockBudgetOption(label: '월 ₩ 19,500,000'),
];

/// A toggleable security policy.
class _MockSecurityPolicy {
  const _MockSecurityPolicy({
    required this.title,
    required this.description,
    required this.enabled,
  });

  final String title;
  final String description;
  final bool enabled;
}

// MOCK: security policy switches. State is illustrative (no-op).
const List<_MockSecurityPolicy> _mockSecurityPolicies = [
  _MockSecurityPolicy(
    title: '데이터 격리',
    description: '테넌트 간 엄격한 데이터 격리 활성화',
    enabled: true,
  ),
  _MockSecurityPolicy(
    title: '2단계 인증 (2FA)',
    description: '모든 관리자 계정에 필수 적용',
    enabled: true,
  ),
  _MockSecurityPolicy(
    title: '인트라넷 전용 정책',
    description: '사내 IP 대역으로 접근 제한',
    enabled: false,
  ),
];

/// A security audit-log entry.
class _MockAuditLog {
  const _MockAuditLog({
    required this.icon,
    required this.title,
    required this.detail,
    required this.time,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String time;
  final StatusTone tone;
}

// MOCK: recent security audit events. Illustrative only.
const List<_MockAuditLog> _mockAuditLogs = [
  _MockAuditLog(
    icon: Icons.login_outlined,
    title: '관리자 로그인',
    detail: '192.168.1.45 에서 접속',
    time: '2분 전',
    tone: StatusTone.info,
  ),
  _MockAuditLog(
    icon: Icons.settings_outlined,
    title: '정책 변경',
    detail: '데이터 격리 활성화',
    time: '1시간 전',
    tone: StatusTone.success,
  ),
  _MockAuditLog(
    icon: Icons.warning_amber_outlined,
    title: '로그인 실패 시도',
    detail: '미확인 IP 에서 접속 시도',
    time: '어제 14:30',
    tone: StatusTone.danger,
  ),
];

/// An active tenant contract row.
class _MockContract {
  const _MockContract({
    required this.tenant,
    required this.licenseType,
    required this.activeUsers,
    required this.renewalDate,
    required this.statusLabel,
    required this.statusTone,
  });

  final String tenant;
  final String licenseType;
  final String activeUsers;
  final String renewalDate;
  final String statusLabel;
  final StatusTone statusTone;
}

// MOCK: active tenant contracts. Illustrative only.
const List<_MockContract> _mockContracts = [
  _MockContract(
    tenant: '동아 AI 랩',
    licenseType: 'Enterprise Plus',
    activeUsers: '1,200',
    renewalDate: '2027-03-01',
    statusLabel: '활성',
    statusTone: StatusTone.success,
  ),
  _MockContract(
    tenant: '서울 교육청',
    licenseType: 'Standard',
    activeUsers: '450',
    renewalDate: '2025-11-15',
    statusLabel: '갱신 임박',
    statusTone: StatusTone.warning,
  ),
];

// ───────────────────────────────────────────────────────────────────────────
// Sections
// ───────────────────────────────────────────────────────────────────────────

class _CostSection extends StatelessWidget {
  const _CostSection();

  @override
  Widget build(BuildContext context) {
    return ExecutiveMockCardGrid(
      children: [
        for (final u in _mockUsage) _UsageCard(usage: u),
      ],
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.usage});

  final _MockUsage usage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  usage.label,
                  style: AppTypography.labelSm,
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
                child: Icon(usage.icon, size: 18, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(usage.value, style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            usage.caption,
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          if (usage.ratio != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppProgressBar(
              value: usage.ratio!,
              color: usage.ratio! >= 0.8
                  ? AppColors.error
                  : AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetThresholdSection extends StatelessWidget {
  const _BudgetThresholdSection();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '예산 경고 임계값',
      icon: Icons.account_balance_wallet_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final opt in _mockBudgetOptions) _BudgetChip(option: opt),
        ],
      ),
    );
  }
}

class _BudgetChip extends StatelessWidget {
  const _BudgetChip({required this.option});

  final _MockBudgetOption option;

  @override
  Widget build(BuildContext context) {
    // MOCK: selection is read-only demo state; tapping is a deliberate no-op.
    final selected = option.selected;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primaryContainer
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(
              Icons.check_circle,
              size: 16,
              color: AppColors.onPrimaryContainer,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            option.label,
            style: AppTypography.labelMd.copyWith(
              color: selected
                  ? AppColors.onPrimaryContainer
                  : AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityPolicySection extends StatelessWidget {
  const _SecurityPolicySection();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '보안 정책',
      icon: Icons.shield_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: Column(
        children: [
          for (final p in _mockSecurityPolicies) ...[
            _PolicyRow(policy: p),
            if (p != _mockSecurityPolicies.last) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({required this.policy});

  final _MockSecurityPolicy policy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(policy.title, style: AppTypography.labelMd),
              const SizedBox(height: AppSpacing.xs),
              Text(
                policy.description,
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        // MOCK: switch reflects demo state only; onChanged is a no-op.
        Switch(value: policy.enabled, onChanged: (_) {}),
      ],
    );
  }
}

class _AuditLogSection extends StatelessWidget {
  const _AuditLogSection();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '최근 보안 감사 로그',
      icon: Icons.history_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: AppDataTable(
        columns: const ['이벤트', '상세', '시각'],
        columnFlex: const [2, 3, 2],
        rows: [
          for (final log in _mockAuditLogs)
            AppTableRow(
              highlight: log.tone == StatusTone.danger,
              cells: [
                Row(
                  children: [
                    Icon(log.icon, size: 16, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        log.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(log.detail),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(label: log.time, tone: log.tone),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ContractSection extends StatelessWidget {
  const _ContractSection();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: '활성 테넌트 계약',
      icon: Icons.description_outlined,
      trailing: const StatusChip(label: '데모', tone: StatusTone.warning),
      dividerUnderTitle: true,
      child: AppDataTable(
        columns: const ['테넌트', '라이선스', '활성 사용자', '갱신일', '상태'],
        columnFlex: const [3, 2, 2, 2, 2],
        rows: [
          for (final c in _mockContracts)
            AppTableRow(
              cells: [
                Text(c.tenant),
                Text(c.licenseType),
                Text(c.activeUsers),
                Text(c.renewalDate),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(label: c.statusLabel, tone: c.statusTone),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
