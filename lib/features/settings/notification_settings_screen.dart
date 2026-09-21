import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/notifications/digest.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../shell/home_shell.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(notificationsAllowedProvider).value ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xxxl,
        ),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: (allowed ? AppColors.success : AppColors.warning)
                            .withValues(alpha: 0.12),
                        borderRadius: AppRadius.rMd,
                      ),
                      child: Icon(
                        allowed
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        size: 20,
                        color: allowed ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            allowed
                                ? 'Notifications are on'
                                : 'Notifications are off',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            allowed
                                ? 'You will be alerted about mentions, '
                                    'assignments and approvals.'
                                : 'Turn these on to hear about mentions, '
                                    'assignments and approvals.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!allowed)
                  FilledButton.icon(
                    onPressed: () => _enable(context, ref),
                    icon: const Icon(Icons.notifications_rounded, size: 18),
                    label: const Text('Allow notifications'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _test(context, ref),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Send a test notification'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('What to notify me about'),
          const _TopicList(),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How delivery works', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Autovella checks for new notifications while the app is '
                  'open and alerts you as they arrive. Alerts when the app is '
                  'fully closed need server-side push, which is not enabled on '
                  'your platform yet.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings_outlined, size: 17),
                  label: const Text('Open system settings'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    ref.invalidate(notificationsAllowedProvider);
    if (!context.mounted) return;
    if (ok) {
      showToast(context, 'Notifications enabled');
    } else {
      showToast(
        context,
        'Permission denied. You can turn it on in system settings.',
        isError: true,
      );
    }
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    await ref.read(notificationServiceProvider).show(
          id: 999001,
          title: 'Autovella',
          body: 'Notifications are working.',
        );
    if (context.mounted) showToast(context, 'Test notification sent');
  }
}

/// Per-topic switches. Everything is on by default except the attendance
/// nudge, which is opt-in — an unrequested reminder is the fastest way to get
/// notifications switched off entirely.
class _TopicList extends ConsumerWidget {
  const _TopicList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(digestTopicsProvider);
    final theme = Theme.of(context);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < DigestTopic.values.length; i++) ...[
            SwitchListTile(
              value: topics[DigestTopic.values[i]] ?? true,
              onChanged: (v) => ref
                  .read(digestTopicsProvider.notifier)
                  .toggle(DigestTopic.values[i], v),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 2,
              ),
              title: Text(
                DigestTopic.values[i].title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
              subtitle: Text(
                DigestTopic.values[i].blurb,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (i < DigestTopic.values.length - 1)
              Divider(height: 1, color: theme.colorScheme.outline),
          ],
        ],
      ),
    );
  }
}

/// Polls for new notifications while the app is in the foreground and raises
/// an OS notification for anything new. Mounted once, by the shell.
class NotificationPoller extends ConsumerStatefulWidget {
  const NotificationPoller({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationPoller> createState() => _NotificationPollerState();
}

class _NotificationPollerState extends ConsumerState<NotificationPoller>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Checking on resume is the cheap, battery-friendly moment: it is exactly
    // when the user might have missed something.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!mounted) return;
    final service = ref.read(notificationServiceProvider);
    await service.init();
    if (!mounted) return;
    await service.pollAndNotify(
      ref.read(apiClientProvider),
      ref.read(prefsProvider),
    );
    if (!mounted) return;
    // Everything the server does not push: approvals, due work, overdue
    // invoices, the attendance nudge.
    await ref.read(notificationDigestProvider).run();
    if (mounted) ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
