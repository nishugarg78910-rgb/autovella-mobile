import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/quick_create.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/common.dart';
import '../../models/work.dart';
import 'widgets/task_row.dart';
import 'work_providers.dart';

/// Project detail, as four tabs.
///
/// The web version puts Overview, Board, Gantt, Sprints, Files and Team on
/// one wide canvas. A phone gets the four that are legible at this width;
/// Gantt is explicitly not among them — a dependency chart on a 390pt screen
/// is unreadable, so it deep-links to the web app instead of shipping a
/// version nobody can use.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));

    return AsyncView<Project>(
      value: project,
      onRetry: () => ref.invalidate(projectProvider(projectId)),
      loading: const Scaffold(body: SkeletonList()),
      data: (p) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Text(p.name, overflow: TextOverflow.ellipsis),
            actions: [
              ShareButton(
                title: p.name,
                path: '/projects/$projectId',
                subtitle: p.account?.name,
              ),
              IconButton(
                onPressed: () => context.push('/projects/$projectId/edit'),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit project',
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Tasks'),
                Tab(text: 'Sprints'),
                Tab(text: 'Team'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.push('/tasks/new?projectId=$projectId'),
            child: const Icon(Icons.add_rounded),
          ),
          body: TabBarView(
            children: [
              _Overview(project: p),
              _TasksTab(projectId: projectId),
              _SprintsTab(projectId: projectId),
              _TeamTab(project: p),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        parseProjectColor(project.color) ?? theme.colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        Row(
          children: [
            ToneChip.status(project.status),
            const SizedBox(width: AppSpacing.sm),
            if (project.priority != null) ToneChip.priority(project.priority),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    Fmt.percent(project.progress),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ProgressRail(value: project.progress, color: accent, height: 8),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${project.taskDone} of ${project.taskTotal} tasks complete',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (project.budget != null) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Budget', style: theme.textTheme.titleSmall),
                    Text(
                      '${Fmt.moneyShort(project.budgetSpent ?? 0, currency: project.currency)}'
                      ' / ${Fmt.moneyShort(project.budget, currency: project.currency)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ProgressRail(
                  value: project.budgetUsed,
                  height: 8,
                  // Turns red once spend passes 90% of budget.
                  color: project.budgetUsed > 0.9
                      ? AppColors.danger
                      : AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              if (project.account != null)
                DetailRow(
                  label: 'Client',
                  icon: Icons.business_outlined,
                  value: project.account!.name,
                ),
              DetailRow(
                label: 'Owner',
                icon: Icons.person_outline_rounded,
                value: project.owner?.fullName,
              ),
              DetailRow(
                label: 'Start',
                icon: Icons.play_arrow_rounded,
                value: Fmt.fullDate(project.startDate),
              ),
              DetailRow(
                label: 'Due',
                icon: Icons.event_outlined,
                child: Text(
                  Fmt.fullDate(project.dueDate),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: project.isOverdue ? AppColors.danger : null,
                  ),
                ),
              ),
              if (project.team != null)
                DetailRow(
                  label: 'Team',
                  icon: Icons.groups_outlined,
                  value: project.team!.name,
                ),
            ],
          ),
        ),
        if ((project.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('About'),
          AppCard(
            child: HtmlWidget(
              project.description!,
              textStyle: theme.textTheme.bodyMedium,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: () => _openGanttOnWeb(context),
          icon: const Icon(Icons.timeline_rounded, size: 18),
          label: const Text('View Gantt on web'),
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  void _openGanttOnWeb(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gantt is a desktop view'),
        content: const Text(
          'Dependency charts need width to be readable. Open this project at '
          'autovella.cloud on a larger screen to work with the Gantt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(projectTasksProvider(projectId));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(projectTasksProvider(projectId));
        await ref.read(projectTasksProvider(projectId).future);
      },
      child: AsyncView<List<Task>>(
        value: tasks,
        onRetry: () => ref.invalidate(projectTasksProvider(projectId)),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 60),
                EmptyState(
                  icon: Icons.checklist_rounded,
                  title: 'No tasks in this project',
                  message: 'Add the first task to get the work moving.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              96,
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, i) =>
                TaskRow(task: items[i], showProject: false),
          );
        },
      ),
    );
  }
}

class _SprintsTab extends ConsumerWidget {
  const _SprintsTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sprints = ref.watch(sprintsProvider(projectId));
    return AsyncView<List<Sprint>>(
      value: sprints,
      onRetry: () => ref.invalidate(sprintsProvider(projectId)),
      data: (items) {
        if (items.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 60),
              EmptyState(
                icon: Icons.directions_run_rounded,
                title: 'No sprints yet',
                message: 'Sprints group work into time-boxed iterations.',
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            96,
          ),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) => SprintRow(sprint: items[i]),
        );
      },
    );
  }
}

/// A sprint row, reused by the standalone Sprints module.
class SprintRow extends StatelessWidget {
  const SprintRow({super.key, required this.sprint});

  final Sprint sprint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push('/sprints/${sprint.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sprint.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (sprint.isActive)
                const ToneChip(
                  Tone('Active', AppColors.success, AppColors.successSoft),
                  dense: true,
                )
              else
                ToneChip.status(sprint.status, dense: true),
            ],
          ),
          if (sprint.goal != null) ...[
            const SizedBox(height: 4),
            Text(
              sprint.goal!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ProgressRail(value: sprint.completion),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${sprint.taskDone}/${sprint.taskTotal} tasks',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
              ),
              const Spacer(),
              if (sprint.endDate != null)
                Text(
                  sprint.isActive
                      ? '${sprint.daysRemaining}d left'
                      : Fmt.date(sprint.endDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamTab extends StatelessWidget {
  const _TeamTab({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    if (project.members.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'No one assigned yet',
        message: 'Project members and their rates appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        96,
      ),
      itemCount: project.members.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        final member = project.members[i];
        final user = member.user;
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              if (user != null) Avatar.user(user, size: 38),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Member',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (user?.role != null)
                      Text(
                        user!.role!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (member.access != null)
                ToneChip(
                  Tone(
                    member.access!,
                    AppColors.slate600,
                    AppColors.slate100,
                  ),
                  dense: true,
                ),
            ],
          ),
        );
      },
    );
  }
}
