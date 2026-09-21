import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/hr.dart';
import 'psa_providers.dart';

/// Time off: my requests, bucketed by what still needs attention, with the
/// next public holiday pinned on top — the thing people actually check before
/// asking for leave.
class TimeOffScreen extends ConsumerWidget {
  const TimeOffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myTimeOffProvider);
    final holidays = ref.watch(holidaysProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Time off')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/time-off/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Request'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTimeOffProvider);
          ref.invalidate(holidaysProvider);
          await ref.read(myTimeOffProvider.future);
        },
        child: AsyncView<List<TimeOff>>(
          value: requests,
          onRetry: () => ref.invalidate(myTimeOffProvider),
          data: (items) {
            final pending = items.where((e) => e.isPending).toList();
            final upcoming = items.where((e) => e.isUpcoming).toList();
            final past =
                items.where((e) => !e.isPending && !e.isUpcoming).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                96,
              ),
              children: [
                holidays.maybeWhen(
                  data: (list) {
                    final next = list.where((h) => h.isUpcoming).toList()
                      ..sort((a, b) => a.daysAway.compareTo(b.daysAway));
                    if (next.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: _NextHoliday(holiday: next.first),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                if (items.isEmpty)
                  EmptyState(
                    icon: Icons.beach_access_rounded,
                    title: 'No leave requested',
                    message: 'Your leave requests and their status show here.',
                    actionLabel: 'Request time off',
                    onAction: () => context.push('/time-off/new'),
                  ),
                _section(context, 'Awaiting approval', pending),
                _section(context, 'Upcoming', upcoming),
                _section(context, 'History', past),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<TimeOff> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('$title · ${items.length}'),
        for (final request in items) ...[
          AppCard(
            onTap: () => context.push('/time-off/${request.id}'),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.type ?? 'Leave',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.date(request.startDate)} – '
                        '${Fmt.date(request.endDate)} · '
                        '${_days(request.dayCount)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (request.reason != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          request.reason!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ToneChip.status(request.status, dense: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  static String _days(double value) {
    final text = value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
    return '$text ${value == 1 ? 'day' : 'days'}';
  }
}

class _NextHoliday extends StatelessWidget {
  const _NextHoliday({required this.holiday});

  final Holiday holiday;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(
            Icons.celebration_rounded,
            color: AppColors.purple,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Next holiday · ${Fmt.fullDate(holiday.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            holiday.daysAway == 0 ? 'Today' : '${holiday.daysAway}d',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.purple,
            ),
          ),
        ],
      ),
    );
  }
}
