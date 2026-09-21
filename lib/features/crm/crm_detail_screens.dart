import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/quick_create.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/contact_actions.dart';
import '../../core/widgets/states.dart';
import '../../models/crm.dart';
import 'crm_providers.dart';

class DealDetailScreen extends ConsumerWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final String dealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deal = ref.watch(dealProvider(dealId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deal'),
        actions: [
          if (deal.hasValue)
            ShareButton(
              title: deal.requireValue.name,
              path: '/deals/$dealId',
              subtitle: deal.requireValue.account?.name,
            ),
        ],
      ),
      body: AsyncView<Deal>(
        value: deal,
        onRetry: () => ref.invalidate(dealProvider(dealId)),
        data: (d) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xxxl,
          ),
          children: [
            Text(
              d.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                ToneChip.status(d.stage),
                const Spacer(),
                Text(
                  Fmt.money(d.amount, currency: d.currency),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            if (d.isOpen && d.probability != null) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Weighted value', style: theme.textTheme.titleSmall),
                        const Spacer(),
                        Text(
                          Fmt.money(d.weightedAmount, currency: d.currency),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ProgressRail(
                      value: (d.probability ?? 0) / 100,
                      color: AppColors.teal,
                      height: 8,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${d.probability}% probability',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  DetailRow(
                    label: 'Account',
                    icon: Icons.business_outlined,
                    value: d.account?.name,
                  ),
                  DetailRow(
                    label: 'Contact',
                    icon: Icons.person_outline_rounded,
                    value: d.contact?.name,
                  ),
                  DetailRow(
                    label: 'Owner',
                    icon: Icons.badge_outlined,
                    value: d.owner?.fullName,
                  ),
                  DetailRow(
                    label: 'Close date',
                    icon: Icons.event_outlined,
                    child: Text(
                      Fmt.fullDate(d.closeDate),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: d.isSlipping ? AppColors.danger : null,
                      ),
                    ),
                  ),
                  DetailRow(
                    label: 'Type',
                    icon: Icons.category_outlined,
                    value: d.type,
                  ),
                  DetailRow(
                    label: 'Source',
                    icon: Icons.input_rounded,
                    value: d.leadSource,
                  ),
                ],
              ),
            ),
            if ((d.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('Notes'),
              AppCard(child: Text(d.notes!, style: theme.textTheme.bodyMedium)),
            ],
            if ((d.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('Description'),
              AppCard(
                child: HtmlWidget(
                  d.description!,
                  textStyle: theme.textTheme.bodyMedium,
                ),
              ),
            ],
            if (d.customFields?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('Custom fields'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    for (final entry in d.customFields!.entries)
                      DetailRow(label: entry.key, value: '${entry.value}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider(accountId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: AsyncView<Account>(
        value: account,
        onRetry: () => ref.invalidate(accountProvider(accountId)),
        data: (a) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xxxl,
          ),
          children: [
            Row(
              children: [
                Avatar(initials: a.initials, size: 56),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, style: theme.textTheme.titleLarge),
                      if (a.industry != null) ...[
                        const SizedBox(height: 2),
                        Text(a.industry!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            ContactActionBar(
              phone: a.phone,
              email: a.email,
              website: a.website,
              subject: a.name,
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Contact'),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  ContactRow(
                    label: 'Email',
                    value: a.email,
                    kind: ContactKind.email,
                    subject: a.name,
                  ),
                  ContactRow(
                    label: 'Phone',
                    value: a.phone,
                    kind: ContactKind.phone,
                  ),
                  ContactRow(
                    label: 'Website',
                    value: a.website,
                    kind: ContactKind.url,
                  ),
                  ContactRow(
                    label: 'Location',
                    value: a.location.isEmpty ? null : a.location,
                    kind: ContactKind.address,
                  ),
                  DetailRow(
                    label: 'Employees',
                    icon: Icons.groups_outlined,
                    value: a.employeeCount == null
                        ? null
                        : Fmt.number(a.employeeCount),
                  ),
                  DetailRow(
                    label: 'Revenue',
                    icon: Icons.trending_up_rounded,
                    value: a.annualRevenue == null
                        ? null
                        : Fmt.money(a.annualRevenue, currency: a.currency),
                  ),
                  DetailRow(
                    label: 'Owner',
                    icon: Icons.badge_outlined,
                    value: a.owner?.fullName,
                  ),
                  DetailRow(
                    label: 'Type',
                    icon: Icons.category_outlined,
                    value: a.type,
                  ),
                  DetailRow(
                    label: 'Added',
                    icon: Icons.history_rounded,
                    value: Fmt.fullDate(a.createdAt),
                  ),
                ],
              ),
            ),
            if (a.customFields?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('Custom fields'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    for (final f in a.customFields!.entries)
                      DetailRow(label: f.key, value: '${f.value}'),
                  ],
                ),
              ),
            ],
            if ((a.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('About'),
              AppCard(
                child: Text(
                  Fmt.plainText(a.description, max: 1000),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(contactProvider(contactId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      body: AsyncView<Contact>(
        value: contact,
        onRetry: () => ref.invalidate(contactProvider(contactId)),
        data: (c) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xxxl,
          ),
          children: [
            Center(
              child: Column(
                children: [
                  Avatar(initials: c.initials, size: 72),
                  const SizedBox(height: AppSpacing.md),
                  Text(c.fullName, style: theme.textTheme.titleLarge),
                  if (c.title != null) ...[
                    const SizedBox(height: 2),
                    Text(c.title!, style: theme.textTheme.bodySmall),
                  ],
                  if (c.account != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      c.account!.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ContactActionBar(
              phone: c.callableNumber,
              email: c.email,
              subject: 'Following up',
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Reach them'),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  ContactRow(
                    label: 'Email',
                    value: c.email,
                    kind: ContactKind.email,
                    subject: 'Following up',
                  ),
                  ContactRow(
                    label: 'Mobile',
                    value: c.mobile,
                    kind: ContactKind.phone,
                  ),
                  ContactRow(
                    label: 'Phone',
                    value: c.phone,
                    kind: ContactKind.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Details'),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                children: [
                  DetailRow(
                    label: 'Title',
                    icon: Icons.work_outline_rounded,
                    value: c.title,
                  ),
                  DetailRow(
                    label: 'Account',
                    icon: Icons.business_outlined,
                    value: c.account?.name,
                  ),
                  DetailRow(
                    label: 'Source',
                    icon: Icons.input_rounded,
                    value: c.leadSource,
                  ),
                  DetailRow(
                    label: 'Owner',
                    icon: Icons.badge_outlined,
                    value: c.owner?.fullName,
                  ),
                  DetailRow(
                    label: 'Primary contact',
                    icon: Icons.star_outline_rounded,
                    value: c.isPrimary ? 'Yes' : 'No',
                  ),
                  DetailRow(
                    label: 'Added',
                    icon: Icons.history_rounded,
                    value: Fmt.fullDate(c.createdAt),
                  ),
                ],
              ),
            ),
            if (c.customFields?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel('Custom fields'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    for (final f in c.customFields!.entries)
                      DetailRow(label: f.key, value: '${f.value}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
