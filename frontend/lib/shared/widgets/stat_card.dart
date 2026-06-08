import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_card.dart';

/// Compact KPI tile: label, big value, optional icon and delta.
///
/// Used across the operations / executive dashboards.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.delta,
    this.deltaPositive = true,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? delta;
  final bool deltaPositive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: theme.textTheme.displayMedium),
          if (delta != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  deltaPositive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: deltaPositive ? AppColors.primary : AppColors.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  delta!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: deltaPositive ? AppColors.primary : AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
