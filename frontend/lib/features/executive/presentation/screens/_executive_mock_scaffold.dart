import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/responsive_layout.dart';

/// Shared page chrome for the executive MOCK analytics screens.
///
/// Lives under `lib/features/executive/` (file ownership): it intentionally
/// duplicates the small layout helpers from `executive_dashboard_page.dart`
/// rather than editing shared widgets or the existing home. Each screen renders
/// content only — the authenticated `ShellRoute` supplies the top bar + side
/// navigation.
class ExecutiveMockScaffold extends StatelessWidget {
  const ExecutiveMockScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.containerMargin),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(title: title, subtitle: subtitle),
                  const SizedBox(height: AppSpacing.lg),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.headlineLg),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Visible "데모 데이터" banner shown at the top of every executive mock screen.
///
/// Makes the mock origin unmistakable to reviewers and marks the seam where a
/// future `/analytics/*` integration would remove it.
class ExecutiveMockBanner extends StatelessWidget {
  const ExecutiveMockBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.science_outlined,
            size: 18,
            color: AppColors.onWarningContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.bodySm
                    .copyWith(color: AppColors.onWarningContainer),
                children: const [
                  TextSpan(
                    text: '데모 데이터  ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: '집계 API 연동 전 예시 데이터입니다.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays cards in a column on mobile and an even row on tablet/desktop
/// (executive screens are PC-first). Mirrors the helper in the executive home.
class ExecutiveMockCardGrid extends StatelessWidget {
  const ExecutiveMockCardGrid({super.key, required this.children});

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
      tablet: (_) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i != children.length - 1)
              const SizedBox(width: AppSpacing.gutter),
          ],
        ],
      ),
    );
  }
}
