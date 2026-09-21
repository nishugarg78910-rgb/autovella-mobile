import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/json.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';

/// A person in the organisation directory.
class Person {
  const Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.position,
    this.role,
    this.team,
    this.isActive = true,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;

  /// Job title, e.g. "Frontend Developer".
  final String? position;

  /// Access role, e.g. "admin".
  final String? role;
  final String? team;
  final bool isActive;

  String get fullName {
    final n = '$firstName $lastName'.trim();
    return n.isEmpty ? (email ?? 'Unknown') : n;
  }

  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    final s = fullName;
    return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    var first = J.str(json['firstName']);
    var last = J.str(json['lastName']);
    // The directory may answer a single `name` instead of a split pair.
    if (first.isEmpty && last.isEmpty) {
      final whole = J.str(J.pick(json, ['name', 'fullName'])).trim();
      if (whole.isNotEmpty) {
        final parts = whole.split(RegExp(r'\s+'));
        first = parts.first;
        last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    }
    return Person(
      id: J.str(json['id']),
      firstName: first,
      lastName: last,
      email: J.strOrNull(json['email']),
      position: J.strOrNull(
        J.pick(json, ['position', 'jobTitle', 'title', 'designation', 'role']),
      ),
      role: J.strOrNull(J.pick(json, ['accessRole', 'roleName', 'role'])),
      team: J.strOrNull(J.pick(json, ['team', 'teamName', 'department'])),
      isActive: J.boolVal(json['isActive'], true),
    );
  }
}

/// The people directory.
///
/// Deliberately hits `/auth/users/directory` rather than `/auth/users`: the
/// latter embeds every user's avatar as a base64 data URI — roughly 190 KB
/// per person, so a 100-row page is ~19 MB. That is why this screen used to
/// show nothing; the request never realistically completed on a phone.
final peopleProvider =
    FutureProvider.autoDispose.family<List<Person>, String?>((ref, search) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get(
    Api.usersDirectory,
    query: {'limit': 200, if (search != null && search.isNotEmpty) 'search': search},
  );
  return J.maps(_rows(data)).map(Person.fromJson).toList();
});

dynamic _rows(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    for (final key in const ['users', 'items', 'results', 'rows', 'data']) {
      if (data[key] is List) return data[key];
    }
  }
  return const [];
}

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final _controller = TextEditingController();
  String? _search;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleProvider(_search));

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
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
              controller: _controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search people',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search != null
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _controller.clear();
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
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(peopleProvider(_search));
          await ref.read(peopleProvider(_search).future);
        },
        child: AsyncView<List<Person>>(
          value: people,
          onRetry: () => ref.invalidate(peopleProvider(_search)),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: _search == null
                        ? 'No people yet'
                        : 'No one matches "$_search"',
                    message: 'Everyone in your organisation appears here.',
                  ),
                ],
              );
            }

            final active = items.where((p) => p.isActive).toList();
            final inactive = items.where((p) => !p.isActive).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              children: [
                SectionLabel('Active · ${active.length}'),
                for (final p in active) ...[
                  _PersonRow(person: p),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (inactive.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SectionLabel('Deactivated · ${inactive.length}'),
                  for (final p in inactive) ...[
                    _PersonRow(person: p, dimmed: true),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, this.dimmed = false});

  final Person person;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Avatar(initials: person.initials, size: 42),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (person.position != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      person.position!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (person.email != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            person.email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (person.team != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: ToneChip.status(person.team, dense: true),
              ),
          ],
        ),
      ),
    );
  }
}
