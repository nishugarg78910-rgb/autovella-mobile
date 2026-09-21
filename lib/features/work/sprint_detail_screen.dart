import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/common.dart';
import '../../models/work.dart';
import '../../core/widgets/charts.dart';
import 'widgets/task_row.dart';
import 'work_providers.dart';

/// Sprint detail — where the sprint stands, and what is still open.
class SprintDetailScreen extends ConsumerWidget {
  const SprintDetailScreen({super.key, required this.sprintId});

  final String sprintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sprint = ref.watch(sprintProvider(sprintId));
    final tasks = ref.watch(sprintTasksProvider(sprintId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sprint')),
      body: AsyncView<Sprint>(
        value: sprint,
        onRetry: () => ref.invalidate(sprintProvider(sprintId)),
        data: (s) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sprintProvider(sprintId));
            ref.invalidate(sprintTasksProvider(sprintId));
            await ref.read(sprintTasksProvider(sprintId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.xxxl,
            ),
            children: [
              Text(
                s.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              if (s.goal != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(s.goal!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (s.isActive)
                    const ToneChip(
                      Tone('Active', AppColors.success, AppColors.successSoft),
                    )
                  else
                    ToneChip.status(s.status),
                  const Spacer(),
                  if (s.endDate != null)
                    Text(
                      s.isActive
                          ? '${s.daysRemaining} days left'
                          : 'Ended ${Fmt.date(s.endDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Progress', style: theme.textTheme.titleSmall),
                        const Spacer(),
                        Text(
                          Fmt.percent(s.completion),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ProgressRail(value: s.completion, height: 8),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${s.taskDone} of ${s.taskTotal} tasks'
                      '${s.pointsTotal > 0 ? ' · ${s.pointsDone}/${s.pointsTotal} points' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Committed',
                      value: s.pointsTotal > 0
                          ? '${s.pointsTotal} pts'
                          : '${s.taskTotal}',
                      icon: Icons.flag_outlined,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      label: 'Completed',
                      value: s.pointsTotal > 0
                          ? '${s.pointsDone} pts'
                          : '${s.taskDone}',
                      icon: Icons.task_alt_rounded,
                      accent: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    DetailRow(
                      label: 'Starts',
                      icon: Icons.play_arrow_rounded,
                      value: Fmt.fullDate(s.startDate),
                    ),
                    DetailRow(
                      label: 'Ends',
                      icon: Icons.event_outlined,
                      value: Fmt.fullDate(s.endDate),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              tasks.when(
                loading: () =>
                    const Skeleton(height: 140, radius: AppRadius.lg),
                error: (_, __) => const SizedBox.shrink(),
                data: (items) => _Breakdown(tasks: items),
              ),

              const SizedBox(height: AppSpacing.xl),
              tasks.when(
                loading: () => const SkeletonList(count: 3),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(sprintTasksProvider(sprintId)),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const AppCard(
                      child: EmptyState(
                        compact: true,
                        icon: Icons.inbox_outlined,
                        title: 'No tasks in this sprint',
                      ),
                    );
                  }
                  final open = items.where((t) => !t.isDone).toList();
                  final done = items.where((t) => t.isDone).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (open.isNotEmpty) ...[
                        SectionLabel('Open · ${open.length}'),
                        for (final t in open) ...[
                          TaskRow(task: t, showProject: false),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                      if (done.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        SectionLabel('Completed · ${done.length}'),
                        for (final t in done) ...[
                          TaskRow(task: t, showProject: false),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the sprint's work sits, by status and by assignee.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final byStatus = <String, int>{};
    final byAssignee = <String, int>{};
    for (final t in tasks) {
      byStatus[Tone.status(t.status).label] =
          (byStatus[Tone.status(t.status).label] ?? 0) + 1;
      if (t.assignees.isEmpty) {
        byAssignee['Unassigned'] = (byAssignee['Unassigned'] ?? 0) + 1;
      }
      for (final u in t.assignees) {
        byAssignee[u.fullName] = (byAssignee[u.fullName] ?? 0) + 1;
      }
    }

    List<BarDatum> rows(Map<String, int> map) =>
        (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .map((e) => BarDatum(label: e.key, value: e.value.toDouble()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('By status'),
        AppCard(child: BarList(rows: rows(byStatus))),
        const SizedBox(height: AppSpacing.md),
        const SectionLabel('By assignee'),
        AppCard(child: BarList(rows: rows(byAssignee))),
      ],
    );
  }
}
