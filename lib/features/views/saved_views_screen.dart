import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/json.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/common.dart';
import '../../models/filter_spec.dart';
import '../../models/work.dart';
import '../work/widgets/task_row.dart';

/// Entities that can carry a saved view. `/saved-views` rejects a request
/// with no `entityType`, so each is fetched explicitly.
const _entities = ['tasks', 'projects', 'accounts', 'contacts', 'deals'];

final savedViewsProvider =
    FutureProvider.autoDispose<List<SavedView>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final out = <SavedView>[];
  for (final entity in _entities) {
    try {
      final data = await api.get(
        Api.savedViews,
        query: {'entityType': entity},
      );
      out.addAll(
        J.maps(ApiClient.asList(data)).map(SavedView.fromJson),
      );
    } catch (_) {
      // One unsupported entity must not empty the list.
    }
  }
  return out;
});

class SavedViewsScreen extends ConsumerWidget {
  const SavedViewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(savedViewsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved views')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(savedViewsProvider);
          await ref.read(savedViewsProvider.future);
        },
        child: AsyncView<List<SavedView>>(
          value: views,
          onRetry: () => ref.invalidate(savedViewsProvider),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: 'No saved views',
                    message: 'Filters you save on the web app appear here, '
                        'and open the matching records when tapped.',
                  ),
                ],
              );
            }

            final byEntity = <String, List<SavedView>>{};
            for (final v in items) {
              byEntity.putIfAbsent(v.entityType, () => []).add(v);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              children: [
                for (final entry in byEntity.entries) ...[
                  SectionLabel('${entry.key} · ${entry.value.length}'),
                  for (final view in entry.value) ...[
                    _ViewCard(view: view),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Views for tasks open here. Views for other entities show '
                  'their filter, and open on the web app.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ViewCard extends StatelessWidget {
  const _ViewCard({required this.view});

  final SavedView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final openable = view.entityType == 'tasks';

    return AppCard(
      onTap: openable
          ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SavedViewResultsScreen(view: view),
                ),
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bookmark_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(view.name, style: theme.textTheme.titleSmall),
              ),
              if (view.isDefault)
                const ToneChip(
                  Tone('Default', AppColors.success, AppColors.successSoft),
                  dense: true,
                ),
              if (openable)
                const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
          if (view.filter.conditions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in view.filter.conditions)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.rSm,
                    ),
                    child: Text(
                      c.describe(),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              view.filter.match.toLowerCase() == 'any'
                  ? 'Matches any of these'
                  : 'Matches all of these',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text('No filters — shows everything',
                style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class SavedViewResultsScreen extends ConsumerStatefulWidget {
  const SavedViewResultsScreen({super.key, required this.view});

  final SavedView view;

  @override
  ConsumerState<SavedViewResultsScreen> createState() =>
      _SavedViewResultsScreenState();
}

class _SavedViewResultsScreenState
    extends ConsumerState<SavedViewResultsScreen> {
  late Future<List<Task>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Task>> _load() async {
    final data = await ref.read(apiClientProvider).get(
          Api.tasks,
          query: {'limit': 100},
        );
    return J
        .maps(ApiClient.asList(data))
        .where(widget.view.filter.matches)
        .map(Task.fromJson)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.view.name),
        bottom: widget.view.filter.conditions.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(34),
                child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(
                      left: AppSpacing.gutter,
                      bottom: AppSpacing.sm,
                    ),
                    children: [
                      for (final c in widget.view.filter.conditions)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            label: Text(c.describe()),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      body: FutureBuilder<List<Task>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snapshot.hasError) {
            return ErrorView(
              error: snapshot.error!,
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final tasks = snapshot.data ?? const <Task>[];
          if (tasks.isEmpty) {
            return const EmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: 'Nothing matches this view',
              message: 'No tasks currently meet every condition.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              children: [
                Text(
                  '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final t in tasks) ...[
                  TaskRow(task: t),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
