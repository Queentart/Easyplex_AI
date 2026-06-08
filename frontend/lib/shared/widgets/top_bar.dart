import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/notification/presentation/notification_provider.dart';

/// Top bar used by the app shell.
///
/// Background is [AppColors.surface] with a bottom border in outlineVariant.
/// On mobile a menu button toggles the drawer.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({
    super.key,
    required this.title,
    this.onMenu,
    this.actions = const [],
  });

  final String title;

  /// When non-null a leading menu (drawer) button is shown — mobile layout.
  final VoidCallback? onMenu;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          if (onMenu != null) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              color: AppColors.onSurface,
              onPressed: onMenu,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTypography.headlineSm,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const _NotificationBell(),
          const _AccountMenu(),
          ...actions,
        ],
      ),
    );
  }
}

/// Account menu: shows the signed-in user and a logout action.
/// Logout clears auth state; the router redirect then sends the user to /login.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return PopupMenuButton<String>(
      tooltip: '계정',
      icon: const Icon(Icons.account_circle_outlined),
      color: AppColors.surfaceContainerLowest,
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        if (value == 'settings') {
          context.go('/settings');
        } else if (value == 'logout') {
          await ref.read(authStateProvider.notifier).logout();
        }
      },
      itemBuilder: (context) => [
        if (user != null)
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.name, style: AppTypography.labelMd),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        if (user != null) const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18,
                  color: AppColors.onSurfaceVariant),
              SizedBox(width: AppSpacing.sm),
              Text('설정'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
              SizedBox(width: AppSpacing.sm),
              Text('로그아웃'),
            ],
          ),
        ),
      ],
    );
  }
}

/// AppBar bell with an unread badge, bound to [unreadNotificationCountProvider].
/// Tapping navigates to the notifications screen.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: '알림',
      color: AppColors.onSurfaceVariant,
      onPressed: () => context.go('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        backgroundColor: AppColors.error,
        textColor: AppColors.onError,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
