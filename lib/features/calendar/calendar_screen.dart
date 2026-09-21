import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/work.dart';
import '../psa/psa_providers.dart';
import '../work/widgets/task_row.dart';
import '../work/work_providers.dart';

/// Calendar, in two views.
///
/// Agenda answers "what is coming"; the month grid answers "how busy is the
/// 14th" — you cannot get that from a list without scrolling. Both read the
/// same data, so switching is instant.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _monthView = false;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(myTasksProvider);
    final holidays = ref.watch(holidaysProvider);
    final leave = ref.watch(myTimeOffProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: SegmentedButton<bool>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.view_agenda_outlined, size: 17),
                  tooltip: 'Agenda',
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.calendar_month_rounded, size: 17),
                  tooltip: 'Month',
                ),
              ],
              selected: {_monthView},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _monthView = s.first),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTasksProvider);
          ref.invalidate(holidaysProvider);
          ref.invalidate(myTimeOffProvider);
          await ref.read(myTasksProvider.future);
        },
        child: AsyncView<List<Task>>(
          value: tasks,
          onRetry: () => ref.invalidate(myTasksProvider),
          data: (items) {
            final dated = items
                .where((t) => t.endDate != null && !t.isDone)
                .toList()
              ..sort((a, b) => a.endDate!.compareTo(b.endDate!));

            final byDay = <DateTime, List<Task>>{};
            for (final t in dated) {
              final d = t.endDate!;
              byDay.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(t);
            }

            final holidayByDay = <DateTime, String>{};
            holidays.whenData((list) {
              for (final h in list) {
                final d = h.date;
                if (d == null) continue;
                holidayByDay[DateTime(d.year, d.month, d.day)] = h.name;
              }
            });

            final leaveDays = <DateTime>{};
            leave.whenData((list) {
              for (final r in list) {
                if (r.isRejected || r.isCancelled) continue;
                var d = r.startDate;
                final end = r.endDate ?? r.startDate;
                while (d != null && end != null && !d.isAfter(end)) {
                  leaveDays.add(DateTime(d.year, d.month, d.day));
                  d = d.add(const Duration(days: 1));
                }
              }
            });

            return _monthView
                ? _MonthView(
                    month: _visibleMonth,
                    selected: _selected,
                    byDay: byDay,
                    holidays: holidayByDay,
                    leave: leaveDays,
                    onMonth: (m) => setState(() {
                      _visibleMonth = m;
                      _selected = null;
                    }),
                    onSelect: (d) => setState(() => _selected = d),
                  )
                : _AgendaView(byDay: byDay, holidays: holidayByDay);
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ agenda

class _AgendaView extends StatelessWidget {
  const _AgendaView({required this.byDay, required this.holidays});

  final Map<DateTime, List<Task>> byDay;
  final Map<DateTime, String> holidays;

  @override
  Widget build(BuildContext context) {
    if (byDay.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 60),
          EmptyState(
            icon: Icons.event_available_rounded,
            title: 'Nothing scheduled',
            message: 'Tasks with a due date appear here in order.',
          ),
        ],
      );
    }
    final days = byDay.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xxxl,
      ),
      children: [
        for (final day in days) ...[
          _DayHeader(
            day: day,
            count: byDay[day]!.length,
            holiday: holidays[day],
          ),
          for (final task in byDay[day]!) ...[
            TaskRow(task: task),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------- month

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.selected,
    required this.byDay,
    required this.holidays,
    required this.leave,
    required this.onMonth,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime? selected;
  final Map<DateTime, List<Task>> byDay;
  final Map<DateTime, String> holidays;
  final Set<DateTime> leave;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = first.weekday - 1;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    final cells = <DateTime?>[
      ...List.filled(leadingBlanks, null),
      for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final selectedTasks = selected == null ? const <Task>[] : (byDay[selected] ?? const <Task>[]);

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
            IconButton(
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                Fmt.monthYear(month),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontSize: 10.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (var row = 0; row < cells.length / 7; row++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: _DayCell(
                          day: cells[row * 7 + col],
                          isToday: cells[row * 7 + col] == todayKey,
                          isSelected: cells[row * 7 + col] != null &&
                              cells[row * 7 + col] == selected,
                          taskCount: byDay[cells[row * 7 + col]]?.length ?? 0,
                          overdue: (byDay[cells[row * 7 + col]] ?? const [])
                              .any((t) => t.isOverdue),
                          isHoliday:
                              holidays.containsKey(cells[row * 7 + col]),
                          isLeave: leave.contains(cells[row * 7 + col]),
                          onTap: cells[row * 7 + col] == null
                              ? null
                              : () => onSelect(cells[row * 7 + col]!),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _MonthLegend(),
        const SizedBox(height: AppSpacing.xl),
        if (selected != null) ...[
          _DayHeader(
            day: selected!,
            count: selectedTasks.length,
            holiday: holidays[selected],
          ),
          if (selectedTasks.isEmpty)
            AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.event_available_rounded,
                title: holidays.containsKey(selected)
                    ? holidays[selected]!
                    : 'Nothing due',
                message: leave.contains(selected) ? 'You are on leave.' : null,
              ),
            )
          else
            for (final t in selectedTasks) ...[
              TaskRow(task: t),
              const SizedBox(height: AppSpacing.md),
            ],
        ] else
          Center(
            child: Text(
              'Pick a day to see what is due',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.taskCount,
    required this.overdue,
    required this.isHoliday,
    required this.isLeave,
    required this.onTap,
  });

  final DateTime? day;
  final bool isToday;
  final bool isSelected;
  final int taskCount;
  final bool overdue;
  final bool isHoliday;
  final bool isLeave;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (day == null) return const SizedBox(height: 46);

    final bg = isSelected
        ? theme.colorScheme.primary
        : isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent;
    final fg = isSelected
        ? Colors.white
        : isHoliday
            ? AppColors.brandOrange
            : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rSm,
      child: SizedBox(
        height: 46,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadius.rSm,
              ),
              child: Text(
                '${day!.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (taskCount > 0)
                  _Dot(
                    color: overdue
                        ? AppColors.danger
                        : theme.colorScheme.primary,
                  ),
                if (isHoliday) const _Dot(color: AppColors.brandOrange),
                if (isLeave) const _Dot(color: AppColors.brandViolet),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 4.5,
        height: 4.5,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _MonthLegend extends StatelessWidget {
  const _MonthLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(color: c),
            const SizedBox(width: 5),
            Text(label,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          ],
        );

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        item(theme.colorScheme.primary, 'Tasks due'),
        item(AppColors.danger, 'Overdue'),
        item(AppColors.brandOrange, 'Holiday'),
        item(AppColors.brandViolet, 'Leave'),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count, this.holiday});

  final DateTime day;
  final int count;
  final String? holiday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPast = day.isBefore(today);
    final isToday = day == today;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isPast
                  ? AppColors.danger
                  : isToday
                      ? AppColors.warning
                      : theme.colorScheme.outlineVariant,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '${Fmt.friendlyDate(day).toUpperCase()} · ${Fmt.weekday(day)}',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                letterSpacing: 0.6,
                color: isPast ? AppColors.danger : null,
              ),
            ),
          ),
          const Spacer(),
          if (holiday != null) ...[
            const Icon(Icons.celebration_rounded,
                size: 13, color: AppColors.brandOrange),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                holiday!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandOrange,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text('$count',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
