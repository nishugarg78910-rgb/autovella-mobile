import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository.dart';
import '../../models/work.dart';
import '../../models/app_config.dart';
import '../auth/auth_controller.dart';
import '../config/app_config_provider.dart';

/// Filters for the task list, shared by My Work and a project's task tab.
class TaskQuery {
  const TaskQuery({
    this.projectId,
    this.sprintId,
    this.assignedTo,
    this.status,
    this.priority,
    this.search,
    this.limit = 50,
  });

  final String? projectId;
  final String? sprintId;
  final String? assignedTo;
  final String? status;
  final String? priority;
  final String? search;
  final int limit;

  Map<String, dynamic> toQuery() => {
        if (projectId != null) 'projectId': projectId,
        if (sprintId != null) 'sprintId': sprintId,
        if (assignedTo != null) 'assignedTo': assignedTo,
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
      };

  @override
  bool operator ==(Object other) =>
      other is TaskQuery &&
      other.projectId == projectId &&
      other.sprintId == sprintId &&
      other.assignedTo == assignedTo &&
      other.status == status &&
      other.priority == priority &&
      other.search == search &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(
        projectId,
        sprintId,
        assignedTo,
        status,
        priority,
        search,
        limit,
      );
}

final tasksProvider =
    FutureProvider.autoDispose.family<List<Task>, TaskQuery>((ref, query) {
  return ref.watch(taskRepoProvider).list(
        limit: query.limit,
        search: query.search,
        filters: query.toQuery(),
      );
});

/// Everything assigned to the signed-in user.
final myTasksProvider = FutureProvider.autoDispose<List<Task>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(taskRepoProvider).list(
        limit: 100,
        filters: {'assignedTo': user.id},
      );
});

/// My Work, bucketed the way someone actually triages a day.
class MyWorkBuckets {
  const MyWorkBuckets({
    required this.overdue,
    required this.today,
    required this.upcoming,
    required this.noDate,
    required this.completed,
  });

  final List<Task> overdue;
  final List<Task> today;
  final List<Task> upcoming;
  final List<Task> noDate;
  final List<Task> completed;

  int get openCount =>
      overdue.length + today.length + upcoming.length + noDate.length;

  bool get isEmpty => openCount == 0 && completed.isEmpty;

  /// Buckets by the organisation's own status definitions — a task whose
  /// status is flagged `isCompleted` counts as done even if it is called
  /// "Shipped".
  factory MyWorkBuckets.from(List<Task> tasks, StatusCatalog catalog) {
    final overdue = <Task>[];
    final today = <Task>[];
    final upcoming = <Task>[];
    final noDate = <Task>[];
    final completed = <Task>[];

    for (final task in tasks) {
      if (task.isDoneIn(catalog)) {
        completed.add(task);
      } else if (task.isOverdueIn(catalog)) {
        overdue.add(task);
      } else if (task.isDueTodayIn(catalog)) {
        today.add(task);
      } else if (task.endDate != null) {
        upcoming.add(task);
      } else {
        noDate.add(task);
      }
    }

    int byDate(Task a, Task b) {
      final x = a.endDate;
      final y = b.endDate;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    }

    overdue.sort(byDate);
    upcoming.sort(byDate);

    return MyWorkBuckets(
      overdue: overdue,
      today: today,
      upcoming: upcoming,
      noDate: noDate,
      completed: completed,
    );
  }
}

final myWorkProvider = FutureProvider.autoDispose<MyWorkBuckets>((ref) async {
  final tasks = await ref.watch(myTasksProvider.future);
  return MyWorkBuckets.from(tasks, ref.watch(taskStatusesProvider));
});

// ---- Projects ------------------------------------------------------------

final projectsProvider =
    FutureProvider.autoDispose.family<List<Project>, String?>(
  (ref, search) =>
      ref.watch(projectRepoProvider).list(limit: 100, search: search),
);

final projectProvider =
    FutureProvider.autoDispose.family<Project, String>((ref, id) {
  return ref.watch(projectRepoProvider).get(id);
});

final projectTasksProvider =
    FutureProvider.autoDispose.family<List<Task>, String>((ref, projectId) {
  return ref.watch(taskRepoProvider).list(
        limit: 100,
        filters: {'projectId': projectId},
      );
});

final taskProvider = FutureProvider.autoDispose.family<Task, String>(
  (ref, id) => ref.watch(taskRepoProvider).get(id),
);

final taskCommentsProvider =
    FutureProvider.autoDispose.family<List<Comment>, String>((ref, taskId) {
  return ref.watch(commentRepoProvider).list(
        filters: {'taskId': taskId, 'entityType': 'task', 'entityId': taskId},
      );
});

final subtasksProvider =
    FutureProvider.autoDispose.family<List<Subtask>, String>((ref, taskId) {
  return ref.watch(subtaskRepoProvider).list(filters: {'taskId': taskId});
});

// ---- Sprints -------------------------------------------------------------

final sprintsProvider =
    FutureProvider.autoDispose.family<List<Sprint>, String?>((ref, projectId) {
  return ref.watch(sprintRepoProvider).list(
        limit: 50,
        filters: {if (projectId != null) 'projectId': projectId},
      );
});

final sprintProvider = FutureProvider.autoDispose.family<Sprint, String>(
  (ref, id) => ref.watch(sprintRepoProvider).get(id),
);

final sprintTasksProvider =
    FutureProvider.autoDispose.family<List<Task>, String>((ref, sprintId) {
  return ref.watch(taskRepoProvider).list(
        limit: 100,
        filters: {'sprintId': sprintId},
      );
});
