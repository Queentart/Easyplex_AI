import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Thin rounded progress bar (e.g. "85% Submitted").
///
/// Mirrors the mockup `bg-surface-container-high rounded-full h-2.5` track with
/// a teal fill.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.color,
  }) : assert(value >= 0 && value <= 1);

  /// 0.0 – 1.0
  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Stack(
        children: [
          Container(height: height, color: AppColors.surfaceContainerHigh),
          FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: color ?? AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular percentage ring used on attendance dashboards.
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 10,
    this.label,
    this.color,
  }) : assert(value >= 0 && value <= 1);

  final double value;
  final double size;
  final double strokeWidth;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: strokeWidth,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}%',
                style: theme.textTheme.headlineSmall,
              ),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(label!, style: theme.textTheme.labelSmall),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
