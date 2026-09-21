import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../../models/app_config.dart';
import '../../models/work.dart';

/// The organisation's configuration.
///
/// Kept alive rather than auto-disposed: every list screen consults it, and
/// re-fetching statuses on each navigation would be wasteful. It falls back
/// to the web client's own built-in defaults if the request fails, so the app
/// still works — it just cannot know about customised statuses.
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  try {
    final data = await ref.watch(apiClientProvider).get(Api.appConfig);
    return AppConfig.fromJson(data);
  } catch (_) {
    return const AppConfig();
  }
});

/// Synchronous access with a safe default, for widgets that cannot await.
final configProvider = Provider<AppConfig>(
  (ref) => ref.watch(appConfigProvider).value ?? const AppConfig(),
);

final taskStatusesProvider =
    Provider<StatusCatalog>((ref) => ref.watch(configProvider).taskStatuses);

final projectStatusesProvider =
    Provider<StatusCatalog>((ref) => ref.watch(configProvider).projectStatuses);

/// The organisation's currency, used wherever a record does not carry one.
final defaultCurrencyProvider =
    Provider<String>((ref) => ref.watch(configProvider).defaultCurrency);

/// Task state resolved against the organisation's own status definitions.
///
/// `Task.isDone` matches on the *name* of the status, which is only correct
/// for an org using the stock statuses. These read the `isCompleted` flag,
/// which is what the web client does.
extension TaskStatusX on Task {
  bool isDoneIn(StatusCatalog catalog) =>
      completedAt != null || catalog.isCompleted(status);

  bool isOverdueIn(StatusCatalog catalog) {
    final end = endDate;
    if (end == null || isDoneIn(catalog)) return false;
    final now = DateTime.now();
    return end.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool isDueTodayIn(StatusCatalog catalog) {
    final end = endDate;
    if (end == null || isDoneIn(catalog)) return false;
    final now = DateTime.now();
    return end.year == now.year &&
        end.month == now.month &&
        end.day == now.day;
  }
}
