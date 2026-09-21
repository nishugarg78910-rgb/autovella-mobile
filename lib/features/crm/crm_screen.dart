import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import '../../core/widgets/atoms.dart';
import '../../core/widgets/states.dart';
import '../../models/crm.dart';
import '../shell/home_shell.dart';
import 'crm_providers.dart';

/// CRM, as three tabs. Deals lead because pipeline is what a sales lead opens
/// the app to check.
class CrmScreen extends ConsumerWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CRM'),
          actions: [
            IconButton(
              onPressed: () => context.push('/search'),
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search',
            ),
            const NotificationBell(),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Deals'),
              Tab(text: 'Accounts'),
              Tab(text: 'Contacts'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DealsTab(), _AccountsTab(), _ContactsTab()],
        ),
      ),
    );
  }
}

class _DealsTab extends ConsumerWidget {
  const _DealsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(dealsProvider(null));
    final pipeline = ref.watch(pipelineProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dealsProvider(null));
        await ref.read(dealsProvider(null).future);
      },
      child: AsyncView<List<Deal>>(
        value: deals,
        onRetry: () => ref.invalidate(dealsProvider(null)),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 60),
                EmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'No deals yet',
                  message: 'Your pipeline will appear here once deals exist.',
                ),
              ],
            );
          }

          // Open deals first, closing soonest at the top — the order someone
          // working the pipeline actually wants.
          final sorted = [...items]..sort((a, b) {
              if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
              final x = a.closeDate;
              final y = b.closeDate;
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
              96,
            ),
            children: [
              if (pipeline.hasValue) _PipelineHeader(summary: pipeline.requireValue),
              const SizedBox(height: AppSpacing.lg),
              for (final deal in sorted) ...[
                _DealRow(deal: deal),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PipelineHeader extends StatelessWidget {
  const _PipelineHeader({required this.summary});

  final PipelineSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile.money(
                summary.openValue,
                label: 'Open pipeline',
                currency: summary.currency,
                icon: Icons.trending_up_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile.money(
                summary.weightedValue,
                label: 'Weighted',
                currency: summary.currency,
                icon: Icons.percent_rounded,
                accent: AppColors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Closing ≤14d',
                value: '${summary.closingSoon}',
                icon: Icons.schedule_rounded,
                accent: AppColors.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatTile(
                label: 'Past close date',
                value: '${summary.slipping}',
                icon: Icons.warning_amber_rounded,
                accent: AppColors.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DealRow extends StatelessWidget {
  const _DealRow({required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push('/deals/${deal.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  deal.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(height: 1.25),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Fmt.moneyShort(deal.amount, currency: deal.currency),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (deal.account != null) ...[
            const SizedBox(height: 4),
            Text(
              deal.account!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              ToneChip.status(deal.stage, dense: true),
              if (deal.probability != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${deal.probability}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              if (deal.closeDate != null)
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 13,
                      color: deal.isSlipping
                          ? AppColors.danger
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Fmt.date(deal.closeDate),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: deal.isSlipping
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: deal.isSlipping
                            ? AppColors.danger
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              if (deal.owner != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Avatar.user(deal.owner!, size: 22),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountsTab extends ConsumerWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider(null));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(accountsProvider(null));
        await ref.read(accountsProvider(null).future);
      },
      child: AsyncView<List<Account>>(
        value: accounts,
        onRetry: () => ref.invalidate(accountsProvider(null)),
        data: (items) => items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.business_outlined,
                    title: 'No accounts yet',
                    message: 'Companies you work with appear here.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  96,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final account = items[i];
                  return AppCard(
                    onTap: () => context.push('/accounts/${account.id}'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Avatar(initials: account.initials, size: 40),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [account.industry, account.location]
                                        .where((e) =>
                                            e != null && e.isNotEmpty)
                                        .join(' · ')
                                        .isEmpty
                                    ? (account.email ?? '—')
                                    : [account.industry, account.location]
                                        .where((e) =>
                                            e != null && e.isNotEmpty)
                                        .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ContactsTab extends ConsumerWidget {
  const _ContactsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider(null));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(contactsProvider(null));
        await ref.read(contactsProvider(null).future);
      },
      child: AsyncView<List<Contact>>(
        value: contacts,
        onRetry: () => ref.invalidate(contactsProvider(null)),
        data: (items) => items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.person_outline_rounded,
                    title: 'No contacts yet',
                    message: 'People at your accounts appear here.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  96,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final contact = items[i];
                  return AppCard(
                    onTap: () => context.push('/contacts/${contact.id}'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Avatar(initials: contact.initials, size: 40),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [contact.title, contact.account?.name]
                                        .where((e) =>
                                            e != null && e.isNotEmpty)
                                        .join(' · ')
                                        .isEmpty
                                    ? (contact.email ?? '—')
                                    : [contact.title, contact.account?.name]
                                        .where((e) =>
                                            e != null && e.isNotEmpty)
                                        .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
