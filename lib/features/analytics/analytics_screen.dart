import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/states.dart';
import '../../models/common.dart';
import '../../models/crm.dart';
import '../../models/finance.dart';
import '../../models/work.dart';
import '../auth/auth_controller.dart';
import '../dashboard/home_providers.dart';
import '../work/work_providers.dart';

/// A scalar lifted out of an analytics payload.
class Metric {
  const Metric(this.label, this.value, {this.isMoney = false});

  final String label;
  final num value;
  final bool isMoney;

  String get number =>
      isMoney ? Fmt.moneyParts(value).$1 + Fmt.moneyParts(value).$2 : _plain;
  String get unit => isMoney ? Fmt.moneyParts(value).$3 : '';

  String get _plain => value is int || value == value.roundToDouble()
      ? Fmt.number(value)
      : value.toStringAsFixed(1);
}

/// The `/analytics/*` payload shapes are not published and differ per
/// endpoint, so rather than hard-code field names — and show nothing when
/// they do not match — this lifts every scalar out and labels it from its own
/// key.
List<Metric> extractMetrics(dynamic data) {
  final out = <Metric>[];
  void walk(dynamic node, String path, int depth) {
    if (depth > 3 || node is! Map) return;
    node.forEach((key, value) {
      final k = '$key';
      if (const {'id', 'organizationId', 'userId', 'projectId', 'teamId'}
          .contains(k)) {
        return;
      }
      final label = path.isEmpty ? k : '$path · $k';
      if (value is num) {
        out.add(Metric(_humanise(label), value, isMoney: _looksLikeMoney(k)));
      } else if (value is Map) {
        walk(value, label, depth + 1);
      }
    });
  }

  walk(data, '', 0);
  return out;
}

bool _looksLikeMoney(String key) {
  final k = key.toLowerCase();
  return k.contains('amount') ||
      k.contains('revenue') ||
      k.contains('value') ||
      k.contains('cost') ||
      k.contains('budget') ||
      k.contains('billed') ||
      k.contains('outstanding');
}

String _humanise(String key) => key
    .split(' · ')
    .map((part) => part
        .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
        .replaceAll('_', ' ')
        .trim())
    .join(' · ')
    .replaceRange(0, 1, key.isEmpty ? '' : key[0].toUpperCase());

Future<List<Metric>> _fetch(Ref ref, String path) async {
  try {
    return extractMetrics(await ref.watch(apiClientProvider).get(path));
  } catch (_) {
    return const [];
  }
}

final analyticsKpiProvider =
    FutureProvider.autoDispose<List<Metric>>((ref) => _fetch(ref, Api.analyticsKpis));
final analyticsSummaryProvider = FutureProvider.autoDispose<List<Metric>>(
    (ref) => _fetch(ref, Api.analyticsSummary));
final analyticsTeamsProvider = FutureProvider.autoDispose<List<Metric>>(
    (ref) => _fetch(ref, Api.analyticsTeams));

/// Analytics.
///
/// Charting notes: bars are a single hue and directly labelled, so identity
/// comes from the label and colour is not carrying meaning twice. The one
/// place colour *is* semantic — the status breakdown — pairs every segment
/// with its name in the legend, never colour alone. No dual axes anywhere.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(myTasksProvider);
    final projects = ref.watch(projectsProvider(null));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.gutter,
              bottom: AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                user?.organization?.name ?? 'Your organisation',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTasksProvider);
          ref.invalidate(projectsProvider(null));
          ref.invalidate(analyticsKpiProvider);
          ref.invalidate(analyticsSummaryProvider);
          ref.invalidate(analyticsTeamsProvider);
          await ref.read(myTasksProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xxxl,
          ),
          children: [
            tasks.when(
              loading: () => const Skeleton(height: 200, radius: AppRadius.lg),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(myTasksProvider),
              ),
              data: (items) => _DeliveryCard(tasks: items),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _MoneyBlock(),
            _MetricGrid(
              title: 'Key performance',
              metrics: ref.watch(analyticsKpiProvider),
              icon: Icons.speed_rounded,
            ),
            _MetricGrid(
              title: 'Organisation',
              metrics: ref.watch(analyticsSummaryProvider),
              icon: Icons.corporate_fare_rounded,
            ),
            projects.when(
              loading: () => const Skeleton(height: 160, radius: AppRadius.lg),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) => _ProjectHealth(projects: list),
            ),
            _MetricGrid(
              title: 'Teams',
              metrics: ref.watch(analyticsTeamsProvider),
              icon: Icons.groups_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

/// The hero: how much of my work is done, and how it is distributed.
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tasks.isEmpty) {
      return const AppCard(
        child: EmptyState(
          compact: true,
          icon: Icons.insights_rounded,
          title: 'Nothing to measure yet',
          message: 'Once work is assigned to you, delivery shows up here.',
        ),
      );
    }

    final done = tasks.where((t) => t.isDone).length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    final completion = done / tasks.length;
    final logged = tasks.fold<double>(0, (s, t) => s + (t.actualHours ?? 0));
    final estimated =
        tasks.fold<double>(0, (s, t) => s + (t.estimatedHours ?? 0));

    // Semantic segments, each named in the legend — never colour alone.
    final byStatus = <String, int>{};
    for (final t in tasks) {
      final tone = Tone.status(t.status);
      byStatus[tone.label] = (byStatus[tone.label] ?? 0) + 1;
    }
    final segments = byStatus.entries
        .map((e) => BarDatum(
              label: e.key,
              value: e.value.toDouble(),
              color: Tone.status(e.key).fg,
              caption: '${e.value}',
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Delivery'),
        AppCard(
          child: Column(
            // Stretch, so the stacked bar below gets a tight full-width
            // constraint. Under the default centre alignment it shrink-wraps
            // a Row of Expanded children and collapses to nothing.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  MetricRing(
                    value: completion,
                    label: Fmt.percent(completion),
                    caption: 'complete',
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Stat(
                          value: '$done of ${tasks.length}',
                          label: 'tasks delivered',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Stat(
                          value: '$overdue',
                          label: overdue == 1 ? 'task overdue' : 'tasks overdue',
                          color: overdue > 0 ? AppColors.danger : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Stat(
                          value: Fmt.hours(logged),
                          label: estimated > 0
                              ? 'logged of ${Fmt.hours(estimated)} planned'
                              : 'logged',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (segments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Divider(height: 1, color: theme.colorScheme.outline),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Where the work sits',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                StackedBar(segments: segments),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.1,
          ),
        ),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
      ],
    );
  }
}

/// Pipeline and receivables.
class _MoneyBlock extends ConsumerWidget {
  const _MoneyBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(homePipelineProvider).value ?? const <Deal>[];
    final invoices = ref.watch(homeInvoicesProvider).value ?? const <Invoice>[];
    if (deals.isEmpty && invoices.isEmpty) return const SizedBox.shrink();

    final open = deals.where((d) => d.isOpen).toList();
    final won = deals.where((d) => d.isWon).toList();
    final pipeline = open.fold<double>(0, (s, d) => s + (d.amount ?? 0));
    final weighted = open.fold<double>(0, (s, d) => s + d.weightedAmount);
    final wonValue = won.fold<double>(0, (s, d) => s + (d.amount ?? 0));
    final currency = _dominant(deals.map((d) => d.currency));

    final outstanding = invoices
        .where((i) => !i.isPaid && !i.isCancelled)
        .fold<double>(0, (s, i) => s + i.balanceDue);
    final overdueValue =
        invoices.where((i) => i.isOverdue).fold<double>(0, (s, i) => s + i.balanceDue);
    final invCurrency = _dominant(invoices.map((i) => i.currency));

    final winRate = (won.length + deals.where((d) => d.isLost).length) == 0
        ? 0.0
        : won.length / (won.length + deals.where((d) => d.isLost).length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Commercial'),
        if (deals.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Open pipeline',
                  value: Fmt.moneyParts(pipeline, currency: currency).$1 +
                      Fmt.moneyParts(pipeline, currency: currency).$2,
                  unit: Fmt.moneyParts(pipeline, currency: currency).$3,
                  caption: '${open.length} open deals',
                  icon: Icons.trending_up_rounded,
                  accent: AppColors.brandTeal,
                  onTap: () => context.go('/crm'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  label: 'Weighted',
                  value: Fmt.moneyParts(weighted, currency: currency).$1 +
                      Fmt.moneyParts(weighted, currency: currency).$2,
                  unit: Fmt.moneyParts(weighted, currency: currency).$3,
                  caption: 'by probability',
                  icon: Icons.percent_rounded,
                  progress: pipeline > 0 ? weighted / pipeline : 0,
                  accent: AppColors.brandViolet,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Won',
                  value: Fmt.moneyParts(wonValue, currency: currency).$1 +
                      Fmt.moneyParts(wonValue, currency: currency).$2,
                  unit: Fmt.moneyParts(wonValue, currency: currency).$3,
                  caption: '${won.length} deals',
                  icon: Icons.emoji_events_outlined,
                  accent: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  label: 'Win rate',
                  value: Fmt.percent(winRate),
                  caption: 'of closed deals',
                  icon: Icons.flag_outlined,
                  progress: winRate,
                  accent: AppColors.success,
                ),
              ),
            ],
          ),
        ],
        if (invoices.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Outstanding',
                  value: Fmt.moneyParts(outstanding, currency: invCurrency).$1 +
                      Fmt.moneyParts(outstanding, currency: invCurrency).$2,
                  unit: Fmt.moneyParts(outstanding, currency: invCurrency).$3,
                  caption: 'awaiting payment',
                  icon: Icons.hourglass_bottom_rounded,
                  accent: AppColors.warning,
                  onTap: () => context.push('/invoices'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  label: 'Overdue',
                  value: Fmt.moneyParts(overdueValue, currency: invCurrency).$1 +
                      Fmt.moneyParts(overdueValue, currency: invCurrency).$2,
                  unit: Fmt.moneyParts(overdueValue, currency: invCurrency).$3,
                  caption: '${invoices.where((i) => i.isOverdue).length} invoices',
                  icon: Icons.warning_amber_rounded,
                  accent: AppColors.danger,
                  progress: outstanding > 0 ? overdueValue / outstanding : 0,
                  onTap: () => context.push('/invoices'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  static String _dominant(Iterable<String?> codes) {
    final tally = <String, int>{};
    for (final c in codes) {
      final code = (c ?? 'INR').toUpperCase();
      tally[code] = (tally[code] ?? 0) + 1;
    }
    if (tally.isEmpty) return 'INR';
    return tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

/// Whatever an analytics endpoint returned, as cards.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.title,
    required this.metrics,
    required this.icon,
  });

  final String title;
  final AsyncValue<List<Metric>> metrics;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return metrics.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(title),
          const Skeleton(height: 90, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final shown = items.take(8).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(title),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.55,
              children: [
                for (final m in shown)
                  MetricCard(
                    label: m.label,
                    value: m.number,
                    unit: m.unit,
                    icon: icon,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }
}

/// Every active project's delivery and budget, side by side.
class _ProjectHealth extends StatelessWidget {
  const _ProjectHealth({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final active = projects.where((p) => !p.isArchived).take(10).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Project health'),
        AppCard(
          child: Column(
            children: [
              for (var i = 0; i < active.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  Divider(height: 1, color: theme.colorScheme.outline),
                  const SizedBox(height: AppSpacing.md),
                ],
                _ProjectRow(project: active[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overBudget = project.budgetUsed > 0.9;

    return InkWell(
      onTap: () => context.push('/projects/${project.id}'),
      borderRadius: AppRadius.rSm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (project.isOverdue)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: AppColors.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  'Delivery',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                ),
              ),
              Expanded(child: ProgressRail(value: project.progress, height: 6)),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: Text(
                  Fmt.percent(project.progress),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (project.budget != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(
                    'Budget',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                  ),
                ),
                Expanded(
                  child: ProgressRail(
                    value: project.budgetUsed,
                    height: 6,
                    color: overBudget ? AppColors.danger : AppColors.brandTeal,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text(
                    Fmt.percent(project.budgetUsed),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: overBudget ? AppColors.danger : null,
                    ),
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
