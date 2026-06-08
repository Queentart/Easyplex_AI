import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../screens/inquiry_form_screen.dart';

/// Floating tech-support entry point, designed to be dropped into the app shell
/// as a global overlay (e.g. inside a [Stack] in `app_shell.dart`).
///
/// It renders a FAB-style button anchored bottom-right that opens the
/// inquiry-create form as a modal. Submitting the form shows its own
/// confirmation SnackBar and pops back to the current screen — no routing
/// change is required, so it works on every page regardless of the active
/// route.
///
/// Usage (orchestrator, in the shell build):
/// ```dart
/// Stack(
///   children: [
///     shellContent,
///     const TechSupportWidget(),
///   ],
/// )
/// ```
class TechSupportWidget extends ConsumerWidget {
  const TechSupportWidget({super.key, this.bottom, this.right});

  /// Optional overrides for the anchor inset (defaults to [AppSpacing.lg]).
  final double? bottom;
  final double? right;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The tech-support team are the people who ANSWER inquiries — they don't
    // need a "contact tech support" button. Hide it for them.
    final role = ref.watch(authStateProvider).role;
    if (role == AppRoles.techSupport) return const SizedBox.shrink();

    return Positioned(
      right: right ?? AppSpacing.lg,
      bottom: bottom ?? AppSpacing.lg,
      child: _TechSupportFab(
        onPressed: () => _openInquiryForm(context),
      ),
    );
  }

  Future<void> _openInquiryForm(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.9;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            // No basePath → the form just pops on success (works on any route).
            child: const InquiryFormScreen(),
          ),
        );
      },
    );
  }
}

class _TechSupportFab extends StatelessWidget {
  const _TechSupportFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.full),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: AppShadows.overlay,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.support_agent_rounded,
                  color: AppColors.onPrimary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '기술지원',
                style: AppTypography.labelMd
                    .copyWith(color: AppColors.onPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
