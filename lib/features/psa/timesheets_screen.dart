import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/common.dart';
import 'psa_providers.dart';

/// Timesheets, grouped into the weeks people actually submit — and now
/// submittable, which was the missing half: the app could show a draft week
/// but gave no way to send it for approval.
class TimesheetsScreen extends ConsumerStatefulWidget {
  const TimesheetsScreen({super.key});

  @override
  ConsumerState<TimesheetsScreen> createState() => _TimesheetsScreenState();
}

class _TimesheetsScreenState extends ConsumerState<TimesheetsScreen> {
  final _submitting = <DateTime>{};

  Future<void> _submitWeek(TimesheetWeek week) async {
    final drafts = week.entries.where((e) => e.canEdit).toList();
    if (drafts.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit this week?'),
        content: Text(
          '${drafts.length} ${drafts.length == 1 ? 'entry' : 'entries'} '
          '(${Fmt.hours(week.totalHours)}) will go to your approver. '
          'You will not be able to edit them afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting.add(week.start));
    var queued = 0;
    try {
      // The API submits per entry, so a week is a small fan-out.
      for (final entry in drafts) {
        final sent = await ref.read(offlineQueueProvider.notifier).send(
              method: 'POST',
              path: Api.timesheetSubmit(entry.id),
              label: 'Submit timesheet ${Fmt.date(entry.date)}',
            );
        if (!sent) queued++;
      }
      ref.invalidate(timesheetsProvider);
      if (mounted) {
        showToast(
          context,
          queued > 0
              ? 'Queued — will submit when back online'
              : 'Week submitted for approval',
        );
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _submitting.remove(week.start));
    }
  }

  @override
  Widget build(BuildContext context) {
    final weeks = ref.watch(timesheetWeeksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Timesheets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/timesheets/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log time'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(timesheetsProvider);
          await ref.read(timesheetWeeksProvider.future);
        },
        child: AsyncView<List<TimesheetWeek>>(
          value: weeks,
          onRetry: () => ref.invalidate(timesheetsProvider),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.schedule_rounded,
                    title: 'No time logged yet',
                    message:
                        'Log hours against a project or task and they will be '
                        'grouped into weeks here, ready to submit.',
                    actionLabel: 'Log time',
                    onAction: () => context.push('/timesheets/new'),
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
              itemBuilder: (context, i) => _WeekCard(
                week: items[i],
                busy: _submitting.contains(items[i].start),
                onSubmit: () => _submitWeek(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.busy,
    required this.onSubmit,
  });

  final TimesheetWeek week;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Fmt.date(week.start)} – ${Fmt.date(week.end)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (week.allApproved)
                const ToneChip(
                  Tone('Approved', AppColors.success, AppColors.successSoft),
                  dense: true,
                )
              else if (week.anyDraft)
                const ToneChip(
                  Tone('Draft', AppColors.slate600, AppColors.slate100),
                  dense: true,
                )
              else
                const ToneChip(
                  Tone('Submitted', AppColors.warning, AppColors.warningSoft),
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Metric(label: 'Total', value: Fmt.hours(week.totalHours)),
              const SizedBox(width: AppSpacing.xxl),
              _Metric(
                label: 'Billable',
                value: Fmt.hours(week.billableHours),
                accent: AppColors.success,
              ),
              const SizedBox(width: AppSpacing.xxl),
              _Metric(label: 'Entries', value: '${week.entries.length}'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in week.entries.take(4))
            InkWell(
              onTap: () => context.push('/timesheets/${entry.id}'),
              borderRadius: AppRadius.rSm,
              child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.task?.name ??
                          entry.project?.name ??
                          entry.description ??
                          'Time entry',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    Fmt.hours(entry.hours),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            ),
          if (week.entries.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${week.entries.length - 4} more',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    );
  }
}
