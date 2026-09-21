import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/quick_create.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/api/endpoints.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/permission_gate.dart';
import '../../core/widgets/states.dart';
import '../../data/repository.dart';
import '../../models/common.dart';
import '../../models/work.dart';
import '../attachments/attachments.dart';
import '../auth/auth_controller.dart';
import 'work_providers.dart';

/// Task detail.
///
/// The web app shows this as a wide two-pane modal. On a phone it becomes a
/// single scroll: what the task *is* up top, then its checklist, then the
/// conversation — with the two actions people actually take (change status,
/// comment) pinned within thumb reach.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskProvider(taskId));
    final perms = ref.watch(permissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: [
          if (task.hasValue)
            ShareButton(
              title: task.requireValue.title,
              path: '/tasks/$taskId',
              subtitle: task.requireValue.project?.name,
            ),
          if (perms.canUpdate('tasks'))
            IconButton(
              onPressed: () => context.push('/tasks/$taskId/edit'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
            ),
          PopupMenuButton<String>(
            onSelected: (value) => _onMenu(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'copy', child: Text('Copy link')),
              if (perms.canDelete('tasks'))
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete task'),
                ),
            ],
          ),
        ],
      ),
      body: AsyncView<Task>(
        value: task,
        onRetry: () => ref.invalidate(taskProvider(taskId)),
        data: (t) => _Body(task: t),
      ),
      bottomNavigationBar: task.hasValue
          ? _ActionBar(task: task.requireValue)
          : null,
    );
  }

  void _onMenu(BuildContext context, WidgetRef ref, String value) async {
    if (value == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete this task?'),
          content: const Text(
            'It will be moved to the recycle bin, where it can be restored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      try {
        await ref.read(taskRepoProvider).remove(taskId);
        ref.invalidate(myTasksProvider);
        if (context.mounted) {
          showToast(context, 'Task deleted');
          context.pop();
        }
      } on ApiException catch (e) {
        if (context.mounted) showToast(context, e.message, isError: true);
      }
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtasks = ref.watch(subtasksProvider(task.id));
    final comments = ref.watch(taskCommentsProvider(task.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xxxl,
      ),
      children: [
        Text(
          task.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ToneChip.status(task.status),
            if (task.priority != null) ToneChip.priority(task.priority),
            if (task.milestone)
              const ToneChip(
                Tone('Milestone', AppColors.warning, AppColors.warningSoft),
                icon: Icons.flag_rounded,
              ),
            if (task.isBillable)
              const ToneChip(
                Tone('Billable', AppColors.success, AppColors.successSoft),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        if ((task.description ?? '').trim().isNotEmpty) ...[
          const SectionLabel('Description'),
          AppCard(
            // Descriptions are authored in the web app's Quill editor and
            // arrive as HTML, so they are rendered, not printed as markup.
            child: HtmlWidget(
              task.description!,
              textStyle: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        const SectionLabel('Details'),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              if (task.project != null)
                DetailRow(
                  label: 'Project',
                  icon: Icons.folder_outlined,
                  child: GestureDetector(
                    onTap: () => context.push('/projects/${task.project!.id}'),
                    child: Text(
                      task.project!.name,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (task.sprint != null)
                DetailRow(
                  label: 'Sprint',
                  icon: Icons.directions_run_rounded,
                  value: task.sprint!.name,
                ),
              DetailRow(
                label: 'Assignees',
                icon: Icons.people_outline_rounded,
                child: task.assignees.isEmpty
                    ? const Text('Unassigned')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final u in task.assignees)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Avatar.user(u, size: 22),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                    child: Text(
                                      u.fullName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              DetailRow(
                label: 'Start',
                icon: Icons.play_arrow_rounded,
                value: Fmt.fullDate(task.startDate),
              ),
              DetailRow(
                label: 'Due',
                icon: Icons.event_outlined,
                child: Text(
                  Fmt.fullDate(task.endDate),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: task.isOverdue ? AppColors.danger : null,
                  ),
                ),
              ),
              if (task.estimatedHours != null || task.actualHours != null)
                GuardedRow(
                  module: 'tasks',
                  field: 'actualHours',
                  label: 'Effort',
                  icon: Icons.timer_outlined,
                  value: '${Fmt.hours(task.actualHours)} logged'
                      '${task.estimatedHours != null ? ' of ${Fmt.hours(task.estimatedHours)}' : ''}',
                ),
              if (task.storyPoints != null)
                GuardedRow(
                  module: 'tasks',
                  field: 'storyPoints',
                  label: 'Story points',
                  icon: Icons.bolt_outlined,
                  value: '${task.storyPoints}',
                ),
              if (task.tags.isNotEmpty)
                DetailRow(
                  label: 'Tags',
                  icon: Icons.label_outline_rounded,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in task.tags)
                        Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ),
              DetailRow(
                label: 'Created',
                icon: Icons.schedule_rounded,
                value: task.createdBy == null
                    ? Fmt.date(task.createdAt)
                    : '${Fmt.date(task.createdAt)} by ${task.createdBy!.fullName}',
              ),
            ],
          ),
        ),

        if (task.customFields?.isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('Custom fields'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                for (final entry in task.customFields!.entries)
                  DetailRow(
                    label: entry.key,
                    value: '${entry.value}'.isEmpty ? '—' : '${entry.value}',
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        subtasks.when(
          loading: () => const Skeleton(height: 60, radius: AppRadius.lg),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(
                      'Checklist · '
                      '${items.where((s) => s.completed).length}/${items.length}',
                    ),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        children: [
                          for (final sub in items)
                            CheckboxListTile(
                              value: sub.completed,
                              dense: true,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              title: Text(
                                sub.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: sub.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: sub.completed
                                      ? theme.colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                              onChanged: (_) =>
                                  _toggleSubtask(context, ref, sub),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
        ),

        AttachmentsSection(
          entityType: 'task',
          entityId: task.id,
          canUpload: ref.watch(permissionsProvider).canUpdate('tasks'),
        ),
        const SizedBox(height: AppSpacing.xl),

        const SectionLabel('Activity'),
        comments.when(
          loading: () => const Skeleton(height: 80, radius: AppRadius.lg),
          error: (_, __) => const AppCard(
            child: Text('Comments are unavailable right now.'),
          ),
          data: (items) => items.isEmpty
              ? const AppCard(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.forum_outlined,
                    title: 'No comments yet',
                    message: 'Be the first to add context to this task.',
                  ),
                )
              : Column(
                  children: [
                    for (final c in items) ...[
                      _CommentTile(comment: c),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _toggleSubtask(
    BuildContext context,
    WidgetRef ref,
    Subtask sub,
  ) async {
    try {
      await ref.read(apiTogglerProvider)(sub.id);
      ref.invalidate(subtasksProvider(task.id));
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, isError: true);
    }
  }
}

/// Subtask completion has its own endpoint rather than a PUT, so it gets a
/// tiny dedicated provider instead of going through the generic repo.
final apiTogglerProvider = Provider<Future<void> Function(String)>((ref) {
  final repo = ref.watch(subtaskRepoProvider);
  return (id) async => repo.update(id, {'toggle': true});
});

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = comment.author;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (author != null) Avatar.user(author, size: 26),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  author?.fullName ?? 'Someone',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                Fmt.relative(comment.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          HtmlWidget(comment.body, textStyle: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Pinned bar: change status, or add a comment.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    if (!perms.canUpdate('tasks')) return const SizedBox.shrink();

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _changeStatus(context, ref),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Status'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _logTime(context, ref),
              icon: const Icon(Icons.timer_outlined, size: 18),
              label: const Text('Log'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _addComment(context, ref),
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: const Text('Comment'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref) async {
    // Organisations define their own statuses; these are the platform
    // defaults, shown when a project has no custom board.
    const options = ['todo', 'in_progress', 'in_review', 'blocked', 'done'];

    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Move task to',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final status in options)
              ListTile(
                leading: ToneChip.status(status),
                title: const SizedBox.shrink(),
                trailing: task.status == status
                    ? const Icon(Icons.check_rounded, size: 20)
                    : null,
                onTap: () => Navigator.pop(context, status),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (picked == null || !context.mounted) return;
    try {
      await ref.read(taskRepoProvider).update(task.id, {'status': picked});
      ref.invalidate(taskProvider(task.id));
      ref.invalidate(myTasksProvider);
      if (context.mounted) showToast(context, 'Status updated');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, isError: true);
    }
  }

  /// Logs time straight onto this task, without hunting for it in the
  /// timesheet module — the moment you finish a task is when you remember
  /// how long it took.
  Future<void> _logTime(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final hours = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Log time',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Hours',
                    hintText: '1.5',
                    suffixText: 'h',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final preset in [0.5, 1, 2, 4, 8])
                      ActionChip(
                        label: Text('${preset}h'),
                        onPressed: () =>
                            Navigator.pop(context, preset.toDouble()),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    double.tryParse(controller.text.trim()),
                  ),
                  child: const Text('Log time'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (hours == null || hours <= 0 || !context.mounted) return;
    try {
      final sent = await ref.read(offlineQueueProvider.notifier).send(
        method: 'POST',
        path: Api.timesheets,
        label: 'Log ${Fmt.hours(hours)} on ${task.title}',
        body: {
          'taskId': task.id,
          if (task.projectId != null) 'projectId': task.projectId,
          'hours': hours,
          'date': Fmt.apiDate(DateTime.now()),
          'isBillable': task.isBillable,
        },
      );
      ref.invalidate(taskProvider(task.id));
      if (context.mounted) {
        showToast(
          context,
          sent ? 'Logged ${Fmt.hours(hours)}' : 'Queued — will send when online',
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, isError: true);
    }
  }

  Future<void> _addComment(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add a comment',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Write an update…',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: const Text('Post comment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (text == null || text.isEmpty || !context.mounted) return;
    try {
      await ref.read(commentRepoProvider).create({
        'taskId': task.id,
        'entityType': 'task',
        'entityId': task.id,
        // The web editor stores HTML, so plain input is wrapped to match.
        'body': '<p>$text</p>',
        'content': '<p>$text</p>',
      });
      ref.invalidate(taskCommentsProvider(task.id));
      if (context.mounted) showToast(context, 'Comment added');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, isError: true);
    }
  }
}
