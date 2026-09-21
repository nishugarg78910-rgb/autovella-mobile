import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/atoms.dart';
import '../../models/org.dart';
import '../auth/auth_controller.dart';

/// One entry in the module directory.
class _Module {
  const _Module(
    this.label,
    this.icon,
    this.route, {
    this.permission,
    this.anyPermission = const [],
    this.feature,
    this.adminOnly = false,
  });

  final String label;
  final IconData icon;
  final String route;

  /// The `rolePermissions` key that must grant `read`.
  final String? permission;

  /// Any one of these keys granting read is enough. Used where the
  /// platform spreads a capability over several grants — approvals are
  /// carried by `approveAllTimesheets` / `approveAllTimeOff` /
  /// `approveAllExpenses` as well as an `approvals` module key.
  final List<String> anyPermission;

  /// The organisation feature flag the module needs.
  final String? feature;

  final bool adminOnly;

  bool visibleTo(CurrentUser? user) {
    if (user == null) return false;
    if (adminOnly && !user.isAdmin) return false;
    if (feature != null && !(user.organization?.hasFeature(feature!) ?? true)) {
      return false;
    }
    if (permission != null && !user.permissions.canRead(permission!)) {
      return false;
    }
    if (anyPermission.isNotEmpty &&
        !anyPermission.any(user.permissions.canRead)) {
      return false;
    }
    return true;
  }
}

class _Group {
  const _Group(this.title, this.modules);
  final String title;
  final List<_Module> modules;
}

/// Everything the web platform has, grouped for a phone.
///
/// The web sidebar is a flat list of thirty-odd links. Flattened onto a phone
/// that is a wall of text, so here they are grouped by the job being done and
/// filtered by what this user's role and plan actually allow.
/// Everything the platform actually has, grouped for a phone.
///
/// This list is now derived from the web app's own route modules. An earlier
/// build advertised Leads, Customers, Vehicles, Inventory and a whole
/// "Operations" group — none of which exist on this platform — so those
/// entries could only ever fail. They are gone.
const _groups = <_Group>[
  _Group('Time & attendance', [
    _Module('Attendance', Icons.fingerprint_rounded, '/attendance',
        permission: 'attendance', feature: 'attendance'),
    _Module('Timesheets', Icons.schedule_rounded, '/timesheets',
        permission: 'timesheets', feature: 'timesheets'),
    _Module('Time off', Icons.beach_access_rounded, '/time-off',
        permission: 'timeOff', feature: 'time_off'),
    _Module('Holidays', Icons.celebration_rounded, '/holidays',
        permission: 'holidays'),
    _Module('Approvals', Icons.fact_check_outlined, '/approvals',
        anyPermission: [
          'approvals',
          'approveAllTimesheets',
          'approveAllTimeOff',
          'approveAllExpenses',
        ]),
  ]),
  _Group('Finance', [
    _Module('Invoices', Icons.receipt_long_rounded, '/invoices',
        permission: 'invoices', feature: 'invoicing'),
    _Module('Expenses', Icons.account_balance_wallet_rounded, '/expenses',
        permission: 'expenses', feature: 'expenses'),
    _Module('Exchange rates', Icons.currency_exchange_rounded,
        '/exchange-rates', feature: 'multicurrency', adminOnly: true),
  ]),
  _Group('Work', [
    _Module('Sprints', Icons.directions_run_rounded, '/sprints',
        permission: 'sprints', feature: 'sprints'),
    _Module('Calendar', Icons.calendar_month_rounded, '/calendar',
        permission: 'calendar'),
    _Module('Resource planner', Icons.calendar_view_week_rounded,
        '/resource-planner', permission: 'projects'),
    _Module('Templates', Icons.dashboard_customize_outlined, '/templates',
        feature: 'templates'),
    _Module('Saved views', Icons.bookmark_border_rounded, '/saved-views'),
    _Module('Bookmarks', Icons.star_border_rounded, '/bookmarks',
        permission: 'bookmarks'),
  ]),
  _Group('Organisation', [
    _Module('People', Icons.people_alt_rounded, '/people',
        permission: 'users'),
    _Module('Teams', Icons.groups_rounded, '/teams', permission: 'teams'),
    _Module('Roles', Icons.admin_panel_settings_outlined, '/roles',
        adminOnly: true),
  ]),
  _Group('Insights', [
    _Module('Analytics', Icons.insights_rounded, '/analytics',
        permission: 'analytics'),
    _Module('Audit log', Icons.history_rounded, '/audit-log',
        adminOnly: true),
  ]),
  _Group('System', [
    _Module('Automations', Icons.bolt_rounded, '/automations',
        feature: 'automation'),
    _Module('Notifications', Icons.notifications_active_outlined,
        '/notification-settings'),
    _Module('Security & sync', Icons.lock_outline_rounded, '/security'),
    _Module('Data import', Icons.upload_file_rounded, '/import',
        adminOnly: true),
    _Module('Recycle bin', Icons.delete_outline_rounded, '/recycle-bin'),
  ]),
];

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.md,
          AppSpacing.gutter,
          AppSpacing.xxxl,
        ),
        children: [
          _ProfileCard(user: user),
          const SizedBox(height: AppSpacing.xl),
          for (final group in _groups) ...[
            Builder(
              builder: (context) {
                final visible =
                    group.modules.where((m) => m.visibleTo(user)).toList();
                if (visible.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(group.title),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < visible.length; i++) ...[
                            _ModuleTile(module: visible[i]),
                            if (i < visible.length - 1)
                              Divider(
                                height: 1,
                                indent: 52,
                                color: theme.colorScheme.outline,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                );
              },
            ),
          ],
          const _SignOutButton(),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'Autovella for ${Theme.of(context).platform == TargetPlatform.iOS ? 'iOS' : 'Android'}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (user?.organization != null) ...[
            const SizedBox(height: 2),
            Center(
              child: Text(
                '${user!.organization!.name} · '
                '${user.organization!.planName ?? 'Plan'}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});

  final _Module module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () => context.push(module.route),
      leading: Icon(module.icon, size: 21, color: theme.colorScheme.primary),
      title: Text(
        module.label,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rLg),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final CurrentUser? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink();

    final org = user!.organization;

    return AppCard(
      onTap: () => context.push('/profile'),
      child: Column(
        children: [
          Row(
            children: [
              Avatar(
                initials: user!.initials,
                imageUrl: user!.avatar,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user!.fullName,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user!.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (user!.role != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: AppRadius.rSm,
                  ),
                  child: Text(
                    user!.role!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          if (org != null && org.quotaBytes > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text('Storage', style: theme.textTheme.bodySmall),
                const Spacer(),
                Text(
                  '${_gb(org.usedBytes)} of ${_gb(org.quotaBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressRail(
              value: org.storageUsed,
              height: 5,
              color: org.storageUsed > 0.9 ? AppColors.danger : null,
            ),
          ],
        ],
      ),
    );
  }

  static String _gb(int bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(1)} GB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              'You will need to sign in again to use Autovella on this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(authProvider.notifier).signOut();
        }
      },
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text('Sign out'),
    );
  }
}
