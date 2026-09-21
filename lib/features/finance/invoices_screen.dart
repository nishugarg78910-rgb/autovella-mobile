import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/finance.dart';
import '../psa/psa_providers.dart';

/// Invoices, ordered by what needs chasing.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final summary = ref.watch(invoiceSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(invoicesProvider);
          await ref.read(invoicesProvider.future);
        },
        child: AsyncView<List<Invoice>>(
          value: invoices,
          onRetry: () => ref.invalidate(invoicesProvider),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No invoices yet',
                    message:
                        'Invoices raised against your projects and accounts '
                        'appear here.',
                  ),
                ],
              );
            }

            // Overdue first, then by due date: the collections order.
            final sorted = [...items]..sort((a, b) {
                if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
                if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
                final x = a.dueDate;
                final y = b.dueDate;
                if (x == null && y == null) return 0;
                if (x == null) return 1;
                if (y == null) return -1;
                return x.compareTo(y);
              });

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.xxxl,
              ),
              children: [
                if (summary.hasValue) _Summary(summary: summary.requireValue),
                const SizedBox(height: AppSpacing.xl),
                for (final invoice in sorted) ...[
                  _InvoiceRow(invoice: invoice),
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

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final InvoiceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile.money(
            summary.outstanding,
            label: 'Outstanding',
            currency: summary.currency,
            icon: Icons.hourglass_bottom_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatTile.money(
            summary.overdue,
            label: 'Overdue (${summary.overdueCount})',
            currency: summary.currency,
            icon: Icons.warning_amber_rounded,
            accent: AppColors.danger,
          ),
        ),
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push('/invoices/${invoice.id}'),
      accentColor: invoice.isOverdue ? AppColors.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.number,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                Fmt.money(invoice.total, currency: invoice.currency),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (invoice.account != null) ...[
            const SizedBox(height: 3),
            Text(
              invoice.account!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              ToneChip.status(
                invoice.isOverdue ? 'overdue' : invoice.status,
                dense: true,
              ),
              const Spacer(),
              if (invoice.isOverdue)
                Text(
                  '${invoice.daysOverdue}d overdue',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                )
              else if (invoice.dueDate != null)
                Text(
                  'Due ${Fmt.date(invoice.dueDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
            ],
          ),
          if (!invoice.isPaid && (invoice.amountPaid ?? 0) > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            ProgressRail(
              value: (invoice.amountPaid ?? 0) / (invoice.total ?? 1),
              height: 4,
            ),
            const SizedBox(height: 4),
            Text(
              '${Fmt.money(invoice.balanceDue, currency: invoice.currency)} remaining',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
