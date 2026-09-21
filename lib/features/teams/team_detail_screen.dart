import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/json.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/contact_actions.dart';
import '../../core/widgets/states.dart';
import '../../data/repository.dart';
import '../../models/common.dart';
import '../../models/org.dart';

final teamsProvider = FutureProvider.autoDispose<List<Team>>(
  (ref) => ref.watch(teamRepoProvider).list(limit: 100),
);

final teamProvider = FutureProvider.autoDispose.family<Team, String>(
  (ref, id) => ref.watch(teamRepoProvider).get(id),
);

/// Members, fetched separately because the team record often carries only a
/// count.
final teamMembersProvider =
    FutureProvider.autoDispose.family<List<UserRef>, String>((ref, id) async {
  try {
    final data = await ref.watch(apiClientProvider).get(Api.teamMembers(id));
    final rows = J.maps(_rows(data));
    return rows
        .map((r) => UserRef.fromJson(r['user']) ?? UserRef.fromJson(r))
        .whereType<UserRef>()
        .toList();
  } catch (_) {
    return const [];
  }
});

dynamic _rows(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    for (final k in const ['members', 'items', 'results', 'data']) {
      if (data[k] is List) return data[k];
    }
  }
  return const [];
}

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(teamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Teams')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teamsProvider);
          await ref.read(teamsProvider.future);
        },
        child: AsyncView<List<Team>>(
          value: teams,
          onRetry: () => ref.invalidate(teamsProvider),
          data: (items) => items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 60),
                    EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'No teams yet',
                      message:
                          'Teams group people for assignment and reporting.',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.md,
                    AppSpacing.gutter,
                    AppSpacing.xxxl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final team = items[i];
                    return AppCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TeamDetailScreen(teamId: team.id),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12),
                              borderRadius: AppRadius.rMd,
                            ),
                            child: Icon(
                              Icons.groups_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  team.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  team.description ??
                                      '${team.memberCount} '
                                          '${team.memberCount == 1 ? 'member' : 'members'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (team.members.isNotEmpty)
                            AvatarStack(users: team.members, size: 24, max: 3),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// Team detail: who is on it, and how to reach them.
class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamProvider(teamId));
    final members = ref.watch(teamMembersProvider(teamId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: AsyncView<Team>(
        value: team,
        onRetry: () => ref.invalidate(teamProvider(teamId)),
        data: (t) {
          final people = members.value ?? t.members;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.xxxl,
            ),
            children: [
              Text(
                t.name,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (t.description != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(t.description!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Members',
                      value: '${people.isEmpty ? t.memberCount : people.length}',
                      icon: Icons.people_alt_rounded,
                    ),
                  ),
                  if (t.lead != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Lead',
                        value: t.lead!.firstName,
                        icon: Icons.star_outline_rounded,
                        accent: AppColors.warning,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionLabel('Members · ${people.length}'),
              if (members.isLoading)
                const Skeleton(height: 80, radius: AppRadius.lg)
              else if (people.isEmpty)
                const AppCard(
                  child: EmptyState(
                    compact: true,
                    icon: Icons.person_off_outlined,
                    title: 'No members yet',
                  ),
                )
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < people.length; i++) ...[
                        _MemberRow(user: people[i]),
                        if (i < people.length - 1)
                          Divider(
                            height: 1,
                            indent: 64,
                            color: theme.colorScheme.outline,
                          ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.user});

  final UserRef user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 4,
      ),
      leading: Avatar.user(user, size: 40),
      title: Text(
        user.fullName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      subtitle: Text(
        [user.role, user.email].where((e) => e != null && e.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: user.email == null
          ? null
          : IconButton(
              tooltip: 'Email',
              icon: const Icon(Icons.mail_outline_rounded, size: 19),
              onPressed: () => ContactActions.email(context, user.email!),
            ),
    );
  }
}
