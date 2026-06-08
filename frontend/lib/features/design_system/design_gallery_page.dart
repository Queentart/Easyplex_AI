import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_data_table.dart';
import '../../shared/widgets/app_progress_bar.dart';
import '../../shared/widgets/chat_bubble.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/status_chip.dart';

/// Living style guide for the platform's design system.
///
/// Run this to visually lock the design direction before building features.
class DesignGalleryPage extends StatelessWidget {
  const DesignGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('디자인 시스템'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.lg),
            child: Center(child: Text('DongA AI Lab — Stitch')),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.containerMargin),
            children: const [
              _Section(title: '01 · Color Tokens', child: _ColorSwatches()),
              _Section(title: '02 · Typography', child: _TypeScale()),
              _Section(title: '03 · Buttons', child: _Buttons()),
              _Section(title: '04 · Status Chips', child: _Chips()),
              _Section(title: '05 · Cards & KPIs', child: _Cards()),
              _Section(title: '06 · Progress', child: _Progress()),
              _Section(title: '07 · Data Table', child: _TableDemo()),
              _Section(title: '08 · Inputs & Toggle', child: _Inputs()),
              _Section(title: '09 · AI Chat Bubbles', child: _Chat()),
              SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

// ── 01 Colors ───────────────────────────────────────────────────────────────
class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches();

  static const _entries = <(String, Color, Color)>[
    ('primary', AppColors.primary, AppColors.onPrimary),
    ('primary\ncontainer', AppColors.primaryContainer, AppColors.onPrimaryContainer),
    ('secondary\ncontainer\n(taupe)', AppColors.secondaryContainer, AppColors.onSecondaryContainer),
    ('tertiary\ncontainer', AppColors.tertiaryContainer, AppColors.onTertiaryContainer),
    ('surface', AppColors.surface, AppColors.onSurface),
    ('surface\ncontainer', AppColors.surfaceContainer, AppColors.onSurface),
    ('surface\ncontainer\nhigh', AppColors.surfaceContainerHigh, AppColors.onSurface),
    ('pale sand', AppColors.paleSand, AppColors.onSurface),
    ('error', AppColors.error, AppColors.onError),
    ('error\ncontainer', AppColors.errorContainer, AppColors.onErrorContainer),
    ('outline', AppColors.outline, Colors.white),
    ('on-surface', AppColors.onSurface, Colors.white),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final (name, bg, fg) in _entries)
          Container(
            width: 130,
            height: 96,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                name,
                style: AppTypography.labelSm.copyWith(color: fg),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 02 Typography ─────────────────────────────────────────────────────────
class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Display LG · 48', style: AppTypography.displayLg),
          const SizedBox(height: AppSpacing.sm),
          Text('Headline LG · 32', style: AppTypography.headlineLg),
          const SizedBox(height: AppSpacing.sm),
          Text('Headline MD · 24', style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.sm),
          Text('Headline SM · 18', style: AppTypography.headlineSm),
          const SizedBox(height: AppSpacing.sm),
          Text('Body LG · 18 — 강의 운영 플랫폼', style: AppTypography.bodyLg),
          Text('Body MD · 16 — 출결 현황 요약', style: AppTypography.bodyMd),
          Text('Body SM · 14 — 보조 설명 텍스트', style: AppTypography.bodySm),
          const SizedBox(height: AppSpacing.sm),
          Text('LABEL MD · 14', style: AppTypography.labelMd),
          Text('LABEL SM · 12', style: AppTypography.labelSm),
        ],
      ),
    );
  }
}

// ── 03 Buttons ──────────────────────────────────────────────────────────────
class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(label: 'Broadcast Notice', icon: Icons.send, onPressed: () {}),
        AppButton(
          label: 'Upload CSV',
          icon: Icons.upload_file,
          variant: AppButtonVariant.secondary,
          onPressed: () {},
        ),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.tertiary,
          onPressed: () {},
        ),
        const AppButton(label: 'Disabled'),
        const AppButton(label: 'Loading', loading: true),
      ],
    );
  }
}

// ── 04 Chips ────────────────────────────────────────────────────────────────
class _Chips extends StatelessWidget {
  const _Chips();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        StatusChip(label: 'Normal'),
        StatusChip(label: '정상', tone: StatusTone.success, icon: Icons.check),
        StatusChip(label: 'At Risk', tone: StatusTone.warning, icon: Icons.warning_amber),
        StatusChip(label: 'Needs Review', tone: StatusTone.danger, icon: Icons.error_outline),
        StatusChip(label: 'Active', tone: StatusTone.info),
      ],
    );
  }
}

// ── 05 Cards ──────────────────────────────────────────────────────────────
class _Cards extends StatelessWidget {
  const _Cards();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: StatCard(
                label: 'TOTAL STUDENTS',
                value: '45',
                icon: Icons.groups,
                delta: '+3 this week',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: StatCard(
                label: 'AVG ATTENDANCE',
                value: '92%',
                icon: Icons.fact_check,
                delta: '-1.2%',
                deltaPositive: false,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppSectionCard(
                title: 'Counseling Schedule',
                icon: Icons.groups,
                dividerUnderTitle: true,
                child: Text(
                  '14:00 · Kim Min-su\n15:30 · Lee Ji-eun',
                  style: AppTypography.bodySm,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 06 Progress ─────────────────────────────────────────────────────────────
class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const AppProgressRing(value: 0.92, label: '출석률'),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Assignment Status",
                    style: AppTypography.headlineSm),
                const SizedBox(height: AppSpacing.sm),
                const AppProgressBar(value: 0.85),
                const SizedBox(height: AppSpacing.xs),
                Text('85% Submitted', style: AppTypography.labelMd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 07 Table ──────────────────────────────────────────────────────────────
class _TableDemo extends StatelessWidget {
  const _TableDemo();

  @override
  Widget build(BuildContext context) {
    Widget cell(String s, {Color? color, FontWeight? weight}) => Text(
          s,
          style: AppTypography.bodySm
              .copyWith(color: color, fontWeight: weight),
        );

    return AppDataTable(
      columns: const ['Student', 'Retention', 'Employment', 'Status'],
      columnFlex: const [3, 2, 2, 2],
      rows: [
        AppTableRow(cells: [
          cell('Park Sang-wook', weight: FontWeight.w500),
          cell('Active'),
          cell('88%'),
          const Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(label: 'Normal'),
          ),
        ]),
        AppTableRow(
          highlight: true,
          cells: [
            cell('Choi Yu-jin', color: AppColors.error, weight: FontWeight.w600),
            cell('At Risk'),
            cell('45%', color: AppColors.error, weight: FontWeight.w600),
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(label: 'Needs Review', tone: StatusTone.danger),
            ),
          ],
        ),
        AppTableRow(cells: [
          cell('Kim Do-yun', weight: FontWeight.w500),
          cell('Active'),
          cell('92%'),
          const Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(label: 'Normal'),
          ),
        ]),
      ],
    );
  }
}

// ── 08 Inputs ─────────────────────────────────────────────────────────────
class _Inputs extends StatefulWidget {
  const _Inputs();

  @override
  State<_Inputs> createState() => _InputsState();
}

class _InputsState extends State<_Inputs> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TextField(
            decoration: InputDecoration(
              labelText: '이메일',
              hintText: 'admin@dongaai.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const TextField(
            decoration: InputDecoration(
              labelText: '비밀번호',
              hintText: '••••••••',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Switch(value: _on, onChanged: (v) => setState(() => _on = v)),
              const SizedBox(width: AppSpacing.sm),
              Text('Live Status', style: AppTypography.labelMd),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 09 Chat ─────────────────────────────────────────────────────────────────
class _Chat extends StatelessWidget {
  const _Chat();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          ChatBubble.text(
            'Summarize students with 3+ absences this month.',
            isUser: true,
          ),
          const SizedBox(height: AppSpacing.md),
          ChatBubble(
            isUser: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('I found 2 students meeting that criteria:',
                    style: AppTypography.bodySm
                        .copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: AppSpacing.xs),
                Text('• Choi Yu-jin (4 absences)\n• Jeong Min-jae (3 absences)',
                    style: AppTypography.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
