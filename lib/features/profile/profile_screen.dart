import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Not signed in',
        ),
      );
    }

    final org = user.organization;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xxxl,
        ),
        children: [
          Center(
            child: Column(
              children: [
                Avatar(
                  initials: user.initials,
                  imageUrl: user.avatar,
                  size: 76,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(user.fullName, style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(user.email, style: theme.textTheme.bodySmall),
                if (user.role != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ToneChip.status(user.role),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const SectionLabel('Details'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                DetailRow(
                  label: 'Department',
                  icon: Icons.badge_outlined,
                  value: user.location,
                ),
                DetailRow(
                  label: 'Timezone',
                  icon: Icons.schedule_rounded,
                  value: user.timezone,
                ),
                DetailRow(
                  label: 'Status',
                  icon: Icons.verified_outlined,
                  value: user.isActive ? 'Active' : 'Inactive',
                ),
              ],
            ),
          ),
          if (org != null) ...[
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Organisation'),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  DetailRow(
                    label: 'Name',
                    icon: Icons.business_outlined,
                    value: org.name,
                  ),
                  DetailRow(
                    label: 'Plan',
                    icon: Icons.workspace_premium_outlined,
                    value: org.planName,
                  ),
                  DetailRow(
                    label: 'Location',
                    icon: Icons.place_outlined,
                    value: org.location,
                  ),
                  DetailRow(
                    label: 'Modules',
                    icon: Icons.extension_outlined,
                    value: '${org.featureFlags.length} enabled',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('Account'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.lock_reset_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(
                    'Change password',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 19),
                  onTap: () => context.push('/profile/password'),
                ),
                Divider(height: 1, indent: 56, color: theme.colorScheme.outline),
                ListTile(
                  leading: Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text(
                    'Security & sync',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 19),
                  onTap: () => context.push('/security'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('Appearance'),
          const _ThemePicker(),
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('Permissions'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your role grants access to '
                  '${user.permissions.modules.where((m) => user.permissions.canRead(m)).length} '
                  'of ${user.permissions.modules.length} modules.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Modules you cannot access are hidden from navigation '
                  'rather than shown and blocked.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: RadioGroup<ThemeMode>(
        groupValue: mode,
        onChanged: (value) {
          if (value != null) {
            ref.read(themeModeProvider.notifier).set(value);
          }
        },
        child: Column(
          children: [
            for (final option in ThemeMode.values)
              RadioListTile<ThemeMode>(
                value: option,
                dense: true,
                title: Text(
                  switch (option) {
                    ThemeMode.system => 'Match device',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  },
                  style: const TextStyle(fontSize: 14.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
