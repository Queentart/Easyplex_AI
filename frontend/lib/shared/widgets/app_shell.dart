import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'cohort_selector.dart';
import 'responsive_layout.dart';
import 'side_nav.dart';
import 'top_bar.dart';

/// The application shell that wraps every authenticated role area.
///
///   - Desktop / tablet : fixed left [SideNav] + [TopBar] + scrollable content.
///   - Mobile           : [TopBar] with a menu button + drawer holding the nav.
///
/// Nav items are derived from the current user's role. The shell drives
/// navigation via go_router.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.title,
  });

  /// The routed page content.
  final Widget child;

  /// Title rendered in the top bar.
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authStateProvider).role;
    final items = navItemsForRole(role);
    final currentRoute =
        GoRouterState.of(context).uri.toString();

    void go(NavItem item) {
      if (item.route != currentRoute) {
        context.go(item.route);
      }
    }

    // Instructor / operations get a global cohort dropdown (1st-level filter)
    // directly under the brand header.
    final showCohortSelector =
        role == AppRoles.instructor || role == AppRoles.adminOps;
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandHeader(roleLabel: _roleLabel(role)),
        if (showCohortSelector) const CohortSelector(),
      ],
    );
    final mobileScaffoldKey = GlobalKey<ScaffoldState>();

    return ResponsiveLayout(
      mobile: (context) => Scaffold(
        key: mobileScaffoldKey,
        backgroundColor: AppColors.surface,
        appBar: TopBar(
          title: title,
          onMenu: () => mobileScaffoldKey.currentState?.openDrawer(),
        ),
        drawer: Drawer(
          backgroundColor: AppColors.surfaceContainerLow,
          child: SafeArea(
            child: SideNav(
              items: items,
              currentRoute: currentRoute,
              header: header,
              onSelect: (item) {
                Navigator.of(context).pop(); // close drawer
                go(item);
              },
            ),
          ),
        ),
        body: child,
      ),
      desktop: (context) => Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          children: [
            SideNav(
              items: items,
              currentRoute: currentRoute,
              header: header,
              onSelect: go,
            ),
            Expanded(
              child: Column(
                children: [
                  TopBar(title: title),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(String? role) {
    switch (role) {
      case 'student':
        return '수강생';
      case 'instructor':
        return '강사';
      case 'admin_ops':
        return '운영팀';
      case 'tech_support':
        return '기술지원';
      case 'executive':
        return '경영진';
      default:
        return '';
    }
  }
}

/// Sidebar header: product name + current role.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.roleLabel});

  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DongA AI Lab', style: AppTypography.headlineSm),
          if (roleLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              roleLabel,
              style: AppTypography.labelSm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
