import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../widgets/mock_demo_banner.dart';

/// Operations · 운영 · 시스템 설정 (MOCK-ONLY).
///
/// Faithful to the `operations_system_settings_dashboard` /
/// `system_configuration_settings_dashboard` Stitch mockups: API & data
/// integration toggles, AI-engine / chatbot preferences, and monitoring &
/// alert-routing thresholds.
///
/// ── DATA SOURCE ────────────────────────────────────────────────────────────
/// EVERY control is LOCAL-ONLY. There is no `/integrations`, `/ai/config`,
/// `/alerts/settings` or `/chatbot/settings` endpoint yet, so "저장" only shows
/// a SnackBar and mutates in-memory `_mock*` state — nothing is persisted. See
/// the repository seam at the bottom of this file. A visible "데모 데이터" banner
/// flags the mock state.
class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  static const String routePath = '/ops/settings';

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  // MOCK: local-only setting state (no persistence / no save endpoint).
  bool _mockAutoSync = true;
  String _mockSyncFrequency = '매시간';
  bool _mockPushNotifications = true;
  String _mockAttendanceTrigger = '지각 3회 후 알림';
  int _mockDistractionMins = 5;
  bool _mockAutoReply = true;
  String _mockAiConfidence = '높음 (90%+)';
  bool _mockSaving = false;

  Future<void> _onSave() async {
    if (_mockSaving) return; // prevent duplicate submission
    setState(() => _mockSaving = true);
    // MOCK: no save endpoint — simulate a brief round-trip for UX feedback.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _mockSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('데모 모드입니다. 설정은 저장되지 않습니다 (API 연동 전).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _integrationsCard(),
      _monitoringCard(),
      _chatbotCard(),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.md),
          const MockDemoBanner(
            caption: '설정 저장 API 연동 전입니다. 변경 사항은 저장되지 않는 예시 데이터입니다.',
          ),
          const SizedBox(height: AppSpacing.lg),
          ResponsiveLayout(
            mobile: (_) => Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i != 0) const SizedBox(height: AppSpacing.lg),
                  cards[i],
                ],
              ],
            ),
            tablet: (_) => _TwoColumn(children: cards),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('운영 · 시스템 설정', style: AppTypography.headlineMd),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '통합 연동, 모니터링 임계값, AI 환경을 관리합니다.',
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppButton(
          label: '설정 저장',
          icon: Icons.save_outlined,
          loading: _mockSaving,
          onPressed: _onSave,
        ),
      ],
    );
  }

  // ── Card 1: API & Data integrations ────────────────────────────────────────
  Widget _integrationsCard() {
    return _SettingsSection(
      title: 'API · 데이터 연동',
      icon: Icons.api_outlined,
      children: [
        _ToggleRow(
          title: '고용24 포털 자동 동기화',
          subtitle: '수강생 데이터를 자동으로 가져옵니다.',
          value: _mockAutoSync,
          onChanged: (v) => setState(() => _mockAutoSync = v),
        ),
        _DropdownRow(
          label: '동기화 주기',
          value: _mockSyncFrequency,
          options: const ['매시간', '매일 자정', '매주'],
          onChanged: (v) => setState(() => _mockSyncFrequency = v),
        ),
        const _ReadonlyField(
          label: 'Zoom API 액세스 키',
          // MOCK: masked demo secret; not a real credential.
          value: '••••••••••••••••••••',
          icon: Icons.visibility_off_outlined,
        ),
      ],
    );
  }

  // ── Card 2: Monitoring & alert routing ─────────────────────────────────────
  Widget _monitoringCard() {
    return _SettingsSection(
      title: '모니터링 · 알림 라우팅',
      icon: Icons.monitor_heart_outlined,
      children: [
        _StepperRow(
          label: '딴짓 감지 알림 임계값',
          subtitle: '연속 비활동 분 수가 이 값을 넘으면 알림을 보냅니다.',
          value: _mockDistractionMins,
          unit: '분',
          onChanged: (v) => setState(() => _mockDistractionMins = v),
        ),
        _DropdownRow(
          label: '출결 경고 트리거',
          value: _mockAttendanceTrigger,
          options: const ['지각 3회 후 알림', '지각 5회 후 알림', '엄격 (지각 1회)'],
          onChanged: (v) => setState(() => _mockAttendanceTrigger = v),
        ),
        _ToggleRow(
          title: '푸시 알림',
          subtitle: '강사 기기로 알림을 직접 전송합니다.',
          value: _mockPushNotifications,
          onChanged: (v) => setState(() => _mockPushNotifications = v),
        ),
      ],
    );
  }

  // ── Card 3: AI / chatbot preferences ───────────────────────────────────────
  Widget _chatbotCard() {
    return _SettingsSection(
      title: 'AI 챗봇 · 엔진 설정',
      icon: Icons.forum_outlined,
      children: [
        _ToggleRow(
          title: '관리자 FAQ 자동 응답',
          subtitle: '반복 문의를 AI가 처리하도록 허용합니다.',
          value: _mockAutoReply,
          onChanged: (v) => setState(() => _mockAutoReply = v),
        ),
        _DropdownRow(
          label: 'AI 자동 응답 신뢰도 임계값',
          value: _mockAiConfidence,
          options: const ['높음 (90%+)', '보통 (75%+)', '낮음 (50%+)'],
          onChanged: (v) => setState(() => _mockAiConfidence = v),
        ),
      ],
    );
  }
}

/// Two-column masonry-ish layout for the settings cards on wide viewports.
class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      (i.isEven ? left : right).add(children[i]);
    }

    Widget column(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i != 0) const SizedBox(height: AppSpacing.lg),
              items[i],
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

/// ───────────────────────────────────────────────────────────────────────────
/// Building blocks
/// ───────────────────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: title,
      icon: icon,
      dividerUnderTitle: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i != 0) const SizedBox(height: AppSpacing.lg),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelMd),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMd),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: [
            for (final o in options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMd),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style:
              AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            IconButton.outlined(
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('$value$unit', style: AppTypography.bodyMd),
            ),
            IconButton.outlined(
              onPressed: value < 60 ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMd),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AppTypography.bodyMd
                      .copyWith(letterSpacing: 2, fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: AppColors.outline),
            ],
          ),
        ),
      ],
    );
  }
}

// ── REPOSITORY SEAM ──────────────────────────────────────────────────────────
// TODO(backend): replace the `_mock*` state + the no-op `_onSave()` with a real
// settings repository once config endpoints exist, e.g.:
//
//   final repo = SystemSettingsRepository(dio);
//   final cfg  = await repo.getConfig();          // GET /integrations, /ai/config, ...
//   await repo.saveConfig(cfg.copyWith(...));      // PATCH /integrations, /alerts/settings
//
// Hoist the form fields into a Riverpod form Notifier (isSubmitting / isSuccess
// / error) following the LeaveRequestForm pattern in the flutter-feature skill,
// and surface 403 / 422 errors via ApiErrorMessages.
