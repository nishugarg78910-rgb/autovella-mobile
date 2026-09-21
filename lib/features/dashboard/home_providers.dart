import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../data/repository.dart';
import '../../models/crm.dart';
import '../../models/finance.dart';
import '../../models/hr.dart';
import '../auth/auth_controller.dart';

/// Runs [work] and swallows any failure, yielding [fallback] instead.
///
/// Home aggregates half a dozen modules. If one of them is disabled for the
/// plan, forbidden for the role, or simply broken, that section should go
/// quiet — not blank the whole screen, which is what happened before.
Future<T> _soft<T>(Future<T> Function() work, T fallback) async {
  try {
    return await work();
  } catch (_) {
    return fallback;
  }
}

/// Work awaiting this user's approval, counted across the three things the
/// platform actually routes for approval.
class ApprovalLoad {
  const ApprovalLoad({
    this.timesheets = 0,
    this.timeOff = 0,
    this.expenses = 0,
  });

  final int timesheets;
  final int timeOff;
  final int expenses;

  int get total => timesheets + timeOff + expenses;
  bool get isEmpty => total == 0;
}

final approvalLoadProvider =
    FutureProvider.autoDispose<ApprovalLoad>((ref) async {
  final api = ref.watch(apiClientProvider);
  final perms = ref.watch(permissionsProvider);
  // Roles carry explicit approval grants (`approveAllTimesheets`,
  // `approveAllTimeOff`, `approveAllExpenses`) alongside module access.
  // Only someone who actually approves should see this card.
  final canApprove = perms.canUpdate('approveAllTimesheets') ||
      perms.canUpdate('approveAllTimeOff') ||
      perms.canUpdate('approveAllExpenses') ||
      perms.canRead('approvals');
  if (!canApprove) return const ApprovalLoad();

  Future<int> count(String path, Map<String, dynamic> query) => _soft(
        () async => ApiClientListLength.of(await api.get(path, query: query)),
        0,
      );

  final results = await Future.wait([
    count(Api.timesheets, {'status': 'submitted', 'limit': 50}),
    count(Api.timeOff, {'status': 'pending', 'limit': 50}),
    count(Api.expenses, {'status': 'pending', 'limit': 50}),
  ]);

  return ApprovalLoad(
    timesheets: results[0],
    timeOff: results[1],
    expenses: results[2],
  );
});

/// Small helper so the counting above does not need the typed list helper.
extension ApiClientListLength on Object? {
  static int of(dynamic data) {
    if (data is List) return data.length;
    if (data is Map) {
      for (final key in const ['items', 'results', 'rows', 'records', 'data']) {
        final value = data[key];
        if (value is List) return value.length;
      }
    }
    return 0;
  }
}

/// Open pipeline, for the sales snapshot.
final homePipelineProvider = FutureProvider.autoDispose<List<Deal>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.canUse('deals', feature: 'crm')) return const [];
  return _soft(
    () => ref.watch(dealRepoProvider).list(limit: 100),
    const <Deal>[],
  );
});

/// Receivables, for the money snapshot.
final homeInvoicesProvider =
    FutureProvider.autoDispose<List<Invoice>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.canUse('invoices', feature: 'invoicing')) {
    return const [];
  }
  return _soft(
    () => ref.watch(invoiceRepoProvider).list(limit: 100),
    const <Invoice>[],
  );
});

/// The next public holiday, so people can see it without opening Time off.
final nextHolidayProvider = FutureProvider.autoDispose<Holiday?>((ref) async {
  final list = await _soft(
    () => ref.watch(holidayRepoProvider).list(limit: 50),
    const <Holiday>[],
  );
  final upcoming = list.where((h) => h.isUpcoming).toList()
    ..sort((a, b) => a.daysAway.compareTo(b.daysAway));
  return upcoming.isEmpty ? null : upcoming.first;
});

/// My approved, upcoming leave.
final myUpcomingLeaveProvider =
    FutureProvider.autoDispose<TimeOff?>((ref) async {
  final list = await _soft(
    () => ref.watch(timeOffRepoProvider).list(limit: 50),
    const <TimeOff>[],
  );
  final upcoming = list.where((t) => t.isUpcoming).toList()
    ..sort((a, b) => (a.startDate ?? DateTime.now())
        .compareTo(b.startDate ?? DateTime.now()));
  return upcoming.isEmpty ? null : upcoming.first;
});
