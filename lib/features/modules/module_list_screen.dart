import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/common.dart';

/// Describes a module that has no bespoke screen of its own.
class ModuleSpec {
  const ModuleSpec({
    required this.title,
    required this.path,
    required this.icon,
    required this.emptyTitle,
    required this.emptyMessage,
    this.limit = 100,
    this.query = const {},
  });

  final String title;

  /// API path, relative to `/api`.
  final String path;
  final IconData icon;
  final String emptyTitle;
  final String emptyMessage;

  /// Page size. Some endpoints embed each actor's avatar as a base64 data URI
  /// (~200 KB a row on audit logs), so those ask for far fewer rows.
  final int limit;

  /// Extra query parameters this endpoint requires.
  final Map<String, dynamic> query;

  // Value equality: this type is a Riverpod family key. Every instance is
  // `const` today, so identity would happen to work — but a non-const one
  // would silently create a new provider on every rebuild and refetch
  // forever. Defining == removes that trap.
  @override
  bool operator ==(Object other) =>
      other is ModuleSpec &&
      other.path == path &&
      other.title == title &&
      other.limit == limit &&
      _sameQuery(other.query, query);

  @override
  int get hashCode => Object.hash(path, title, limit, query.length);

  static bool _sameQuery(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Raw rows for a module, fetched straight from its list endpoint.
final moduleRecordsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ModuleSpec>((ref, spec) async {
  final data = await ref.watch(apiClientProvider).get(
        spec.path,
        query: {'limit': spec.limit, ...spec.query},
      );
  if (data is List) return J.maps(data);
  return J.maps(J.pick(J.map(data), ['items', 'results', 'rows', 'records']));
});

/// A working list screen for any module that does not yet justify a bespoke
/// design.
///
/// This is deliberately schema-agnostic: it reads the real endpoint and picks
/// a title, subtitle, status and amount out of whatever field names come
/// back. Autovella's payloads are consistent enough (`name`/`title`,
/// `status`, `amount`, `createdAt`) that this produces a genuinely useful
/// list rather than a placeholder — and each module can graduate to its own
/// screen without changing anything else.
class ModuleListScreen extends ConsumerWidget {
  const ModuleListScreen({super.key, required this.spec});

  final ModuleSpec spec;

  static const _titleKeys = [
    'name',
    'title',
    'label',
    'subject',
    'invoiceNumber',
    'registrationNumber',
    'description',
  ];
  static const _subtitleKeys = [
    'description',
    'summary',
    'email',
    'category',
    'type',
    'code',
    'notes',
  ];
  static const _amountKeys = ['amount', 'total', 'value', 'rate', 'price'];
  static const _dateKeys = ['date', 'createdAt', 'updatedAt', 'dueDate'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(moduleRecordsProvider(spec));

    return Scaffold(
      appBar: AppBar(title: Text(spec.title)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(moduleRecordsProvider(spec));
          await ref.read(moduleRecordsProvider(spec).future);
        },
        child: AsyncView<List<Map<String, dynamic>>>(
          value: records,
          onRetry: () => ref.invalidate(moduleRecordsProvider(spec)),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: spec.icon,
                    title: spec.emptyTitle,
                    message: spec.emptyMessage,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _RecordRow(
                record: items[i],
                icon: spec.icon,
              ),
            );
          },
        ),
      ),
    );
  }

  static String titleOf(Map<String, dynamic> record) {
    for (final key in _titleKeys) {
      final value = J.strOrNull(record[key]);
      if (value != null) return Fmt.plainText(value, max: 80);
    }
    // Some records only carry a person's name in parts.
    final first = J.str(record['firstName']);
    final last = J.str(record['lastName']);
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Record' : name;
  }

  static String? subtitleOf(Map<String, dynamic> record) {
    final title = titleOf(record);
    for (final key in _subtitleKeys) {
      final value = J.strOrNull(record[key]);
      if (value != null) {
        final text = Fmt.plainText(value, max: 90);
        if (text.isNotEmpty && text != title) return text;
      }
    }
    return null;
  }

  static double? amountOf(Map<String, dynamic> record) {
    for (final key in _amountKeys) {
      final value = J.dblOrNull(record[key]);
      if (value != null) return value;
    }
    return null;
  }

  static DateTime? dateOf(Map<String, dynamic> record) {
    for (final key in _dateKeys) {
      final value = J.date(record[key]);
      if (value != null) return value;
    }
    return null;
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.icon});

  final Map<String, dynamic> record;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = ModuleListScreen.titleOf(record);
    final subtitle = ModuleListScreen.subtitleOf(record);
    final amount = ModuleListScreen.amountOf(record);
    final date = ModuleListScreen.dateOf(record);
    final status = J.strOrNull(
      J.pick(record, ['status', 'stage', 'state']),
    );
    final enabled = record['isEnabled'] ?? record['isActive'];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (date != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    Fmt.date(date),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (amount != null)
                Text(
                  Fmt.money(amount, currency: J.strOrNull(record['currency'])),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (status != null) ...[
                if (amount != null) const SizedBox(height: 3),
                ToneChip.status(status, dense: true),
              ] else if (enabled is bool) ...[
                if (amount != null) const SizedBox(height: 3),
                ToneChip(
                  enabled
                      ? const Tone(
                          'Active',
                          AppColors.success,
                          AppColors.successSoft,
                        )
                      : const Tone(
                          'Off',
                          AppColors.slate600,
                          AppColors.slate100,
                        ),
                  dense: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Modules that run on the generic screen.
///
/// Trimmed to routes that exist. Leads, Customers, Vehicles, Inventory and
/// Resources were removed — none of them are endpoints on this platform, so
/// those screens could only ever error.
class Modules {
  const Modules._();

  static const templates = ModuleSpec(
    title: 'Templates',
    path: Api.templates,
    icon: Icons.dashboard_customize_outlined,
    emptyTitle: 'No templates',
    emptyMessage: 'Reusable project and task structures appear here.',
  );
  /// `/saved-views` rejects a request with no `entityType` ("Invalid
  /// entityType"), which is why this screen errored. Tasks is the view people
  /// save most; the others are reachable from their own lists.
  static const savedViews = ModuleSpec(
    title: 'Saved views',
    path: Api.savedViews,
    icon: Icons.bookmark_border_rounded,
    emptyTitle: 'No saved task views',
    emptyMessage: 'Filters you save against Tasks on the web app appear here.',
    query: {'entityType': 'tasks'},
  );
  static const bookmarks = ModuleSpec(
    title: 'Bookmarks',
    path: Api.bookmarks,
    icon: Icons.star_border_rounded,
    emptyTitle: 'No bookmarks',
    emptyMessage: 'Records you star appear here for quick access.',
  );
  static const roles = ModuleSpec(
    title: 'Roles',
    path: Api.roles,
    icon: Icons.admin_panel_settings_outlined,
    emptyTitle: 'No roles defined',
    emptyMessage: 'Roles control what each person can see and change.',
  );
  static const automations = ModuleSpec(
    title: 'Automations',
    path: Api.automations,
    icon: Icons.bolt_rounded,
    emptyTitle: 'No automations',
    emptyMessage: 'Rules that fire on record changes appear here.',
  );
  static const exchangeRates = ModuleSpec(
    title: 'Exchange rates',
    path: Api.exchangeRates,
    icon: Icons.currency_exchange_rounded,
    emptyTitle: 'No exchange rates',
    emptyMessage: 'Rates used to convert multi-currency amounts appear here.',
  );
  static const holidays = ModuleSpec(
    title: 'Holidays',
    path: Api.holidays,
    icon: Icons.celebration_rounded,
    emptyTitle: 'No holidays configured',
    emptyMessage: "Your organisation's holiday calendar appears here.",
  );
  static const sprints = ModuleSpec(
    title: 'Sprints',
    path: Api.sprints,
    icon: Icons.directions_run_rounded,
    emptyTitle: 'No sprints',
    emptyMessage: 'Sprints across all your projects appear here.',
  );
}
