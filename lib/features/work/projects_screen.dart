import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/common.dart';
import '../../models/work.dart';
import '../auth/auth_controller.dart';
import '../shell/home_shell.dart';
import 'widgets/task_row.dart';
import 'work_providers.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final _searchController = TextEditingController();
  String? _search;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider(_search));
    final canCreate = ref.watch(permissionsProvider).canCreate('projects');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [const NotificationBell(), const SizedBox(width: 4)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search projects',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                suffixIcon: _search != null
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = null);
                        },
                      )
                    : null,
              ),
              onSubmitted: (v) =>
                  setState(() => _search = v.trim().isEmpty ? null : v.trim()),
            ),
          ),
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/projects/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New project'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(projectsProvider(_search));
          await ref.read(projectsProvider(_search).future);
        },
        child: AsyncView<List<Project>>(
          value: projects,
          onRetry: () => ref.invalidate(projectsProvider(_search)),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.folder_open_rounded,
                    title: _search == null
                        ? 'No projects yet'
                        : 'No projects match "$_search"',
                    message: _search == null
                        ? 'Projects group tasks, sprints, budgets and the '
                            'people delivering the work.'
                        : 'Try a different search term.',
                    actionLabel: _search == null && canCreate
                        ? 'Create a project'
                        : null,
                    onAction: () => context.push('/projects/new'),
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
              itemBuilder: (_, i) => ProjectRow(project: items[i]),
            );
          },
        ),
      ),
    );
  }
}

/// One project in a list — name, health, progress and team at a glance.
class ProjectRow extends StatelessWidget {
  const ProjectRow({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = parseProjectColor(project.color) ?? theme.colorScheme.primary;

    return AppCard(
      onTap: () => context.push('/projects/${project.id}'),
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ToneChip.status(project.status, dense: true),
            ],
          ),
          if (project.account != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.business_outlined,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    project.account!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ProgressRail(value: project.progress, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${project.taskDone}/${project.taskTotal}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (project.members.isNotEmpty)
                AvatarStack(
                  users: project.members
                      .map((m) => m.user)
                      .whereType<UserRef>()
                      .toList(),
                  size: 24,
                  max: 3,
                ),
              const Spacer(),
              if (project.budget != null) ...[
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  Fmt.moneyShort(project.budget, currency: project.currency),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              if (project.dueDate != null)
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 13,
                      color: project.isOverdue
                          ? AppColors.danger
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Fmt.date(project.dueDate),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            project.isOverdue ? FontWeight.w700 : FontWeight.w500,
                        color: project.isOverdue
                            ? AppColors.danger
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
