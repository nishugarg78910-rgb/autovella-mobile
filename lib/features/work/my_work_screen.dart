import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/filter_bar.dart';
import '../../core/widgets/quick_create.dart';
import '../../core/widgets/states.dart';
import '../../data/repository.dart';
import '../../models/work.dart';
import '../shell/home_shell.dart';
import 'widgets/task_row.dart';
import 'work_providers.dart';

/// My Work — everything assigned to me, filterable and sortable.
///
/// The default view is still urgency-bucketed, because that is how a day gets
/// triaged. The filter chips exist for the other question people ask — "show
/// me just this project" — without leaving the screen.
class MyWorkScreen extends ConsumerStatefulWidget {
  const MyWorkScreen({super.key});

  @override
  ConsumerState<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends ConsumerState<MyWorkScreen> {
  static const _all = 'All';
  static const _overdue = 'Overdue';
  static const _today = 'Today';
  static const _upcoming = 'Upcoming';
  static const _noDate = 'No date';
  static const _done = 'Done';

  String _filter = _all;
  SortOrder _sort = SortOrder.dueDate;

  Future<void> _toggle(Task task, bool done) async {
    try {
      await ref
          .read(taskRepoProvider)
          .update(task.id, {'status': done ? 'done' : 'todo'});
      ref.invalidate(myTasksProvider);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    }
  }

  List<Task> _apply(MyWorkBuckets b) {
    final list = switch (_filter) {
      _overdue => b.overdue,
      _today => b.today,
      _upcoming => b.upcoming,
      _noDate => b.noDate,
      _done => b.completed,
      _ => [...b.overdue, ...b.today, ...b.upcoming, ...b.noDate],
    };

    final sorted = [...list];
    int byDate(Task a, Task c) {
      final x = a.endDate;
      final y = c.endDate;
      if (x == null && y == null) return 0;
      if (x == null) return 1; // undated sinks
      if (y == null) return -1;
      return x.compareTo(y);
    }

    switch (_sort) {
      case SortOrder.dueDate:
        sorted.sort(byDate);
      case SortOrder.priority:
        const rank = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
        sorted.sort((a, c) {
          final pa = rank[(a.priority ?? '').toLowerCase()] ?? 9;
          final pc = rank[(c.priority ?? '').toLowerCase()] ?? 9;
          return pa == pc ? byDate(a, c) : pa.compareTo(pc);
        });
      case SortOrder.project:
        sorted.sort((a, c) {
          final r = (a.project?.name ?? '~')
              .toLowerCase()
              .compareTo((c.project?.name ?? '~').toLowerCase());
          return r == 0 ? byDate(a, c) : r;
        });
      case SortOrder.recentlyUpdated:
        sorted.sort((a, c) {
          final x = a.updatedAt;
          final y = c.updatedAt;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        });
      case SortOrder.title:
        sorted.sort(
          (a, c) => a.title.toLowerCase().compareTo(c.title.toLowerCase()),
        );
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final work = ref.watch(myWorkProvider);
    final buckets = work.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Work'),
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
          const SizedBox(width: 4),
        ],
        bottom: buckets == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: FilterBar(
                  selected: _filter,
                  onSelect: (v) => setState(() => _filter = v),
                  sort: _sort,
                  onSort: (v) => setState(() => _sort = v),
                  chips: {
                    _all: buckets.openCount,
                    if (buckets.overdue.isNotEmpty)
                      _overdue: buckets.overdue.length,
                    if (buckets.today.isNotEmpty) _today: buckets.today.length,
                    if (buckets.upcoming.isNotEmpty)
                      _upcoming: buckets.upcoming.length,
                    if (buckets.noDate.isNotEmpty) _noDate: buckets.noDate.length,
                    if (buckets.completed.isNotEmpty)
                      _done: buckets.completed.length,
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tasks/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New task'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTasksProvider);
          await ref.read(myWorkProvider.future);
        },
        child: AsyncView<MyWorkBuckets>(
          value: work,
          onRetry: () => ref.invalidate(myTasksProvider),
          data: (b) {
            if (b.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'Nothing assigned to you',
                    message: 'Tasks assigned to you will appear here, grouped '
                        'by when they are due.',
                    actionLabel: 'Create a task',
                    onAction: () => context.push('/tasks/new'),
                  ),
                ],
              );
            }

            final tasks = _apply(b);
            if (tasks.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 70),
                  EmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'Nothing in "$_filter"',
                    message: 'Try another filter.',
                    actionLabel: 'Show all',
                    onAction: () => setState(() => _filter = _all),
                  ),
                ],
              );
            }

            // Grouped headers only make sense on the unfiltered, date-sorted
            // view; a filtered list is already one bucket.
            final grouped = _filter == _all && _sort == SortOrder.dueDate;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                96,
              ),
              children: grouped
                  ? [
                      _group('Overdue', b.overdue, AppColors.danger),
                      _group('Today', b.today, AppColors.warning),
                      _group('Upcoming', b.upcoming, null),
                      _group('No due date', b.noDate, null),
                    ]
                  : [
                      for (final t in tasks) ...[
                        TaskRow(task: t, onToggle: (v) => _toggle(t, v)),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
            );
          },
        ),
      ),
    );
  }

  Widget _group(String title, List<Task> tasks, Color? accent) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              if (accent != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                '${title.toUpperCase()} · ${tasks.length}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontSize: 11, letterSpacing: 0.7),
              ),
            ],
          ),
        ),
        for (final task in tasks) ...[
          TaskRow(task: task, onToggle: (v) => _toggle(task, v)),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
