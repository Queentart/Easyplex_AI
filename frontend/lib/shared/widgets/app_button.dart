import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, tertiary }

/// Brand button with the three mockup variants and an optional leading icon.
///
///  - [AppButtonVariant.primary]   : teal fill, white text
///  - [AppButtonVariant.secondary] : teal outline, teal text
///  - [AppButtonVariant.tertiary]  : ghost, taupe hover
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  /// When `true`, the button drops the default 48px *padded* tap target
  /// ([MaterialTapTargetSize.padded]) in favour of
  /// [MaterialTapTargetSize.shrinkWrap] and lets its visible filled box
  /// grow to fill the height it is given (via `minimumSize.height = infinity`).
  ///
  /// Use this when the button is placed in a tightly height-constrained slot
  /// (e.g. a `SizedBox(height: 48)` row with `CrossAxisAlignment.stretch`) and
  /// you need its painted background to span the *full* slot height so it lines
  /// up exactly with a sibling such as a `TextField`. Default `false` keeps the
  /// stock Material behaviour for every existing caller.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = loading ? null : onPressed;

    // When dense, drop the 48px *padded* tap target. With the default
    // [MaterialTapTargetSize.padded], `_RenderInputPadding` reserves a 48px tap
    // slot and paints the coloured [Material] at its ~40px preferred height,
    // *centred* in that slot — so the visible fill is 8px shorter than a
    // sibling 48px search field. Switching to [shrinkWrap] removes that padding
    // and centring, then a concrete [minimumSize] height of 48 forces the
    // coloured fill itself to reach 48 (a `double.infinity` minimum is
    // unsatisfiable and is silently clamped away, which is why the previous
    // attempt only worked when a tight parent constraint happened to drag the
    // fill up — it did nothing on its own).
    const double denseHeight = 48;
    final ButtonStyle? denseStyle = dense
        ? ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: WidgetStateProperty.all(
              const Size(0, denseHeight),
            ),
          )
        : null;

    final child = loading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label),
            ],
          );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: effectiveOnPressed,
          style: denseStyle,
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: denseStyle,
          child: child,
        ),
      AppButtonVariant.tertiary => TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
          ).copyWith(
            overlayColor: WidgetStateProperty.all(AppColors.secondaryContainer),
          ).merge(denseStyle),
          child: child,
        ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
