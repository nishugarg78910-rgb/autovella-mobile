import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository.dart';
import '../../models/finance.dart';
import '../../models/hr.dart';
import '../auth/auth_controller.dart';

// ---- Timesheets ----------------------------------------------------------

final timesheetsProvider =
    FutureProvider.autoDispose<List<Timesheet>>((ref) async {
  final user = ref.watch(currentUserProvider);
  return ref.watch(timesheetRepoProvider).list(
        limit: 100,
        filters: {if (user != null) 'userId': user.id},
      );
});

/// Timesheets grouped by ISO week, newest first — the unit people submit in.
class TimesheetWeek {
  const TimesheetWeek({
    required this.start,
    required this.entries,
  });

  final DateTime start;
  final List<Timesheet> entries;

  double get totalHours =>
      entries.fold<double>(0, (sum, e) => sum + e.hours);

  double get billableHours => entries
      .where((e) => e.isBillable)
      .fold<double>(0, (sum, e) => sum + e.hours);

  bool get anyDraft => entries.any((e) => e.isDraft);
  bool get allApproved => entries.isNotEmpty && entries.every((e) => e.isApproved);

  DateTime get end => start.add(const Duration(days: 6));
}

final timesheetWeeksProvider =
    FutureProvider.autoDispose<List<TimesheetWeek>>((ref) async {
  final entries = await ref.watch(timesheetsProvider.future);
  final byWeek = <DateTime, List<Timesheet>>{};

  for (final entry in entries) {
    final date = entry.date ?? entry.weekStart;
    if (date == null) continue;
    // Monday of that week.
    final monday = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
    byWeek.putIfAbsent(monday, () => []).add(entry);
  }

  final weeks = byWeek.entries
      .map((e) => TimesheetWeek(start: e.key, entries: e.value))
      .toList()
    ..sort((a, b) => b.start.compareTo(a.start));

  return weeks;
});

// ---- Time off ------------------------------------------------------------

final timeOffProvider = FutureProvider.autoDispose<List<TimeOff>>((ref) {
  return ref.watch(timeOffRepoProvider).list(limit: 100);
});

final myTimeOffProvider = FutureProvider.autoDispose<List<TimeOff>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(timeOffRepoProvider).list(
        limit: 100,
        filters: {'userId': user.id},
      );
});

final holidaysProvider = FutureProvider.autoDispose<List<Holiday>>((ref) {
  return ref.watch(holidayRepoProvider).list(limit: 100);
});

// ---- Expenses ------------------------------------------------------------

final expensesProvider = FutureProvider.autoDispose<List<Expense>>((ref) {
  return ref.watch(expenseRepoProvider).list(limit: 100);
});

// ---- Invoices ------------------------------------------------------------

final invoicesProvider = FutureProvider.autoDispose<List<Invoice>>((ref) {
  return ref.watch(invoiceRepoProvider).list(limit: 100);
});

/// Receivables rollup for the invoices header.
class InvoiceSummary {
  const InvoiceSummary({
    required this.outstanding,
    required this.overdue,
    required this.overdueCount,
    required this.paidThisMonth,
    required this.currency,
  });

  final double outstanding;
  final double overdue;
  final int overdueCount;
  final double paidThisMonth;
  final String currency;

  factory InvoiceSummary.from(List<Invoice> invoices) {
    var outstanding = 0.0;
    var overdue = 0.0;
    var overdueCount = 0;
    var paid = 0.0;
    final now = DateTime.now();
    final tally = <String, int>{};

    for (final invoice in invoices) {
      final code = (invoice.currency ?? 'INR').toUpperCase();
      tally[code] = (tally[code] ?? 0) + 1;

      if (invoice.isPaid) {
        final at = invoice.paidAt;
        if (at != null && at.year == now.year && at.month == now.month) {
          paid += invoice.total ?? 0;
        }
      } else if (!invoice.isCancelled && !invoice.isDraft) {
        outstanding += invoice.balanceDue;
        if (invoice.isOverdue) {
          overdue += invoice.balanceDue;
          overdueCount++;
        }
      }
    }

    final dominant = tally.entries.isEmpty
        ? 'INR'
        : tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return InvoiceSummary(
      outstanding: outstanding,
      overdue: overdue,
      overdueCount: overdueCount,
      paidThisMonth: paid,
      currency: dominant,
    );
  }
}

final invoiceSummaryProvider =
    FutureProvider.autoDispose<InvoiceSummary>((ref) async {
  final invoices = await ref.watch(invoicesProvider.future);
  return InvoiceSummary.from(invoices);
});

// ---- Single records ------------------------------------------------------

final timesheetProvider = FutureProvider.autoDispose.family<Timesheet, String>(
  (ref, id) => ref.watch(timesheetRepoProvider).get(id),
);

final timeOffDetailProvider = FutureProvider.autoDispose.family<TimeOff, String>(
  (ref, id) => ref.watch(timeOffRepoProvider).get(id),
);

final expenseProvider = FutureProvider.autoDispose.family<Expense, String>(
  (ref, id) => ref.watch(expenseRepoProvider).get(id),
);
