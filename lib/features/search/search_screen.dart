import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/json.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';

/// A single hit from the cross-module search endpoint.
class SearchHit {
  const SearchHit({
    required this.id,
    required this.title,
    required this.type,
    this.subtitle,
  });

  final String id;
  final String title;
  final String type;
  final String? subtitle;

  IconData get icon => switch (type) {
        'task' => Icons.check_circle_outline_rounded,
        'project' => Icons.folder_outlined,
        'deal' => Icons.handshake_outlined,
        'account' => Icons.business_outlined,
        'contact' => Icons.person_outline_rounded,
        'invoice' => Icons.receipt_long_rounded,
        _ => Icons.description_outlined,
      };

  String? get route => switch (type) {
        'task' => '/tasks/$id',
        'project' => '/projects/$id',
        'deal' => '/deals/$id',
        'account' => '/accounts/$id',
        'contact' => '/contacts/$id',
        _ => null,
      };
}

final searchProvider =
    FutureProvider.autoDispose.family<List<SearchHit>, String>((ref, q) async {
  if (q.trim().length < 2) return const [];
  final data = await ref.watch(apiClientProvider).get(
        Api.search,
        query: {'q': q, 'query': q, 'search': q, 'limit': 40},
      );

  final hits = <SearchHit>[];

  void absorb(dynamic rows, String type) {
    for (final row in J.maps(rows)) {
      final id = J.str(row['id']);
      if (id.isEmpty) continue;
      final name = J.strOrNull(J.pick(row, ['title', 'name'])) ??
          '${J.str(row['firstName'])} ${J.str(row['lastName'])}'.trim();
      hits.add(
        SearchHit(
          id: id,
          title: name.isEmpty ? 'Untitled' : name,
          type: J.strOrNull(row['type']) ?? type,
          subtitle: J.strOrNull(
            J.pick(row, ['description', 'email', 'status', 'stage']),
          ),
        ),
      );
    }
  }

  // The endpoint may answer a flat list or a map keyed by module.
  if (data is List) {
    absorb(data, 'record');
  } else {
    final map = J.map(data);
    for (final entry in map.entries) {
      if (entry.value is List) {
        // "tasks" -> "task"
        final type = entry.key.endsWith('s')
            ? entry.key.substring(0, entry.key.length - 1)
            : entry.key;
        absorb(entry.value, type);
      }
    }
  }

  return hits;
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search tasks, projects, deals…',
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
          onSubmitted: (v) => setState(() => _query = v.trim()),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.trim().length < 2
          ? const EmptyState(
              icon: Icons.search_rounded,
              title: 'Search Autovella',
              message: 'Find tasks, projects, deals, accounts and contacts '
                  'across the whole platform.',
            )
          : AsyncView<List<SearchHit>>(
              value: results,
              onRetry: () => ref.invalidate(searchProvider(_query)),
              data: (hits) => hits.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matches for "$_query"',
                      message: 'Try a shorter or different term.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.gutter),
                      itemCount: hits.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final hit = hits[i];
                        return AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          onTap: hit.route == null
                              ? null
                              : () => context.push(hit.route!),
                          child: Row(
                            children: [
                              Icon(
                                hit.icon,
                                size: 19,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hit.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      hit.subtitle ?? hit.type,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
