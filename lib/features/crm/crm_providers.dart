import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository.dart';
import '../../models/crm.dart';

final accountsProvider =
    FutureProvider.autoDispose.family<List<Account>, String?>(
  (ref, search) =>
      ref.watch(accountRepoProvider).list(limit: 100, search: search),
);

final accountProvider = FutureProvider.autoDispose.family<Account, String>(
  (ref, id) => ref.watch(accountRepoProvider).get(id),
);

final contactsProvider =
    FutureProvider.autoDispose.family<List<Contact>, String?>(
  (ref, search) =>
      ref.watch(contactRepoProvider).list(limit: 100, search: search),
);

final contactProvider = FutureProvider.autoDispose.family<Contact, String>(
  (ref, id) => ref.watch(contactRepoProvider).get(id),
);

final dealsProvider = FutureProvider.autoDispose.family<List<Deal>, String?>(
  (ref, search) => ref.watch(dealRepoProvider).list(limit: 100, search: search),
);

final dealProvider = FutureProvider.autoDispose.family<Deal, String>(
  (ref, id) => ref.watch(dealRepoProvider).get(id),
);

/// Pipeline rollup for the Deals tab header.
class PipelineSummary {
  const PipelineSummary({
    required this.openValue,
    required this.weightedValue,
    required this.wonValue,
    required this.openCount,
    required this.closingSoon,
    required this.slipping,
    required this.currency,
  });

  final double openValue;
  final double weightedValue;
  final double wonValue;
  final int openCount;
  final int closingSoon;
  final int slipping;
  final String currency;

  factory PipelineSummary.from(List<Deal> deals) {
    var open = 0.0;
    var weighted = 0.0;
    var won = 0.0;
    var openCount = 0;
    var soon = 0;
    var slipping = 0;
    // Deals can carry mixed currencies. Rather than convert with a stale
    // rate, the rollup reports in whichever currency dominates the list and
    // the UI flags that it is an approximation.
    final currencyTally = <String, int>{};

    for (final deal in deals) {
      final code = (deal.currency ?? 'INR').toUpperCase();
      currencyTally[code] = (currencyTally[code] ?? 0) + 1;

      if (deal.isWon) {
        won += deal.amount ?? 0;
      } else if (deal.isOpen) {
        open += deal.amount ?? 0;
        weighted += deal.weightedAmount;
        openCount++;
        if (deal.isClosingSoon) soon++;
        if (deal.isSlipping) slipping++;
      }
    }

    final dominant = currencyTally.entries.isEmpty
        ? 'INR'
        : currencyTally.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

    return PipelineSummary(
      openValue: open,
      weightedValue: weighted,
      wonValue: won,
      openCount: openCount,
      closingSoon: soon,
      slipping: slipping,
      currency: dominant,
    );
  }
}

final pipelineProvider =
    FutureProvider.autoDispose<PipelineSummary>((ref) async {
  final deals = await ref.watch(dealsProvider(null).future);
  return PipelineSummary.from(deals);
});
