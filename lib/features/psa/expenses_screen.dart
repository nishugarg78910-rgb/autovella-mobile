import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/finance.dart';
import 'psa_providers.dart';

/// Expenses.
///
/// The mobile-native part is capture: photographing a receipt at the counter
/// beats typing it into a laptop that evening, so the camera is the primary
/// action rather than a field buried in a form.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _capture(context, ref),
        icon: const Icon(Icons.photo_camera_rounded),
        label: const Text('Snap receipt'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expensesProvider);
          await ref.read(expensesProvider.future);
        },
        child: AsyncView<List<Expense>>(
          value: expenses,
          onRetry: () => ref.invalidate(expensesProvider),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.receipt_rounded,
                    title: 'No expenses yet',
                    message:
                        'Photograph a receipt and file it in seconds — no '
                        'need to wait until you are back at a desk.',
                    actionLabel: 'Snap a receipt',
                    onAction: () => _capture(context, ref),
                  ),
                ],
              );
            }

            final total = items.fold<double>(0, (sum, e) => sum + e.amount);
            final pending = items.where((e) {
              final s = (e.status ?? '').toLowerCase();
              return s == 'pending' || s == 'submitted';
            }).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                96,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile.money(
                        total,
                        label: 'Total filed',
                        currency: items.first.currency,
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: StatTile(
                        label: 'Awaiting approval',
                        value: '$pending',
                        icon: Icons.hourglass_empty_rounded,
                        accent: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final expense in items) ...[
                  _ExpenseRow(expense: expense),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _capture(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      // Receipts are documents, not photographs — cap the size so uploads
      // stay quick on patchy mobile data.
      maxWidth: 2000,
      imageQuality: 80,
    );
    if (picked == null || !context.mounted) return;

    final details = await showModalBottomSheet<_ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExpenseForm(imagePath: picked.path),
    );
    if (details == null || !context.mounted) return;

    try {
      final api = ref.read(apiClientProvider);
      final created = await api.post(
        Api.expenses,
        body: {
          'description': details.description,
          'amount': details.amount,
          'currency': details.currency,
          if (details.category != null) 'category': details.category,
          'date': Fmt.apiDate(DateTime.now()),
          'isBillable': details.billable,
          'isReimbursable': true,
        },
      );

      // Attach the receipt to the expense the server just created.
      final id = created is Map ? '${created['id'] ?? ''}' : '';
      if (id.isNotEmpty) {
        await api.upload(
          '${Api.expenses}/$id/receipt',
          filePath: picked.path,
          field: 'receipt',
        );
      }

      ref.invalidate(expensesProvider);
      if (context.mounted) showToast(context, 'Expense filed');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, e.message, isError: true);
    }
  }
}

class _ExpenseDraft {
  const _ExpenseDraft({
    required this.description,
    required this.amount,
    required this.currency,
    this.category,
    this.billable = false,
  });

  final String description;
  final double amount;
  final String currency;
  final String? category;
  final bool billable;
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({required this.imagePath});

  final String imagePath;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  String _category = 'Travel';
  bool _billable = false;

  static const _categories = [
    'Travel',
    'Meals',
    'Accommodation',
    'Software',
    'Equipment',
    'Other',
  ];

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'File this expense',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: AppRadius.rMd,
                child: Image.file(
                  File(widget.imagePath),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _description,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What was it for?',
                  hintText: 'Client lunch, cab to site…',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'Other'),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                value: _billable,
                onChanged: (v) => setState(() => _billable = v),
                title: const Text('Billable to client'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(_amount.text.trim());
                  if (_description.text.trim().isEmpty || amount == null) {
                    showToast(
                      context,
                      'Add a description and a valid amount.',
                      isError: true,
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    _ExpenseDraft(
                      description: _description.text.trim(),
                      amount: amount,
                      currency: 'INR',
                      category: _category,
                      billable: _billable,
                    ),
                  );
                },
                child: const Text('File expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push('/expenses/${expense.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(
              expense.hasReceipt
                  ? Icons.receipt_long_rounded
                  : Icons.description_outlined,
              size: 19,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    expense.category,
                    Fmt.date(expense.date),
                    if (expense.isBillable) 'Billable',
                  ].where((e) => e != null && e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.money(expense.amount, currency: expense.currency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              ToneChip.status(expense.status, dense: true),
            ],
          ),
        ],
      ),
    );
  }
}
