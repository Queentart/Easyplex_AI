import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Semantic tone for [StatusChip].
enum StatusTone { neutral, success, warning, danger, info }

/// Small pill/label used in tables and cards (e.g. "Normal", "Needs Review").
///
/// Mirrors the mockup `inline-block px-2 py-1 rounded` status labels, including
/// the error-container variant for at-risk rows.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  ({Color bg, Color fg}) get _colors => switch (tone) {
        StatusTone.neutral => (
            bg: AppColors.surfaceContainerHigh,
            fg: AppColors.onSurface,
          ),
        StatusTone.success => (
            bg: AppColors.primaryContainer,
            fg: AppColors.onPrimaryContainer,
          ),
        StatusTone.warning => (
            bg: AppColors.warningContainer,
            fg: AppColors.onWarningContainer,
          ),
        StatusTone.danger => (
            bg: AppColors.errorContainer,
            fg: AppColors.onErrorContainer,
          ),
        StatusTone.info => (
            bg: AppColors.surfaceContainerHighest,
            fg: AppColors.onSurfaceVariant,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c.fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: c.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
