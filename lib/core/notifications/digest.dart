import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../providers/app_providers.dart';
import '../util/json.dart';
import 'notification_service.dart';

/// Everything the app can notify about, beyond the server's own feed.
enum DigestTopic {
  mentions,
  approvals,
  dueToday,
  overdue,
  invoices,
  attendance,
  leave,
}

extension DigestTopicInfo on DigestTopic {
  String get key => 'autovella.notify.$name';

  String get title => switch (this) {
        DigestTopic.mentions => 'Mentions & assignments',
        DigestTopic.approvals => 'Approvals waiting on you',
        DigestTopic.dueToday => 'Work due today',
        DigestTopic.overdue => 'Overdue work',
        DigestTopic.invoices => 'Overdue invoices',
        DigestTopic.attendance => 'Attendance reminder',
        DigestTopic.leave => 'Leave decisions',
      };

  String get blurb => switch (this) {
        DigestTopic.mentions =>
          'When someone @mentions you or assigns you a task.',
        DigestTopic.approvals =>
          'Timesheets, leave and expenses queued for your decision.',
        DigestTopic.dueToday => 'A morning summary of what is due today.',
        DigestTopic.overdue => 'When something you own slips past its date.',
        DigestTopic.invoices => 'When an invoice goes past its due date.',
        DigestTopic.attendance =>
          "If you haven't checked in by mid-morning on a working day.",
        DigestTopic.leave => 'When your leave request is approved or rejected.',
      };

  /// On unless the user turns it off — except attendance, which is a nudge
  /// and should be opt-in.
  bool get defaultOn => this != DigestTopic.attendance;
}

/// Builds and raises the non-feed notifications.
///
/// These are derived client-side because the platform has no push
/// infrastructure: there is no endpoint to register a device token, so the
/// server cannot reach the phone. Everything here fires while the app is
/// running or on resume. Each topic is de-duplicated per day so a morning
/// summary cannot repeat every time the app is opened.
class NotificationDigest {
  const NotificationDigest(this._prefs, this._api, this._service);

  final SharedPreferences _prefs;
  final ApiClient _api;
  final NotificationService _service;

  bool isOn(DigestTopic topic) =>
      _prefs.getBool(topic.key) ?? topic.defaultOn;

  Future<void> setOn(DigestTopic topic, bool value) async {
    await _prefs.setBool(topic.key, value);
  }

  String _todayStamp() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// True the first time this topic runs today.
  Future<bool> _claimToday(DigestTopic topic) async {
    final key = '${topic.key}.lastRun';
    if (_prefs.getString(key) == _todayStamp()) return false;
    await _prefs.setString(key, _todayStamp());
    return true;
  }

  Future<int> _count(String path, Map<String, dynamic> query) async {
    try {
      final data = await _api.get(path, query: query);
      return ApiClient.asList(data).length;
    } catch (_) {
      return 0;
    }
  }

  /// Runs every enabled topic. Safe to call on each resume.
  Future<void> run() async {
    if (!await _service.isAllowed()) return;

    if (isOn(DigestTopic.approvals)) await _approvals();
    if (isOn(DigestTopic.dueToday)) await _dueToday();
    if (isOn(DigestTopic.overdue)) await _overdue();
    if (isOn(DigestTopic.invoices)) await _invoices();
    if (isOn(DigestTopic.attendance)) await _attendance();
  }

  Future<void> _approvals() async {
    final counts = await Future.wait([
      _count(Api.timesheets, {'status': 'submitted', 'limit': 50}),
      _count(Api.timeOff, {'status': 'pending', 'limit': 50}),
      _count(Api.expenses, {'status': 'pending', 'limit': 50}),
    ]);
    final total = counts.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;

    // Notify when the queue *grows*, not on every check — otherwise a stable
    // backlog would nag on every app open.
    const key = 'autovella.notify.approvals.lastCount';
    final previous = _prefs.getInt(key) ?? 0;
    await _prefs.setInt(key, total);
    if (total <= previous) return;

    await _service.show(
      id: 900001,
      title: 'Waiting on you',
      body: '$total ${total == 1 ? 'item needs' : 'items need'} your approval',
      route: '/approvals',
    );
  }

  Future<void> _dueToday() async {
    if (!await _claimToday(DigestTopic.dueToday)) return;
    final tasks = await _myTasks();
    final due = tasks.where((t) => _isDueToday(t)).length;
    if (due == 0) return;
    await _service.show(
      id: 900002,
      title: 'Due today',
      body: '$due ${due == 1 ? 'task is' : 'tasks are'} due today',
      route: '/my-work',
    );
  }

  Future<void> _overdue() async {
    if (!await _claimToday(DigestTopic.overdue)) return;
    final tasks = await _myTasks();
    final late = tasks.where((t) => _isOverdue(t)).length;
    if (late == 0) return;
    await _service.show(
      id: 900003,
      title: 'Overdue work',
      body: '$late ${late == 1 ? 'task has' : 'tasks have'} slipped past '
          'their date',
      route: '/my-work',
    );
  }

  Future<void> _invoices() async {
    if (!await _claimToday(DigestTopic.invoices)) return;
    try {
      final data = await _api.get(Api.invoices, query: {'limit': 100});
      final rows = J.maps(ApiClient.asList(data));
      final now = DateTime.now();
      var count = 0;
      for (final r in rows) {
        final status = J.str(r['status']).toLowerCase();
        if (status == 'paid' || status == 'cancelled' || status == 'draft') {
          continue;
        }
        final due = J.date(r['dueDate']);
        if (due != null && due.isBefore(now)) count++;
      }
      if (count == 0) return;
      await _service.show(
        id: 900004,
        title: 'Overdue invoices',
        body: '$count ${count == 1 ? 'invoice is' : 'invoices are'} past due',
        route: '/invoices',
      );
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _attendance() async {
    final now = DateTime.now();
    // Working days, mid-morning only — a reminder at 7pm helps nobody.
    if (now.weekday >= 6 || now.hour < 10 || now.hour > 12) return;
    if (!await _claimToday(DigestTopic.attendance)) return;
    try {
      final data = await _api.get(Api.attendanceToday);
      final json = J.mapOrNull(data);
      final punches = J.maps(json?['punches']);
      if (punches.isNotEmpty) return;
      await _service.show(
        id: 900005,
        title: 'Not checked in',
        body: 'Tap to record your attendance for today',
        route: '/attendance',
      );
    } catch (_) {
      // Attendance may be off for this plan.
    }
  }

  Future<List<Map<String, dynamic>>> _myTasks() async {
    try {
      final data = await _api.get(Api.tasks, query: {'limit': 100});
      return J.maps(ApiClient.asList(data));
    } catch (_) {
      return const [];
    }
  }

  static bool _isDueToday(Map<String, dynamic> t) {
    final d = J.date(J.pick(t, ['endDate', 'dueDate']));
    if (d == null || _isDone(t)) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  static bool _isOverdue(Map<String, dynamic> t) {
    final d = J.date(J.pick(t, ['endDate', 'dueDate']));
    if (d == null || _isDone(t)) return false;
    final n = DateTime.now();
    return d.isBefore(DateTime(n.year, n.month, n.day));
  }

  static bool _isDone(Map<String, dynamic> t) {
    final s = J.str(t['status']).toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return t['completedAt'] != null ||
        const {'done', 'completed', 'complete', 'closed'}.contains(s);
  }
}

final notificationDigestProvider = Provider<NotificationDigest>(
  (ref) => NotificationDigest(
    ref.watch(prefsProvider),
    ref.watch(apiClientProvider),
    ref.watch(notificationServiceProvider),
  ),
);

/// Rebuilt whenever a topic is toggled, so the settings list redraws.
final digestTopicsProvider =
    StateNotifierProvider<DigestTopics, Map<DigestTopic, bool>>(
  (ref) => DigestTopics(ref.watch(notificationDigestProvider)),
);

class DigestTopics extends StateNotifier<Map<DigestTopic, bool>> {
  DigestTopics(this._digest)
      : super({for (final t in DigestTopic.values) t: _digest.isOn(t)});

  final NotificationDigest _digest;

  Future<void> toggle(DigestTopic topic, bool value) async {
    await _digest.setOn(topic, value);
    state = {...state, topic: value};
    debugPrint('Notification topic ${topic.name} -> $value');
  }
}
