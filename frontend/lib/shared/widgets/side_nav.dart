import 'package:flutter/material.dart';

import '../../core/app_labels.dart';
import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A single navigation destination.
class NavItem {
  const NavItem({required this.label, required this.icon, required this.route});

  final String label;
  final IconData icon;
  final String route;
}

/// Role → navigation items. Items vary per role; the first item is the role's
/// home. Routes beyond the dashboards are placeholders the feature phases fill.
List<NavItem> navItemsForRole(String? role) {
  switch (role) {
    case AppRoles.student:
      return const [
        NavItem(label: AppLabels.dashboard, icon: Icons.dashboard_outlined, route: AppRoutes.student),
        NavItem(label: AppLabels.notices, icon: Icons.campaign_outlined, route: '${AppRoutes.student}/notices'),
        NavItem(label: AppLabels.studentCourses, icon: Icons.play_circle_outline, route: '${AppRoutes.student}/courses'),
        NavItem(label: AppLabels.attendance, icon: Icons.fact_check_outlined, route: '${AppRoutes.student}/attendance'),
        NavItem(label: AppLabels.assignments, icon: Icons.assignment_outlined, route: '${AppRoutes.student}/assignments'),
        NavItem(label: AppLabels.leaveRequests, icon: Icons.event_busy_outlined, route: '${AppRoutes.student}/leave-requests'),
        NavItem(label: AppLabels.community, icon: Icons.forum_outlined, route: '${AppRoutes.student}/community'),
        NavItem(label: AppLabels.chat, icon: Icons.chat_bubble_outline, route: '/chat'),
        NavItem(label: AppLabels.counseling, icon: Icons.psychology_outlined, route: '${AppRoutes.student}/counseling'),
        NavItem(label: AppLabels.myInquiries, icon: Icons.inbox_outlined, route: '${AppRoutes.student}/inquiries'),
        NavItem(label: AppLabels.support, icon: Icons.support_agent_outlined, route: '${AppRoutes.student}/support'),
      ];
    case AppRoles.instructor:
      return const [
        NavItem(label: AppLabels.dashboard, icon: Icons.dashboard_outlined, route: AppRoutes.instructor),
        NavItem(label: AppLabels.courses, icon: Icons.video_library_outlined, route: '${AppRoutes.instructor}/courses'),
        NavItem(label: AppLabels.attendanceManagement, icon: Icons.fact_check_outlined, route: '${AppRoutes.instructor}/attendance'),
        NavItem(label: AppLabels.leaveApproval, icon: Icons.fact_check_outlined, route: '${AppRoutes.instructor}/leave-approvals'),
        NavItem(label: AppLabels.assignmentGrading, icon: Icons.grading_outlined, route: '${AppRoutes.instructor}/assignments'),
        NavItem(label: AppLabels.community, icon: Icons.forum_outlined, route: '${AppRoutes.instructor}/community'),
        NavItem(label: AppLabels.communityManagement, icon: Icons.dashboard_customize_outlined, route: '${AppRoutes.instructor}/boards'),
        NavItem(label: AppLabels.counseling, icon: Icons.psychology_outlined, route: '${AppRoutes.instructor}/counseling'),
        NavItem(label: AppLabels.chat, icon: Icons.chat_bubble_outline, route: '/chat'),
        NavItem(label: AppLabels.aiCopilot, icon: Icons.auto_awesome_outlined, route: '${AppRoutes.instructor}/ai'),
        NavItem(label: AppLabels.support, icon: Icons.support_agent_outlined, route: '${AppRoutes.instructor}/support'),
      ];
    case AppRoles.adminOps:
      return const [
        NavItem(label: AppLabels.opsStatus, icon: Icons.monitor_heart_outlined, route: AppRoutes.ops),
        NavItem(label: AppLabels.attendanceManagement, icon: Icons.fact_check_outlined, route: '${AppRoutes.ops}/attendance'),
        NavItem(label: AppLabels.userManagement, icon: Icons.group_outlined, route: '${AppRoutes.ops}/users'),
        NavItem(label: AppLabels.cohortManagement, icon: Icons.workspaces_outlined, route: '${AppRoutes.ops}/cohorts'),
        NavItem(label: AppLabels.leaveApproval, icon: Icons.event_available_outlined, route: '${AppRoutes.ops}/leave-requests'),
        NavItem(label: AppLabels.community, icon: Icons.forum_outlined, route: '${AppRoutes.ops}/community'),
        NavItem(label: AppLabels.communityManagement, icon: Icons.dashboard_customize_outlined, route: '${AppRoutes.ops}/boards'),
        NavItem(label: AppLabels.inquiries, icon: Icons.confirmation_number_outlined, route: '${AppRoutes.ops}/issues'),
        NavItem(label: AppLabels.chat, icon: Icons.chat_bubble_outline, route: '/chat'),
        NavItem(label: AppLabels.aiCopilot, icon: Icons.auto_awesome_outlined, route: '${AppRoutes.ops}/ai'),
        NavItem(label: AppLabels.support, icon: Icons.support_agent_outlined, route: '${AppRoutes.ops}/support'),
      ];
    case AppRoles.techSupport:
      return const [
        NavItem(label: AppLabels.infra, icon: Icons.dns_outlined, route: AppRoutes.tech),
        NavItem(label: AppLabels.ticket, icon: Icons.confirmation_number_outlined, route: '${AppRoutes.tech}/issues'),
        NavItem(label: AppLabels.licenses, icon: Icons.vpn_key_outlined, route: '${AppRoutes.tech}/licenses'),
        NavItem(label: AppLabels.aiCopilot, icon: Icons.auto_awesome_outlined, route: '${AppRoutes.tech}/ai'),
        NavItem(label: AppLabels.support, icon: Icons.support_agent_outlined, route: '${AppRoutes.tech}/support'),
      ];
    case AppRoles.executive:
      return const [
        NavItem(label: AppLabels.execDashboard, icon: Icons.insights_outlined, route: AppRoutes.executive),
        NavItem(label: AppLabels.kpiRoi, icon: Icons.trending_up_outlined, route: '${AppRoutes.executive}/kpis'),
        NavItem(label: AppLabels.governance, icon: Icons.gavel_outlined, route: '${AppRoutes.executive}/governance'),
        NavItem(label: AppLabels.analytics, icon: Icons.analytics_outlined, route: '${AppRoutes.executive}/analytics'),
      ];
    default:
      return const [];
  }
}

/// Fixed left sidebar for desktop / tablet, and drawer body on mobile.
///
/// Matches the mockup: surfaceContainerLow background with a right border in
/// outlineVariant; the active item uses a tertiaryContainer pill with
/// onTertiaryContainer foreground.
class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.items,
    required this.currentRoute,
    required this.onSelect,
    this.width = 264,
    this.header,
  });

  final List<NavItem> items;
  final String currentRoute;
  final ValueChanged<NavItem> onSelect;
  final double width;
  final Widget? header;

  bool _isActive(NavItem item) {
    if (currentRoute == item.route) return true;
    // Highlight the home item only on an exact match; sub-routes highlight their
    // own item via prefix.
    return currentRoute.startsWith('${item.route}/');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              children: [
                for (final item in items)
                  _NavTile(
                    item: item,
                    active: _isActive(item),
                    onTap: () => onSelect(item),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.onTertiaryContainer : AppColors.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: active ? AppColors.tertiaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: fg),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.labelMd.copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
