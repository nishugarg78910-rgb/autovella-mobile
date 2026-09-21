import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/quick_create.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/offline/offline_queue.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/permission_gate.dart';
import '../../core/widgets/states.dart';
import '../../data/repository.dart';
import '../../models/finance.dart';
import '../psa/psa_providers.dart';

final invoiceProvider = FutureProvider.autoDispose.family<Invoice, String>(
  (ref, id) => ref.watch(invoiceRepoProvider).get(id),
);

/// Invoice detail — lines, totals, and the two actions that matter on a
/// phone: send it, and record that it was paid.
class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _busy = false;

  Future<void> _act(String path, String label, String done) async {
    setState(() => _busy = true);
    try {
      final sent = await ref.read(offlineQueueProvider.notifier).send(
            method: 'POST',
            path: path,
            label: label,
          );
      ref.invalidate(invoiceProvider(widget.invoiceId));
      ref.invalidate(invoicesProvider);
      if (mounted) {
        showToast(context, sent ? done : 'Queued — will send when back online');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markPaid(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Record payment?'),
        content: Text(
          'This marks ${invoice.number} as paid in full '
          '(${Fmt.money(invoice.balanceDue, currency: invoice.currency)} '
          'outstanding).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _act(
      Api.invoicePay(widget.invoiceId),
      'Mark ${invoice.number} paid',
      'Marked as paid',
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoice = ref.watch(invoiceProvider(widget.invoiceId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          if (invoice.hasValue)
            ShareButton(
              title: 'Invoice ${invoice.requireValue.number}',
              path: '/invoices/${widget.invoiceId}',
              subtitle: invoice.requireValue.account?.name,
            ),
        ],
      ),
      body: AsyncView<Invoice>(
        value: invoice,
        onRetry: () => ref.invalidate(invoiceProvider(widget.invoiceId)),
        data: (inv) => ListView(
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
                        inv.number,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (inv.account != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          inv.account!.name,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                ToneChip.status(
                  inv.isOverdue ? 'overdue' : inv.status,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Headline number, with what is still owed.
            GuardedField(
              module: 'invoices',
              field: 'total',
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.money(inv.total, currency: inv.currency, decimals: true),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                    if (!inv.isPaid && inv.balanceDue > 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      ProgressRail(
                        value: (inv.amountPaid ?? 0) / (inv.total ?? 1),
                        height: 6,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${Fmt.money(inv.amountPaid ?? 0, currency: inv.currency)} paid · '
                        '${Fmt.money(inv.balanceDue, currency: inv.currency)} outstanding',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (inv.isOverdue) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${inv.daysOverdue} days overdue',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  GuardedRow(
                    module: 'invoices',
                    field: 'issueDate',
                    label: 'Issued',
                    icon: Icons.event_outlined,
                    value: Fmt.fullDate(inv.issueDate),
                  ),
                  GuardedRow(
                    module: 'invoices',
                    field: 'dueDate',
                    label: 'Due',
                    icon: Icons.schedule_rounded,
                    child: Text(
                      Fmt.fullDate(inv.dueDate),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: inv.isOverdue ? AppColors.danger : null,
                      ),
                    ),
                  ),
                  GuardedRow(
                    module: 'invoices',
                    field: 'paymentTerms',
                    label: 'Terms',
                    icon: Icons.handshake_outlined,
                    value: inv.paymentTerms,
                  ),
                  if (inv.project != null)
                    GuardedRow(
                      module: 'invoices',
                      field: 'projectId',
                      label: 'Project',
                      icon: Icons.folder_outlined,
                      value: inv.project!.name,
                    ),
                ],
              ),
            ),

            if (inv.lineItems.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              SectionLabel('Lines · ${inv.lineItems.length}'),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    for (var i = 0; i < inv.lineItems.length; i++) ...[
                      if (i > 0)
                        Divider(height: 18, color: theme.colorScheme.outline),
                      _LineRow(line: inv.lineItems[i], currency: inv.currency),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            GuardedField(
              module: 'invoices',
              field: 'subtotal',
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    DetailRow(
                      label: 'Subtotal',
                      value: Fmt.money(inv.subtotal,
                          currency: inv.currency, decimals: true),
                    ),
                    if ((inv.discount ?? 0) > 0)
                      DetailRow(
                        label: 'Discount',
                        value: '−${Fmt.money(inv.discount, currency: inv.currency)}',
                      ),
                    DetailRow(
                      label: 'Tax',
                      value: Fmt.money(inv.taxAmount,
                          currency: inv.currency, decimals: true),
                    ),
                    DetailRow(
                      label: 'Total',
                      child: Text(
                        Fmt.money(inv.total,
                            currency: inv.currency, decimals: true),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if ((inv.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('Notes'),
              AppCard(
                child: Text(inv.notes!, style: theme.textTheme.bodyMedium),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: invoice.hasValue
          ? _Actions(
              invoice: invoice.requireValue,
              busy: _busy,
              onSend: () => _act(
                Api.invoiceSend(widget.invoiceId),
                'Send ${invoice.requireValue.number}',
                'Invoice sent',
              ),
              onMarkPaid: () => _markPaid(invoice.requireValue),
            )
          : null,
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, this.currency});

  final InvoiceLine line;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.description,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                '${Fmt.number(line.quantity)} × '
                '${Fmt.money(line.unitPrice, currency: currency)}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          Fmt.money(line.amount, currency: currency),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.invoice,
    required this.busy,
    required this.onSend,
    required this.onMarkPaid,
  });

  final Invoice invoice;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    if (invoice.isPaid || invoice.isCancelled) return const SizedBox.shrink();

    return GuardedAction(
      module: 'invoices',
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onSend,
                icon: const Icon(Icons.send_rounded, size: 17),
                label: const Text('Send'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onMarkPaid,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Mark paid'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
