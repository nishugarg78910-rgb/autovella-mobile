import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../data/repository.dart';
import '../dashboard/home_providers.dart';

/// One thing awaiting a decision, whatever kind it is.
class ApprovalItem {
  const ApprovalItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.approvePath,
    required this.rejectPath,
    this.route,
    this.trailing,
    this.who,
    this.when,
  });

  /// Where to go to see the whole record — the receipt on an expense, the
  /// reason on a leave request. Approving from a one-line summary is guesswork.
  final String? route;

  final String id;

  /// 'Timesheet' | 'Time off' | 'Expense'
  final String kind;
  final String title;
  final String subtitle;
  final String approvePath;
  final String rejectPath;
  final String? trailing;
  final String? who;
  final DateTime? when;

  IconData get icon => switch (kind) {
        'Timesheet' => Icons.schedule_rounded,
        'Time off' => Icons.beach_access_rounded,
        _ => Icons.receipt_long_rounded,
      };
}

/// Approvals.
///
/// The platform has no `/approvals` endpoint — the web app's Approvals page
/// is a composite over timesheets, time off and expenses, each with its own
/// `/:id/approve` and `/:id/reject` routes. This screen does the same. The
/// previous build called a `/approvals` route that does not exist, which is
/// why it errored.
final approvalsProvider =
    FutureProvider.autoDispose<List<ApprovalItem>>((ref) async {
  final items = <ApprovalItem>[];

  Future<void> collect(Future<void> Function() work) async {
    try {
      await work();
    } catch (_) {
      // One unavailable source must not empty the whole queue.
    }
  }

  await Future.wait([
    collect(() async {
      final rows = await ref.watch(timesheetRepoProvider).list(
            limit: 50,
            filters: {'status': 'submitted'},
          );
      for (final t in rows.where((e) => e.isSubmitted)) {
        items.add(ApprovalItem(
          id: t.id,
          kind: 'Timesheet',
          title: t.project?.name ?? 'Time entry',
          subtitle: [
            if (t.user != null) t.user!.fullName,
            Fmt.date(t.date),
          ].join(' · '),
          trailing: Fmt.hours(t.hours),
          who: t.user?.fullName,
          when: t.date,
          route: '/timesheets/${t.id}',
          approvePath: Api.timesheetApprove(t.id),
          rejectPath: Api.timesheetReject(t.id),
        ));
      }
    }),
    collect(() async {
      final rows = await ref.watch(timeOffRepoProvider).list(
            limit: 50,
            filters: {'status': 'pending'},
          );
      for (final r in rows.where((e) => e.isPending)) {
        items.add(ApprovalItem(
          id: r.id,
          kind: 'Time off',
          title: r.type ?? 'Leave request',
          subtitle: [
            if (r.user != null) r.user!.fullName,
            '${Fmt.date(r.startDate)} – ${Fmt.date(r.endDate)}',
          ].join(' · '),
          trailing: '${r.dayCount.toStringAsFixed(r.dayCount % 1 == 0 ? 0 : 1)}d',
          who: r.user?.fullName,
          when: r.startDate,
          route: '/time-off/${r.id}',
          approvePath: Api.timeOffApprove(r.id),
          rejectPath: Api.timeOffReject(r.id),
        ));
      }
    }),
    collect(() async {
      final rows = await ref.watch(expenseRepoProvider).list(
            limit: 50,
            filters: {'status': 'pending'},
          );
      for (final e in rows) {
        items.add(ApprovalItem(
          id: e.id,
          kind: 'Expense',
          title: e.description,
          subtitle: [
            if (e.user != null) e.user!.fullName,
            if (e.category != null) e.category!,
            Fmt.date(e.date),
          ].join(' · '),
          trailing: Fmt.money(e.amount, currency: e.currency),
          who: e.user?.fullName,
          when: e.date,
          route: '/expenses/${e.id}',
          approvePath: Api.expenseApprove(e.id),
          rejectPath: Api.expenseReject(e.id),
        ));
      }
    }),
  ]);

  items.sort((a, b) {
    final x = a.when;
    final y = b.when;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  });
  return items;
});

class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  final _busy = <String>{};

  Future<void> _decide(ApprovalItem item, {required bool approve}) async {
    setState(() => _busy.add(item.id));
    try {
      await ref
          .read(apiClientProvider)
          .post(approve ? item.approvePath : item.rejectPath);
      ref.invalidate(approvalsProvider);
      ref.invalidate(approvalLoadProvider);
      if (mounted) {
        showToast(context, approve ? 'Approved' : 'Rejected');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final approvals = ref.watch(approvalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Approvals')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(approvalsProvider);
          await ref.read(approvalsProvider.future);
        },
        child: AsyncView<List<ApprovalItem>>(
          value: approvals,
          onRetry: () => ref.invalidate(approvalsProvider),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Nothing to approve',
                    message:
                        'Submitted timesheets, leave requests and expenses '
                        'appear here for your decision.',
                  ),
                ],
              );
            }

            final byKind = <String, List<ApprovalItem>>{};
            for (final item in items) {
              byKind.putIfAbsent(item.kind, () => []).add(item);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              children: [
                for (final entry in byKind.entries) ...[
                  SectionLabel('${entry.key} · ${entry.value.length}'),
                  for (final item in entry.value) ...[
                    _ApprovalCard(
                      item: item,
                      busy: _busy.contains(item.id),
                      onApprove: () => _decide(item, approve: true),
                      onReject: () => _decide(item, approve: false),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final ApprovalItem item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: item.route == null ? null : () => context.push(item.route!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 17, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (item.trailing != null)
                Text(
                  item.trailing!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    minimumSize: const Size(0, 40),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
