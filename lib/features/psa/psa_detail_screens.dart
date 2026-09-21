import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/permission_gate.dart';
import '../../core/widgets/states.dart';
import '../../models/finance.dart';
import '../../models/hr.dart';
import '../approvals/approvals_screen.dart';
import '../auth/auth_controller.dart';
import 'psa_providers.dart';

/// Shared chrome for the three PSA records: a headline, a details card, and
/// a pinned action bar.
class _RecordScaffold extends StatelessWidget {
  const _RecordScaffold({
    required this.title,
    required this.headline,
    required this.status,
    required this.children,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String headline;
  final String? subtitle;
  final String? status;
  final List<Widget> children;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: actions,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.xxxl,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: AppSpacing.sm),
                ToneChip.status(status),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          ...children,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- timesheet

class TimesheetDetailScreen extends ConsumerStatefulWidget {
  const TimesheetDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<TimesheetDetailScreen> createState() =>
      _TimesheetDetailScreenState();
}

class _TimesheetDetailScreenState extends ConsumerState<TimesheetDetailScreen> {
  bool _busy = false;

  Future<void> _post(String path, String label, String done) async {
    setState(() => _busy = true);
    try {
      final sent = await ref
          .read(offlineQueueProvider.notifier)
          .send(method: 'POST', path: path, label: label);
      ref.invalidate(timesheetProvider(widget.id));
      ref.invalidate(timesheetsProvider);
      ref.invalidate(approvalsProvider);
      if (mounted) {
        showToast(context, sent ? done : 'Queued — will send when online');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(timesheetProvider(widget.id));
    final perms = ref.watch(permissionsProvider);
    final canApprove = perms.canUpdate('approveAllTimesheets') ||
        perms.canRead('approvals');

    return AsyncView<Timesheet>(
      value: entry,
      loading: const Scaffold(body: SkeletonList(count: 3)),
      onRetry: () => ref.invalidate(timesheetProvider(widget.id)),
      data: (t) => _RecordScaffold(
        title: 'Time entry',
        headline: Fmt.hours(t.hours),
        subtitle: t.project?.name ?? t.task?.name,
        status: t.status ?? 'draft',
        actions: _busy
            ? null
            : _ActionBar(
                children: [
                  if (t.canEdit)
                    FilledButton.icon(
                      onPressed: () => _post(
                        Api.timesheetSubmit(t.id),
                        'Submit timesheet',
                        'Submitted for approval',
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Submit'),
                    ),
                  if (t.isSubmitted && canApprove) ...[
                    OutlinedButton(
                      onPressed: () => _post(
                        Api.timesheetReject(t.id),
                        'Reject timesheet',
                        'Rejected',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('Reject'),
                    ),
                    FilledButton(
                      onPressed: () => _post(
                        Api.timesheetApprove(t.id),
                        'Approve timesheet',
                        'Approved',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      child: const Text('Approve'),
                    ),
                  ],
                ],
              ),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                DetailRow(
                  label: 'Date',
                  icon: Icons.event_outlined,
                  value: Fmt.weekday(t.date),
                ),
                GuardedRow(
                  module: 'timesheets',
                  field: 'hours',
                  label: 'Hours',
                  icon: Icons.timer_outlined,
                  child: Text(
                    Fmt.hours(t.hours),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DetailRow(
                  label: 'Billable',
                  icon: Icons.receipt_long_outlined,
                  value: t.isBillable ? 'Yes' : 'No',
                ),
                if (t.project != null)
                  DetailRow(
                    label: 'Project',
                    icon: Icons.folder_outlined,
                    value: t.project!.name,
                  ),
                if (t.task != null)
                  DetailRow(
                    label: 'Task',
                    icon: Icons.check_circle_outline_rounded,
                    child: GestureDetector(
                      onTap: () => context.push('/tasks/${t.task!.id}'),
                      child: Text(
                        t.task!.name,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                DetailRow(
                  label: 'Logged by',
                  icon: Icons.person_outline_rounded,
                  value: t.user?.fullName,
                ),
                if (t.weekStart != null)
                  DetailRow(
                    label: 'Week',
                    icon: Icons.date_range_outlined,
                    value: '${Fmt.date(t.weekStart)} – ${Fmt.date(t.weekEnd)}',
                  ),
                if (t.submittedAt != null)
                  DetailRow(
                    label: 'Submitted',
                    icon: Icons.send_outlined,
                    value: Fmt.dateTime(t.submittedAt),
                  ),
                if (t.approvedBy != null)
                  DetailRow(
                    label: 'Approved by',
                    icon: Icons.verified_outlined,
                    value: t.approvedBy!.fullName,
                  ),
              ],
            ),
          ),
          if ((t.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('What was done'),
            AppCard(child: Text(t.description!)),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ timeoff

class TimeOffDetailScreen extends ConsumerStatefulWidget {
  const TimeOffDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<TimeOffDetailScreen> createState() =>
      _TimeOffDetailScreenState();
}

class _TimeOffDetailScreenState extends ConsumerState<TimeOffDetailScreen> {
  bool _busy = false;

  Future<void> _post(String path, String label, String done) async {
    setState(() => _busy = true);
    try {
      final sent = await ref
          .read(offlineQueueProvider.notifier)
          .send(method: 'POST', path: path, label: label);
      ref.invalidate(timeOffDetailProvider(widget.id));
      ref.invalidate(myTimeOffProvider);
      ref.invalidate(approvalsProvider);
      if (mounted) {
        showToast(context, sent ? done : 'Queued — will send when online');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(timeOffDetailProvider(widget.id));
    final me = ref.watch(currentUserProvider);
    final perms = ref.watch(permissionsProvider);
    final canApprove =
        perms.canUpdate('approveAllTimeOff') || perms.canRead('approvals');

    return AsyncView<TimeOff>(
      value: record,
      loading: const Scaffold(body: SkeletonList(count: 3)),
      onRetry: () => ref.invalidate(timeOffDetailProvider(widget.id)),
      data: (r) {
        final mine = me != null && r.user?.id == me.id;
        return _RecordScaffold(
          title: 'Time off',
          headline: r.type ?? 'Leave',
          subtitle: '${Fmt.date(r.startDate)} – ${Fmt.date(r.endDate)}',
          status: r.status,
          actions: _busy
              ? null
              : _ActionBar(
                  children: [
                    if (mine && (r.isPending || r.isApproved))
                      OutlinedButton.icon(
                        onPressed: () => _post(
                          Api.timeOffCancel(r.id),
                          'Cancel leave',
                          'Leave cancelled',
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Cancel request'),
                      ),
                    if (!mine && r.isPending && canApprove) ...[
                      OutlinedButton(
                        onPressed: () => _post(
                          Api.timeOffReject(r.id),
                          'Reject leave',
                          'Rejected',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        child: const Text('Reject'),
                      ),
                      FilledButton(
                        onPressed: () => _post(
                          Api.timeOffApprove(r.id),
                          'Approve leave',
                          'Approved',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                        child: const Text('Approve'),
                      ),
                    ],
                  ],
                ),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Days',
                    value: r.dayCount
                        .toStringAsFixed(r.dayCount % 1 == 0 ? 0 : 1),
                    icon: Icons.event_available_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    label: 'Starts in',
                    value: r.startDate == null
                        ? '—'
                        : '${r.startDate!.difference(DateTime.now()).inDays}d',
                    icon: Icons.schedule_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  DetailRow(
                    label: 'Requested by',
                    icon: Icons.person_outline_rounded,
                    value: r.user?.fullName,
                  ),
                  DetailRow(
                    label: 'From',
                    icon: Icons.play_arrow_rounded,
                    value: Fmt.fullDate(r.startDate),
                  ),
                  DetailRow(
                    label: 'To',
                    icon: Icons.stop_rounded,
                    value: Fmt.fullDate(r.endDate),
                  ),
                  DetailRow(
                    label: 'Requested on',
                    icon: Icons.history_rounded,
                    value: Fmt.fullDate(r.createdAt),
                  ),
                  if (r.approvedBy != null)
                    DetailRow(
                      label: 'Decided by',
                      icon: Icons.verified_outlined,
                      value: r.approvedBy!.fullName,
                    ),
                ],
              ),
            ),
            if ((r.reason ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('Reason'),
              AppCard(child: Text(r.reason!)),
            ],
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ expense

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  const ExpenseDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  bool _busy = false;

  Future<void> _post(String path, String label, String done) async {
    setState(() => _busy = true);
    try {
      final sent = await ref
          .read(offlineQueueProvider.notifier)
          .send(method: 'POST', path: path, label: label);
      ref.invalidate(expenseProvider(widget.id));
      ref.invalidate(expensesProvider);
      ref.invalidate(approvalsProvider);
      if (mounted) {
        showToast(context, sent ? done : 'Queued — will send when online');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = ref.watch(expenseProvider(widget.id));
    final perms = ref.watch(permissionsProvider);
    final canApprove =
        perms.canUpdate('approveAllExpenses') || perms.canRead('approvals');

    return AsyncView<Expense>(
      value: expense,
      loading: const Scaffold(body: SkeletonList(count: 3)),
      onRetry: () => ref.invalidate(expenseProvider(widget.id)),
      data: (e) {
        final pending = (e.status ?? '').toLowerCase() == 'pending';
        return _RecordScaffold(
          title: 'Expense',
          headline: Fmt.money(e.amount, currency: e.currency, decimals: true),
          subtitle: e.description,
          status: e.status,
          actions: _busy || !(pending && canApprove)
              ? null
              : _ActionBar(
                  children: [
                    OutlinedButton(
                      onPressed: () => _post(
                        Api.expenseReject(e.id),
                        'Reject expense',
                        'Rejected',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('Reject'),
                    ),
                    FilledButton(
                      onPressed: () => _post(
                        Api.expenseApprove(e.id),
                        'Approve expense',
                        'Approved',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
          children: [
            ReceiptView(url: e.receiptUrl),
            if (e.hasReceipt) const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  GuardedRow(
                    module: 'expenses',
                    field: 'amount',
                    label: 'Amount',
                    icon: Icons.payments_outlined,
                    child: Text(
                      Fmt.money(e.amount, currency: e.currency, decimals: true),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  GuardedRow(
                    module: 'expenses',
                    field: 'category',
                    label: 'Category',
                    icon: Icons.category_outlined,
                    value: e.category,
                  ),
                  GuardedRow(
                    module: 'expenses',
                    field: 'date',
                    label: 'Date',
                    icon: Icons.event_outlined,
                    value: Fmt.fullDate(e.date),
                  ),
                  DetailRow(
                    label: 'Filed by',
                    icon: Icons.person_outline_rounded,
                    value: e.user?.fullName,
                  ),
                  if (e.project != null)
                    GuardedRow(
                      module: 'expenses',
                      field: 'projectId',
                      label: 'Project',
                      icon: Icons.folder_outlined,
                      value: e.project!.name,
                    ),
                  GuardedRow(
                    module: 'expenses',
                    field: 'isBillable',
                    label: 'Billable',
                    icon: Icons.receipt_long_outlined,
                    value: e.isBillable ? 'Yes' : 'No',
                  ),
                  DetailRow(
                    label: 'Reimbursable',
                    icon: Icons.account_balance_wallet_outlined,
                    value: e.isReimbursable ? 'Yes' : 'No',
                  ),
                ],
              ),
            ),
            if ((e.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('Notes'),
              AppCard(child: Text(e.notes!)),
            ],
          ],
        );
      },
    );
  }
}

/// The receipt image, tappable for a full-screen zoomable view. Approving an
/// expense without being able to see what was bought is guesswork, so this
/// sits at the top of the screen rather than behind a link.
class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final src = url;
    if (src == null || src.isEmpty) {
      return const AppCard(
        child: EmptyState(
          compact: true,
          icon: Icons.receipt_long_outlined,
          title: 'No receipt attached',
        ),
      );
    }

    final absolute =
        src.startsWith('http') ? src : '${Api.baseUrl}${src.startsWith('/') ? '' : '/'}$src';

    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: absolute,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.rLg,
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: absolute,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                height: 120,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Text('Receipt could not be loaded'),
                ),
              ),
              placeholder: (_, __) => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: AppRadius.rSm,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Tap to zoom',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}
