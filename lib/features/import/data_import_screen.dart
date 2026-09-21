import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/util/json.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/contact_actions.dart';
import '../../core/widgets/states.dart';

/// A past import run.
class ImportRun {
  const ImportRun({
    required this.id,
    required this.entityType,
    this.status,
    this.fileName,
    this.total = 0,
    this.succeeded = 0,
    this.failed = 0,
    this.at,
    this.by,
  });

  final String id;
  final String entityType;
  final String? status;
  final String? fileName;
  final int total;
  final int succeeded;
  final int failed;
  final DateTime? at;
  final String? by;

  double get successRate => total == 0 ? 0 : succeeded / total;

  factory ImportRun.fromJson(Map<String, dynamic> json) => ImportRun(
        id: J.str(json['id']),
        entityType: J.str(
          J.pick(json, ['entityType', 'type', 'resource', 'module']),
          'records',
        ),
        status: J.strOrNull(json['status']),
        fileName: J.strOrNull(J.pick(json, ['fileName', 'filename', 'file'])),
        total: J.intVal(J.pick(json, ['total', 'totalRows', 'rowCount'])),
        succeeded: J.intVal(
          J.pick(json, ['succeeded', 'imported', 'successCount', 'created']),
        ),
        failed: J.intVal(J.pick(json, ['failed', 'errors', 'errorCount'])),
        at: J.date(J.pick(json, ['createdAt', 'startedAt', 'completedAt'])),
        by: J.strOrNull(J.pick(json, ['userName', 'createdByName'])),
      );
}

final importRunsProvider =
    FutureProvider.autoDispose<List<ImportRun>>((ref) async {
  try {
    final data = await ref.watch(apiClientProvider).get(
          Api.dataImport,
          query: {'limit': 30},
        );
    return J.maps(ApiClient.asList(data)).map(ImportRun.fromJson).toList();
  } catch (_) {
    // The endpoint may not expose a history; the page is still useful.
    return const [];
  }
});

/// What can be imported, and where each kind lands.
class _Importable {
  const _Importable(this.label, this.icon, this.description, this.route);

  final String label;
  final IconData icon;
  final String description;
  final String? route;
}

const _importables = [
  _Importable('Accounts', Icons.business_outlined,
      'Companies, with industry, size and billing address.', '/accounts'),
  _Importable('Contacts', Icons.person_outline_rounded,
      'People, linked to their account by name or email.', null),
  _Importable('Deals', Icons.handshake_outlined,
      'Pipeline, with stage, amount, currency and close date.', null),
  _Importable('Tasks', Icons.check_circle_outline_rounded,
      'Work items, assigned to a project and an owner.', null),
  _Importable('Holidays', Icons.celebration_rounded,
      'Your holiday calendar, by location.', '/holidays'),
];

/// Data import.
///
/// Bulk CSV import is a desktop job — picking a file, mapping columns and
/// fixing rejected rows is not something anyone wants to do on a phone. What
/// *is* useful on a phone is knowing whether last night's import worked, and
/// what failed. So this shows the run history with its success rate, explains
/// what each import covers, and hands off cleanly to the web importer rather
/// than pretending to do the upload.
class DataImportScreen extends ConsumerWidget {
  const DataImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(importRunsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Data import')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(importRunsProvider);
          await ref.read(importRunsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xxxl,
          ),
          children: [
            AppCard(
              accentColor: theme.colorScheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.upload_file_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Importing is a desktop job',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Uploading a spreadsheet means mapping columns and fixing '
                    'rejected rows — fiddly on a phone. Start the import on the '
                    'web app, then come back here to watch it land.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () =>
                        ContactActions.open(context, '${Api.baseUrl}/import'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('Open the web importer'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('What you can import'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _importables.length; i++) ...[
                    ListTile(
                      leading: Icon(
                        _importables[i].icon,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        _importables[i].label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        _importables[i].description,
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: _importables[i].route == null
                          ? null
                          : const Icon(Icons.chevron_right_rounded, size: 19),
                      onTap: _importables[i].route == null
                          ? null
                          : () => context.push(_importables[i].route!),
                    ),
                    if (i < _importables.length - 1)
                      Divider(
                        height: 1,
                        indent: 56,
                        color: theme.colorScheme.outline,
                      ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Recent imports'),
            runs.when(
              loading: () => const Skeleton(height: 90, radius: AppRadius.lg),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) {
                if (items.isEmpty) {
                  return const AppCard(
                    child: EmptyState(
                      compact: true,
                      icon: Icons.history_rounded,
                      title: 'No imports yet',
                      message: 'Runs started on the web app will show up here '
                          'with their results.',
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final run in items) ...[
                      _RunCard(run: run),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final ImportRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFailures = run.failed > 0;

    return AppCard(
      accentColor: hasFailures ? AppColors.warning : AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  run.fileName ?? '${run.entityType} import',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              ToneChip.status(run.status ?? (hasFailures ? 'partial' : 'done'),
                  dense: true),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              run.entityType,
              if (run.by != null) run.by!,
              Fmt.relative(run.at),
            ].where((e) => e.isNotEmpty).join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
          ),
          if (run.total > 0) ...[
            const SizedBox(height: AppSpacing.md),
            ProgressRail(
              value: run.successRate,
              height: 6,
              color: hasFailures ? AppColors.warning : AppColors.success,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${run.succeeded} of ${run.total} rows imported',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
                const Spacer(),
                if (hasFailures)
                  Text(
                    '${run.failed} failed',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
