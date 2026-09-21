import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/offline_queue.dart';
import '../../core/security/app_lock.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';

/// Security and sync: the app lock, and anything waiting to reach the server.
class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    final pending = ref.watch(offlineQueueProvider);
    final online = ref.watch(connectivityProvider).value ?? true;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Security & sync')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xxxl,
        ),
        children: [
          const SectionLabel('App lock'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  value: lock.enabled,
                  onChanged: lock.available
                      ? (v) => _toggle(context, ref, v)
                      : null,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Require unlock',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    lock.available
                        ? 'Ask for your fingerprint, face or device PIN after '
                            'the app has been in the background for a couple '
                            'of minutes.'
                        : 'This device has no screen lock set up, so there is '
                            'nothing to authenticate against.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (lock.enabled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 15,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Your pipeline, salaries and invoices are protected '
                          'if this phone is lost.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          SectionLabel(
            pending.isEmpty ? 'Sync' : 'Waiting to sync · ${pending.length}',
            action: pending.isEmpty ? null : 'Sync now',
            onAction: pending.isEmpty ? null : () => _flush(context, ref),
          ),
          if (pending.isEmpty)
            AppCard(
              child: Row(
                children: [
                  Icon(
                    online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    size: 19,
                    color: online ? AppColors.success : AppColors.slate500,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      online
                          ? 'Everything is saved. Changes go straight to the '
                              'server.'
                          : "You're offline. Anything you change will be saved "
                              'here and sent when the connection returns.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final write in pending) ...[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_send_rounded,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                write.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Queued ${Fmt.relative(write.queuedAt)}'
                                '${write.attempts > 0 ? ' · ${write.attempts} failed attempt${write.attempts == 1 ? '' : 's'}' : ''}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Discard',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => ref
                              .read(offlineQueueProvider.notifier)
                              .remove(write.id),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),

          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How offline works', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Reading needs a connection. Writing does not — logging time, '
                  'filing an expense, changing a status or approving something '
                  'is saved here if you are offline and sent automatically when '
                  'you are back. A change that the server rejects is kept for a '
                  'few attempts, then dropped so it cannot retry forever.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    final ok = await ref.read(appLockProvider.notifier).setEnabled(value);
    if (!context.mounted) return;
    if (!ok && value) {
      showToast(context, 'Could not verify — app lock not enabled',
          isError: true);
    } else {
      showToast(context, value ? 'App lock on' : 'App lock off');
    }
  }

  Future<void> _flush(BuildContext context, WidgetRef ref) async {
    final sent = await ref.read(offlineQueueProvider.notifier).flush();
    if (!context.mounted) return;
    showToast(
      context,
      sent > 0
          ? 'Synced $sent change${sent == 1 ? '' : 's'}'
          : 'Nothing could be sent yet',
      isError: sent == 0,
    );
  }
}
