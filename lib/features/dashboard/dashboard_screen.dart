import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/quick_create.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/states.dart';
import '../../models/crm.dart';
import '../../models/finance.dart';
import '../attendance/attendance_controller.dart';
import '../auth/auth_controller.dart';
import '../shell/home_shell.dart';
import '../work/widgets/task_row.dart';
import '../work/work_providers.dart';
import 'home_providers.dart';

/// Home.
///
/// Rebuilt to answer, in one screenful: am I clocked in, what is on fire, who
/// is waiting on me, where does the money stand, and what is due today. The
/// first version showed three counters and a list, which read as empty on a
/// tall phone.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final work = ref.watch(myWorkProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.gutter,
        title: Row(
          children: [
            const AutovellaMark(height: 26),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _greeting(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                    ),
                  ),
                  Text(
                    user?.firstName.isNotEmpty == true
                        ? user!.firstName
                        : 'Autovella',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => showQuickCreate(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Create',
          ),
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
          ),
          const NotificationBell(),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.gutter, left: 2),
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: user == null
                  ? const Avatar(initials: '?', size: 32)
                  : Avatar(initials: user.initials, size: 32),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTasksProvider);
          ref.invalidate(todayAttendanceProvider);
          ref.invalidate(unreadCountProvider);
          ref.invalidate(approvalLoadProvider);
          ref.invalidate(homePipelineProvider);
          ref.invalidate(homeInvoicesProvider);
          ref.invalidate(nextHolidayProvider);
          await ref.read(myWorkProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            AppSpacing.xxxl,
          ),
          children: [
            const CheckInCard(),
            const SizedBox(height: AppSpacing.lg),
            _StatsRow(work: work),
            const SizedBox(height: AppSpacing.xl),
            const _ApprovalsCard(),
            const _MoneyRow(),
            const SectionLabel('Quick actions'),
            const _QuickActions(),
            const SizedBox(height: AppSpacing.xl),
            work.when(
              loading: () => const _TodaySkeleton(),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(myTasksProvider),
              ),
              data: (buckets) => _TodaySection(buckets: buckets),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _UpcomingCard(),
          ],
        ),
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Clock in / clock out.
class CheckInCard extends ConsumerWidget {
  const CheckInCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayAttendanceProvider);
    final busy = ref.watch(attendanceControllerProvider).isLoading;

    // Never hide this card on error. An earlier build returned an empty box
    // when today's record failed to load, so a wrong endpoint made the whole
    // check-in control disappear rather than show a problem. Punching does
    // not depend on having today's record, so the button stays available.
    final record = today.value;
    final failed = today.hasError;

    return today.maybeWhen(
      loading: () => const Skeleton(height: 104, radius: AppRadius.xl),
      orElse: () {
        final checkedIn = record?.isCheckedIn ?? false;
        final punches = record?.punches.length ?? 0;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brandNavy, AppColors.heroGradientEnd],
            ),
            borderRadius: AppRadius.rXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: checkedIn
                                    ? AppColors.brandTeal
                                    : Colors.white38,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              failed
                                  ? 'Attendance unavailable'
                                  : checkedIn
                                      ? 'Clocked in'
                                      : 'Not clocked in',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record == null ? '—' : Fmt.duration(record.worked),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.9,
                          ),
                        ),
                        if (record?.firstIn != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            checkedIn
                                ? 'Since ${Fmt.time(record!.firstIn)}'
                                : '${Fmt.time(record!.firstIn)} – ${Fmt.time(record.lastOut)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    onPressed: busy ? null : () => _punch(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.brandNavy,
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Text(checkedIn ? 'Check out' : 'Check in'),
                  ),
                ],
              ),
              if (punches > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in record!.punches)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: AppRadius.rSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              p.isIn
                                  ? Icons.login_rounded
                                  : Icons.logout_rounded,
                              size: 11,
                              color: p.isIn
                                  ? AppColors.brandTeal
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              Fmt.time(p.at),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _punch(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(attendanceControllerProvider.notifier).punch();
    if (!context.mounted) return;
    if (ok) {
      showToast(context, 'Attendance recorded');
    } else {
      final error = ref.read(attendanceControllerProvider).error;
      showToast(
        context,
        error is ApiException ? error.message : 'Could not record attendance',
        isError: true,
      );
    }
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.work});

  final AsyncValue<MyWorkBuckets> work;

  @override
  Widget build(BuildContext context) {
    final b = work.value;
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Overdue',
            value: '${b?.overdue.length ?? 0}',
            icon: Icons.error_outline_rounded,
            accent: AppColors.danger,
            onTap: () => context.go('/my-work'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatTile(
            label: 'Due today',
            value: '${b?.today.length ?? 0}',
            icon: Icons.today_rounded,
            accent: AppColors.warning,
            onTap: () => context.go('/my-work'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatTile(
            label: 'Open',
            value: '${b?.openCount ?? 0}',
            icon: Icons.checklist_rounded,
            onTap: () => context.go('/my-work'),
          ),
        ),
      ],
    );
  }
}

/// "N things are waiting on you" — only when there actually are.
class _ApprovalsCard extends ConsumerWidget {
  const _ApprovalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(approvalLoadProvider).value;
    if (load == null || load.isEmpty) return const SizedBox.shrink();

    final parts = <String>[
      if (load.timesheets > 0) '${load.timesheets} timesheet${load.timesheets == 1 ? '' : 's'}',
      if (load.timeOff > 0) '${load.timeOff} leave request${load.timeOff == 1 ? '' : 's'}',
      if (load.expenses > 0) '${load.expenses} expense${load.expenses == 1 ? '' : 's'}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: AppCard(
        onTap: () => context.push('/approvals'),
        accentColor: AppColors.warning,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppRadius.rMd,
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waiting on you',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parts.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Pipeline and receivables, side by side — hidden when the plan or role
/// does not include them.
class _MoneyRow extends ConsumerWidget {
  const _MoneyRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(homePipelineProvider).value ?? const <Deal>[];
    final invoices = ref.watch(homeInvoicesProvider).value ?? const <Invoice>[];
    if (deals.isEmpty && invoices.isEmpty) return const SizedBox.shrink();

    final open = deals.where((d) => d.isOpen);
    final pipeline = open.fold<double>(0, (s, d) => s + (d.amount ?? 0));
    // Taking the *first* record's currency was wrong: one USD deal at the top
    // of the list relabelled the whole rupee pipeline. Use whichever currency
    // dominates the set, which is what the CRM rollup already did.
    final currency = _dominantCurrency(deals.map((d) => d.currency));

    final overdue = invoices.where((i) => i.isOverdue);
    final overdueValue = overdue.fold<double>(0, (s, i) => s + i.balanceDue);
    final invCurrency =
        _dominantCurrency(invoices.map((i) => i.currency));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Money'),
        Row(
          children: [
            if (deals.isNotEmpty)
              Expanded(
                child: StatTile.money(
                  pipeline,
                  label: 'Open pipeline',
                  currency: currency,
                  delta: '${open.length} deals',
                  deltaPositive: true,
                  icon: Icons.trending_up_rounded,
                  accent: AppColors.brandTeal,
                  onTap: () => context.go('/crm'),
                ),
              ),
            if (deals.isNotEmpty && invoices.isNotEmpty)
              const SizedBox(width: AppSpacing.md),
            if (invoices.isNotEmpty)
              Expanded(
                child: StatTile.money(
                  overdueValue,
                  label: 'Overdue invoices',
                  currency: invCurrency,
                  delta: '${overdue.length} unpaid',
                  deltaPositive: false,
                  icon: Icons.warning_amber_rounded,
                  accent: AppColors.danger,
                  onTap: () => context.push('/invoices'),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// The currency most records in a set use, defaulting to INR.
String _dominantCurrency(Iterable<String?> codes) {
  final tally = <String, int>{};
  for (final c in codes) {
    final code = (c ?? 'INR').toUpperCase();
    tally[code] = (tally[code] ?? 0) + 1;
  }
  if (tally.isEmpty) return 'INR';
  return tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    const actions = [
      (Icons.add_task_rounded, 'New task', '/tasks/new'),
      (Icons.schedule_rounded, 'Log time', '/timesheets/new'),
      (Icons.receipt_long_rounded, 'Add expense', '/expenses'),
      (Icons.beach_access_rounded, 'Request leave', '/time-off/new'),
      (Icons.folder_open_rounded, 'New project', '/projects/new'),
    ];

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final (icon, label, route) = actions[i];
          return SizedBox(
            width: 94,
            child: AppCard(
              onTap: () => context.push(route),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const Spacer(),
                  Text(
                    label,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.buckets});

  final MyWorkBuckets buckets;

  @override
  Widget build(BuildContext context) {
    final focus = [...buckets.overdue, ...buckets.today].take(4).toList();

    if (focus.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Today'),
          AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.task_alt_rounded,
              title: 'Nothing due today',
              message: buckets.openCount > 0
                  ? 'You have ${buckets.openCount} other open '
                      '${buckets.openCount == 1 ? 'task' : 'tasks'}.'
                  : 'You are all clear.',
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Today · ${focus.length}',
          action: 'See all',
          onAction: () => context.go('/my-work'),
        ),
        for (final task in focus) ...[
          TaskRow(task: task),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

/// Next holiday and next approved leave.
class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holiday = ref.watch(nextHolidayProvider).value;
    final leave = ref.watch(myUpcomingLeaveProvider).value;
    if (holiday == null && leave == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Coming up'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (holiday != null)
                ListTile(
                  leading: const Icon(
                    Icons.celebration_rounded,
                    color: AppColors.brandOrange,
                    size: 20,
                  ),
                  title: Text(
                    holiday.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(Fmt.fullDate(holiday.date)),
                  trailing: Text(
                    holiday.daysAway == 0 ? 'Today' : 'in ${holiday.daysAway}d',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              if (holiday != null && leave != null)
                Divider(
                  height: 1,
                  indent: 56,
                  color: Theme.of(context).colorScheme.outline,
                ),
              if (leave != null)
                ListTile(
                  leading: const Icon(
                    Icons.beach_access_rounded,
                    color: AppColors.brandViolet,
                    size: 20,
                  ),
                  title: Text(
                    leave.type ?? 'Leave',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  subtitle: Text(
                    '${Fmt.date(leave.startDate)} – ${Fmt.date(leave.endDate)}',
                  ),
                  onTap: () => context.push('/time-off'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('Today'),
          Skeleton(height: 74, radius: AppRadius.lg),
          SizedBox(height: AppSpacing.md),
          Skeleton(height: 74, radius: AppRadius.lg),
        ],
      );
}
