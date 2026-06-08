import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_card.dart';

/// Shared placeholder body for role dashboards before their feature phase
/// builds the real screen. Renders a heading + helper text inside an
/// [AppCard], using only design-system tokens.
///
/// TODO: implement feature — each role dashboard is replaced by its feature
/// phase (see memo/0529 execution order guide).
class PlaceholderDashboard extends StatelessWidget {
  const PlaceholderDashboard({
    super.key,
    required this.heading,
    required this.description,
    required this.icon,
  });

  final String heading;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: AppTypography.headlineLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Row(
              children: [
                Icon(icon, size: 32, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('준비 중', style: AppTypography.headlineSm),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '이 화면은 곧 제공됩니다.',
                        style: AppTypography.bodySm
                            .copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
