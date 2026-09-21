import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/atoms.dart';
import '../../../models/work.dart';

/// One task in a list.
///
/// Tuned for scanning with a thumb: title first, then only the metadata that
/// changes a decision — due date (red when overdue), project, assignees. The
/// checkbox toggles completion in place so the common action costs one tap
/// rather than a navigation.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    this.onToggle,
    this.showProject = true,
  });

  final Task task;
  final ValueChanged<bool>? onToggle;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final card = _card(context);
    if (onToggle == null) return card;

    // Swipe right to complete. `confirmDismiss` returning false runs the
    // action and springs the row back rather than removing it — the task
    // stays visible, struck through, which is what people expect from a
    // checklist they might immediately un-tick.
    return Dismissible(
      key: ValueKey('task-swipe-${task.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        onToggle!(!task.isDone);
        return false;
      },
      background: _SwipeBackground(done: task.isDone),
      child: card,
    );
  }

  Widget _card(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.isDone;
    final overdue = task.isOverdue;

    return AppCard(
      onTap: () => context.push('/tasks/${task.id}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      accentColor: _projectColor(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, left: 2),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: done,
                onChanged: onToggle == null
                    ? null
                    : (v) {
                        HapticFeedback.selectionClick();
                        onToggle!(v ?? false);
                      },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          color: done
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ),
                    if (task.milestone) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.flag_rounded,
                        size: 14,
                        color: AppColors.warning,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (task.status != null) ToneChip.status(task.status, dense: true),
                    if (task.priority != null &&
                        task.priority!.toLowerCase() != 'medium')
                      ToneChip.priority(task.priority, dense: true),
                    if (task.endDate != null)
                      _Meta(
                        icon: overdue
                            ? Icons.error_outline_rounded
                            : Icons.event_outlined,
                        label: Fmt.friendlyDate(task.endDate),
                        color: overdue ? AppColors.danger : null,
                        emphasise: overdue,
                      ),
                    if (showProject && task.project != null)
                      _Meta(
                        icon: Icons.folder_outlined,
                        label: task.project!.name,
                      ),
                    if (task.storyPoints != null)
                      _Meta(
                        icon: Icons.bolt_outlined,
                        label: '${task.storyPoints} pts',
                      ),
                    if (task.dependencyCount > 0)
                      _Meta(
                        icon: Icons.link_rounded,
                        label: '${task.dependencyCount}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (task.assignees.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AvatarStack(users: task.assignees, size: 24, max: 2),
            ),
          ],
        ],
      ),
    );
  }

  Color? _projectColor() {
    final hex = task.project?.color;
    if (hex == null) return null;
    return _parseHex(hex);
  }
}

/// The green (or grey) panel revealed while swiping a task.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: AppSpacing.xl),
      decoration: BoxDecoration(
        color: done ? AppColors.slate400 : AppColors.success,
        borderRadius: AppRadius.rLg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.undo_rounded : Icons.check_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            done ? 'Reopen' : 'Complete',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon + label metadata pair.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.label,
    this.color,
    this.emphasise = false,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: tint),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: tint,
              fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Parses `#RRGGBB` / `#AARRGGBB` colours as stored on projects.
Color? _parseHex(String? hex) {
  if (hex == null) return null;
  var value = hex.replaceAll('#', '').trim();
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// Shared by project rows and detail headers.
Color? parseProjectColor(String? hex) => _parseHex(hex);
