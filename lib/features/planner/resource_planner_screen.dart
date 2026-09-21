import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../people/people_screen.dart';

/// One planned allocation: somebody's time, on something, on a day.
class Allocation {
  const Allocation({
    required this.userId,
    required this.date,
    this.hours = 0,
    this.label,
  });

  final String userId;
  final DateTime date;
  final double hours;
  final String? label;

  static Allocation? fromJson(Map<String, dynamic> json) {
    final date = J.date(
      J.pick(json, ['date', 'startDate', 'scheduledDate', 'day']),
    );
    final userId = J.strOrNull(
      J.pick(json, ['userId', 'assigneeId', 'resourceId']),
    );
    if (date == null || userId == null) return null;
    return Allocation(
      userId: userId,
      date: DateTime(date.year, date.month, date.day),
      hours: J.dbl(
        J.pick(json, ['hours', 'allocatedHours', 'capacity', 'duration']),
        // A schedule row with no hours still occupies the day; treat it as a
        // standard working day rather than as nothing.
        8,
      ),
      label: J.strOrNull(J.pick(json, ['title', 'name', 'taskName'])),
    );
  }
}

final allocationsProvider =
    FutureProvider.autoDispose<List<Allocation>>((ref) async {
  final data = await ref.watch(apiClientProvider).get(
        Api.taskSchedules,
        query: {'limit': 200},
      );
  return J
      .maps(ApiClient.asList(data))
      .map(Allocation.fromJson)
      .whereType<Allocation>()
      .toList();
});

/// Resource planner.
///
/// The question this answers is "who has room next week, and who is drowning".
/// It lays the next 14 days across the top and gives each person a row of
/// day cells shaded by how loaded they are, with their total beside them —
/// the shape of the web planner, compressed to a phone.
class ResourcePlannerScreen extends ConsumerStatefulWidget {
  const ResourcePlannerScreen({super.key});

  @override
  ConsumerState<ResourcePlannerScreen> createState() =>
      _ResourcePlannerScreenState();
}

class _ResourcePlannerScreenState
    extends ConsumerState<ResourcePlannerScreen> {
  int _weekOffset = 0;

  static const _capacityPerDay = 8.0;

  List<DateTime> get _days {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .add(Duration(days: _weekOffset * 7));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final allocations = ref.watch(allocationsProvider);
    final people = ref.watch(peopleProvider(null));
    final theme = Theme.of(context);
    final days = _days;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource planner'),
        actions: [
          IconButton(
            tooltip: 'Previous week',
            onPressed: () => setState(() => _weekOffset--),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          if (_weekOffset != 0)
            TextButton(
              onPressed: () => setState(() => _weekOffset = 0),
              child: const Text('Today'),
            ),
          IconButton(
            tooltip: 'Next week',
            onPressed: () => setState(() => _weekOffset++),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allocationsProvider);
          ref.invalidate(peopleProvider(null));
          await ref.read(allocationsProvider.future);
        },
        child: AsyncView<List<Allocation>>(
          value: allocations,
          onRetry: () => ref.invalidate(allocationsProvider),
          data: (all) {
            final roster = people.value ?? const <Person>[];

            // Load per person per day for the visible week.
            final byUser = <String, Map<DateTime, double>>{};
            for (final a in all) {
              if (a.date.isBefore(days.first) || a.date.isAfter(days.last)) {
                continue;
              }
              byUser.putIfAbsent(a.userId, () => {});
              byUser[a.userId]![a.date] =
                  (byUser[a.userId]![a.date] ?? 0) + a.hours;
            }

            if (roster.isEmpty && byUser.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 50),
                  EmptyState(
                    icon: Icons.calendar_view_week_rounded,
                    title: 'Nothing scheduled this week',
                    message: all.isEmpty
                        ? 'Allocations created in the web planner appear here, '
                            'showing who is loaded and who has room.'
                        : 'Try another week.',
                    actionLabel: 'Next week',
                    onAction: () => setState(() => _weekOffset++),
                  ),
                ],
              );
            }

            // Everyone with a name, loaded first.
            final rows = roster.isNotEmpty
                ? roster
                : byUser.keys
                    .map((id) => Person(id: id, firstName: 'User', lastName: ''))
                    .toList();
            rows.sort((a, b) {
              final la = _total(byUser[a.id], days);
              final lb = _total(byUser[b.id], days);
              return lb.compareTo(la);
            });

            final weekCapacity = _capacityPerDay * 5 * rows.length;
            final booked = rows.fold<double>(
              0,
              (s, p) => s + _total(byUser[p.id], days),
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Booked',
                        value: Fmt.hours(booked),
                        icon: Icons.event_busy_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Utilisation',
                        value: weekCapacity <= 0
                            ? '—'
                            : Fmt.percent(booked / weekCapacity),
                        icon: Icons.speed_rounded,
                        accent: booked / (weekCapacity == 0 ? 1 : weekCapacity) > 0.9
                            ? AppColors.danger
                            : AppColors.brandTeal,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'People',
                        value: '${rows.length}',
                        icon: Icons.people_alt_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${Fmt.date(days.first)} – ${Fmt.date(days.last)}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      _HeaderRow(days: days),
                      const SizedBox(height: AppSpacing.sm),
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: AppSpacing.md,
                            color: theme.colorScheme.outline,
                          ),
                        _PersonRow(
                          person: rows[i],
                          load: byUser[rows[i].id] ?? const {},
                          days: days,
                          capacity: _capacityPerDay,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _Legend(),
              ],
            );
          },
        ),
      ),
    );
  }

  static double _total(Map<DateTime, double>? load, List<DateTime> days) {
    if (load == null) return 0;
    return days.fold<double>(0, (s, d) => s + (load[d] ?? 0));
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.days});

  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    return Row(
      children: [
        const SizedBox(width: 96),
        for (final d in days)
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Text(
                    ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1],
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                  ),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: d.day == today.day && d.month == today.month
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: d.day == today.day && d.month == today.month
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 40),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.load,
    required this.days,
    required this.capacity,
  });

  final Person person;
  final Map<DateTime, double> load;
  final List<DateTime> days;
  final double capacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = days.fold<double>(0, (s, d) => s + (load[d] ?? 0));

    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Row(
            children: [
              Avatar(initials: person.initials, size: 24, maxInitials: 1),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  person.firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final d in days)
          Expanded(
            child: _DayCell(
              hours: load[d] ?? 0,
              capacity: capacity,
              isWeekend: d.weekday >= 6,
            ),
          ),
        SizedBox(
          width: 40,
          child: Text(
            total == 0 ? '—' : Fmt.hours(total),
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: total > capacity * 5 ? AppColors.danger : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// One day's load. Shade deepens with utilisation; over-capacity turns red.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.hours,
    required this.capacity,
    required this.isWeekend,
  });

  final double hours;
  final double capacity;
  final bool isWeekend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = capacity <= 0 ? 0.0 : (hours / capacity).clamp(0.0, 2.0);

    Color fill;
    if (hours <= 0) {
      fill = isWeekend
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : theme.colorScheme.surfaceContainerHighest;
    } else if (ratio > 1) {
      fill = AppColors.danger;
    } else {
      fill = theme.colorScheme.primary.withValues(alpha: 0.25 + ratio * 0.65);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 4),
      child: Tooltip(
        message: hours <= 0 ? 'Free' : Fmt.hours(hours),
        child: Container(
          height: 24,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
          ),
          child: hours > 0
              ? Center(
                  child: Text(
                    hours % 1 == 0
                        ? '${hours.toInt()}'
                        : hours.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: ratio > 0.55 ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget swatch(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 5),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          ],
        );

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: 6,
      children: [
        swatch(theme.colorScheme.surfaceContainerHighest, 'Free'),
        swatch(theme.colorScheme.primary.withValues(alpha: 0.45), 'Part day'),
        swatch(theme.colorScheme.primary.withValues(alpha: 0.9), 'Full day'),
        swatch(AppColors.danger, 'Over capacity'),
      ],
    );
  }
}
