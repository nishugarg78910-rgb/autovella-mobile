import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import '../core/providers/app_providers.dart';
import '../models/common.dart';
import '../models/crm.dart';
import '../models/finance.dart';
import '../models/hr.dart';
import '../models/org.dart';
import '../models/work.dart';

/// Generic REST resource.
///
/// Every module in Autovella exposes the same shape — `GET /x`, `GET /x/:id`,
/// `POST /x`, `PUT /x/:id`, `DELETE /x/:id` — so one implementation serves
/// all of them and each module only declares its path and parser.
class Repo<T> {
  const Repo(this._api, this.path, this.parse);

  final ApiClient _api;
  final String path;
  final T Function(Map<String, dynamic>) parse;

  Future<List<T>> list({
    int? page,
    int? limit,
    String? search,
    Map<String, dynamic>? filters,
  }) =>
      _api.list(
        path,
        parse,
        query: {
          if (page != null) 'page': page,
          if (limit != null) 'limit': limit,
          if (search != null && search.isNotEmpty) 'search': search,
          ...?filters,
        },
      );

  Future<T> get(String id) => _api.one('$path/$id', parse);

  Future<T> create(Map<String, dynamic> body) async {
    final data = await _api.post(path, body: body);
    return parse(data is Map<String, dynamic> ? data : {});
  }

  Future<T> update(String id, Map<String, dynamic> body) async {
    final data = await _api.put('$path/$id', body: body);
    return parse(data is Map<String, dynamic> ? data : {});
  }

  Future<void> remove(String id) => _api.delete('$path/$id');
}

// ---- Repository providers ------------------------------------------------
// One line per module. Adding a module to the app is adding a line here plus
// a screen that reads it.

Repo<T> _repo<T>(
  Ref ref,
  String path,
  T Function(Map<String, dynamic>) parse,
) =>
    Repo<T>(ref.watch(apiClientProvider), path, parse);

final projectRepoProvider =
    Provider((ref) => _repo(ref, Api.projects, Project.fromJson));
final taskRepoProvider =
    Provider((ref) => _repo(ref, Api.tasks, Task.fromJson));
final sprintRepoProvider =
    Provider((ref) => _repo(ref, Api.sprints, Sprint.fromJson));
final sectionRepoProvider =
    Provider((ref) => _repo(ref, Api.sections, Section.fromJson));
final subtaskRepoProvider =
    Provider((ref) => _repo(ref, Api.subtasks, Subtask.fromJson));
final commentRepoProvider =
    Provider((ref) => _repo(ref, Api.comments, Comment.fromJson));
final attachmentRepoProvider =
    Provider((ref) => _repo(ref, Api.attachments, Attachment.fromJson));

final accountRepoProvider =
    Provider((ref) => _repo(ref, Api.accounts, Account.fromJson));
final contactRepoProvider =
    Provider((ref) => _repo(ref, Api.contacts, Contact.fromJson));
final dealRepoProvider =
    Provider((ref) => _repo(ref, Api.deals, Deal.fromJson));

final invoiceRepoProvider =
    Provider((ref) => _repo(ref, Api.invoices, Invoice.fromJson));
final expenseRepoProvider =
    Provider((ref) => _repo(ref, Api.expenses, Expense.fromJson));

final attendanceRepoProvider =
    Provider((ref) => _repo(ref, Api.attendance, Attendance.fromJson));
final timesheetRepoProvider =
    Provider((ref) => _repo(ref, Api.timesheets, Timesheet.fromJson));
final timeOffRepoProvider =
    Provider((ref) => _repo(ref, Api.timeOff, TimeOff.fromJson));
final holidayRepoProvider =
    Provider((ref) => _repo(ref, Api.holidays, Holiday.fromJson));

/// The directory route, not `/auth/users`: the latter embeds every user's
/// avatar as a base64 data URI (~190 KB each), which made the People
/// screen download megabytes and appear blank.
final userRepoProvider =
    Provider((ref) => _repo(ref, Api.usersDirectory, userFromJson));
final teamRepoProvider =
    Provider((ref) => _repo(ref, Api.teams, Team.fromJson));
final roleRepoProvider =
    Provider((ref) => _repo(ref, Api.roles, Role.fromJson));
final notificationRepoProvider =
    Provider((ref) => _repo(ref, Api.notifications, AppNotification.fromJson));
final auditRepoProvider =
    Provider((ref) => _repo(ref, Api.auditLogs, AuditEntry.fromJson));
final automationRepoProvider =
    Provider((ref) => _repo(ref, Api.automations, Automation.fromJson));

/// `UserRef.fromJson` is nullable (it returns null for rows with no id, so
/// embedded relations can be skipped). A users *list* needs a total parser,
/// so a malformed row degrades to a placeholder rather than dropping out and
/// silently shortening the list.
UserRef userFromJson(Map<String, dynamic> json) =>
    UserRef.fromJson(json) ??
    const UserRef(id: '', firstName: 'Unknown', lastName: 'user');
