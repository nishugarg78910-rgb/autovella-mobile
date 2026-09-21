import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/common.dart';
import '../../models/hr.dart';
import '../dashboard/dashboard_screen.dart';
import 'attendance_controller.dart';

/// Attendance history, with the live check-in card reused from Home.
class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(attendanceHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(attendanceHistoryProvider);
          ref.invalidate(todayAttendanceProvider);
          await ref.read(attendanceHistoryProvider.future);
        },
        child: AsyncView<List<Attendance>>(
          value: history,
          onRetry: () => ref.invalidate(attendanceHistoryProvider),
          data: (items) {
            final totalThisMonth = items
                .where((a) {
                  final d = a.date ?? a.firstIn;
                  final now = DateTime.now();
                  return d != null &&
                      d.year == now.year &&
                      d.month == now.month;
                })
                .fold<Duration>(
                  Duration.zero,
                  (sum, a) => sum + a.worked,
                );

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              children: [
                const CheckInCard(),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'This month',
                        value: Fmt.duration(totalThisMonth),
                        icon: Icons.timelapse_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Days recorded',
                        value: '${items.length}',
                        icon: Icons.event_available_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel('History'),
                if (items.isEmpty)
                  const EmptyState(
                    compact: true,
                    icon: Icons.fingerprint_rounded,
                    title: 'No attendance recorded',
                    message: 'Check in from Home to start a record.',
                  ),
                for (final record in items) ...[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Fmt.weekday(record.date ?? record.firstIn),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                record.firstIn == null
                                    ? '—'
                                    : '${Fmt.time(record.firstIn)} – '
                                        '${record.lastOut == null ? 'now' : Fmt.time(record.lastOut)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (record.location != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.place_outlined,
                                      size: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        record.location!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Fmt.duration(record.worked),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (record.isCheckedIn)
                              const ToneChip(
                                Tone(
                                  'Open',
                                  AppColors.brand700,
                                  AppColors.brand50,
                                ),
                                dense: true,
                              )
                            else
                              ToneChip.status(record.status, dense: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
