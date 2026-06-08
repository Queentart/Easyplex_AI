import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/date_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/notification_model.dart';
import '../notification_provider.dart';

/// Notification center: a chronological list with read / unread styling,
/// tap-to-read, and a "모두 읽음" (mark all read) action.
class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationListProvider);
    final hasUnread = ref.watch(unreadNotificationCountProvider) > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton.icon(
            onPressed: hasUnread ? () => _markAllRead(context, ref) : null,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('모두 읽음'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: state.when(
        loading: () => const LoadingView(message: '알림을 불러오는 중입니다...'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.read(notificationListProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: '알림이 없습니다',
              description: '새로운 소식이 도착하면 여기에 표시됩니다.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () =>
                ref.read(notificationListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _NotificationTile(
                notification: items[index],
                onTap: () => _onTap(context, ref, items[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    if (notification.isRead) return;
    try {
      await ref
          .read(notificationListProvider.notifier)
          .markRead(notification.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationListProvider.notifier).markAllRead();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 알림을 읽음 처리했습니다.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

/// A single notification row. Unread rows carry a teal accent dot and bolder
/// title; read rows are muted.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final createdAt = notification.createdAt;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread accent dot keeps a stable layout for read rows.
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Container(
              width: AppSpacing.sm,
              height: AppSpacing.sm,
              decoration: BoxDecoration(
                color: isUnread ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppTypography.headlineSm.copyWith(
                          color: isUnread
                              ? AppColors.onSurface
                              : AppColors.onSurfaceVariant,
                          fontWeight:
                              isUnread ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const StatusChip(label: '새 알림', tone: StatusTone.info),
                    ],
                  ],
                ),
                if (notification.body != null &&
                    notification.body!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    notification.body!,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    DateFormatter.relative(createdAt),
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.outline),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
