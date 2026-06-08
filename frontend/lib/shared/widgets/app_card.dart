import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

/// White surface container with soft ambient shadow and large radius.
///
/// Mirrors the mockup `.bg-white .rounded-xl .p-lg .card-shadow` pattern.
/// Set [hero] for the airier `xl` (40px) padding used on hero sections.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.hero = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool hero;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    final resolvedPadding = padding ??
        EdgeInsets.all(hero ? AppSpacing.xl : AppSpacing.lg);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: resolvedPadding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: radius,
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        hoverColor: AppColors.paleSand,
        child: card,
      ),
    );
  }
}

/// A titled card: optional leading icon + title row, then [child].
class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.dividerUnderTitle = false,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final bool dividerUnderTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.outline),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(title, style: theme.textTheme.headlineSmall),
              ),
              ?trailing,
            ],
          ),
          if (dividerUnderTitle) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
