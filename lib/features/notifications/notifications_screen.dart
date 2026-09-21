import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../data/repository.dart';
import '../../models/org.dart';
import '../shell/home_shell.dart';

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) {
  return ref.watch(notificationRepoProvider).list(limit: 100);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(context, ref),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        child: AsyncView<List<AppNotification>>(
          value: notifications,
          onRetry: () => ref.invalidate(notificationsProvider),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'You are all caught up',
                    message: 'Mentions, assignments and approvals land here.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _Row(
                notification: items[i],
                onTap: () => _open(context, ref, items[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post(Api.notificationsReadAll);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      if (context.mounted) showToast(context, 'All caught up');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, isError: true);
    }
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    if (!notification.isRead) {
      try {
        await ref
            .read(apiClientProvider)
            .post('${Api.notifications}/${notification.id}/read');
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadCountProvider);
      } on ApiException {
        // Opening matters more than the read receipt.
      }
    }
    if (!context.mounted) return;

    // Deep-link to the record the notification is about, when we know how.
    final id = notification.entityId;
    final type = (notification.entityType ?? '').toLowerCase();
    if (id == null || id.isEmpty) return;
    switch (type) {
      case 'task':
        context.push('/tasks/$id');
      case 'project':
        context.push('/projects/$id');
      case 'deal':
        context.push('/deals/$id');
      case 'invoice':
        context.push('/invoices');
      default:
        break;
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.actor != null)
            Avatar.user(notification.actor!, size: 34)
          else
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                if (notification.body != null &&
                    notification.body != notification.title) ...[
                  const SizedBox(height: 2),
                  Text(
                    Fmt.plainText(notification.body, max: 120),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  Fmt.relative(notification.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (unread)
            Container(
              margin: const EdgeInsets.only(top: 6, left: 6),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
