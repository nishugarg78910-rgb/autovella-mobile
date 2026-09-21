// Demo build: the real app — real screens, real models, real repositories,
// real routing — with the network replaced by a fixture set.
//
//   flutter run -d chrome -t lib/demo.dart
//   flutter build web  -t lib/demo.dart --output build/demo
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/token_store.dart';
import 'core/providers/app_providers.dart';
import 'demo/fixtures.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient.ephemeral()..addInterceptor(FixtureInterceptor());
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        prefsProvider.overrideWithValue(prefs),
        // Boot straight into the app so every screen is reachable. Signing
        // out from More still shows the real login screen.
        tokenStoreProvider.overrideWithValue(const _DemoTokenStore()),
      ],
      child: const _DemoChrome(),
    ),
  );
}

/// Hands back a token so the demo starts signed in.
class _DemoTokenStore implements TokenStore {
  const _DemoTokenStore();

  @override
  Future<String?> read() async => 'demo-token';

  @override
  Future<void> write(String token, {required bool remember}) async {}

  @override
  Future<bool> shouldRemember() async => true;

  @override
  Future<void> clear() async {}
}

/// Wraps the real app with a small banner, so nobody mistakes fixture data
/// for their live tenant.
class _DemoChrome extends StatelessWidget {
  const _DemoChrome();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        message: 'DEMO',
        location: BannerLocation.topEnd,
        color: const Color(0xFF7C3AED),
        child: const AutovellaApp(),
      ),
    );
  }
}

/// Resolves every request from [Fixtures] instead of the network.
class FixtureInterceptor extends Interceptor {
  /// A little latency, so loading skeletons and refresh indicators behave the
  /// way they will against a real server rather than snapping instantly.
  static const _latency = Duration(milliseconds: 220);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await Future<void>.delayed(_latency);

    final path = options.path;
    final method = options.method.toUpperCase();
    final data = _resolve(method, path, options.queryParameters);

    if (data == null) {
      return handler.reject(
        DioException(
          requestOptions: options,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 404,
            data: {'success': false, 'message': 'Not available in the demo.'},
          ),
          type: DioExceptionType.badResponse,
        ),
        true,
      );
    }

    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'data': data},
      ),
      true,
    );
  }

  dynamic _resolve(String method, String path, Map<String, dynamic> query) {
    // Writes always succeed; the demo does not persist them.
    if (method != 'GET') {
      if (path == '/auth/login') return {'token': 'demo'};
      if (path == '/auth/password') return {'ok': true};
      return {'id': 'demo-${DateTime.now().millisecondsSinceEpoch}'};
    }

    // ---- Exact matches ------------------------------------------------
    switch (path) {
      case '/auth/me':
        return Fixtures.me;
      case '/attendance/me/today':
        return Fixtures.attendanceToday;
      case '/attendance':
        return Fixtures.attendance;
      case '/notifications':
        return Fixtures.notifications;
      case '/notifications/unread-count':
        return {'count': Fixtures.notifications.where((n) => n['isRead'] == false).length};
      case '/projects':
        return _search(Fixtures.projects, query, ['name']);
      case '/tasks':
        return _tasks(query);
      case '/sprints':
        return _filter(Fixtures.sprints, query, 'projectId');
      case '/subtasks':
        return Fixtures.subtasks;
      case '/comments':
        return Fixtures.comments;
      case '/attachments':
        return Fixtures.attachments;
      case '/analytics/kpis':
        return Fixtures.analyticsKpis;
      case '/analytics/summary':
        return Fixtures.analyticsSummary;
      case '/analytics/teams':
        return Fixtures.analyticsTeams;
      case '/task-schedules':
        return Fixtures.taskSchedules;
      case '/import':
        return Fixtures.imports;
      case '/accounts':
        return _search(Fixtures.accounts, query, ['name']);
      case '/contacts':
        return _search(Fixtures.contacts, query, ['firstName', 'lastName']);
      case '/deals':
        return _search(Fixtures.deals, query, ['name']);
      case '/invoices':
        return Fixtures.invoices;
      case '/expenses':
        return Fixtures.expenses;
      case '/timesheets':
        return Fixtures.timesheets;
      case '/time-off':
        return Fixtures.timeOff;
      case '/holidays':
      case '/holidays/upcoming':
        return Fixtures.holidays;
      case '/auth/users/directory':
      case '/auth/users':
        return Fixtures.users;
      case '/teams':
        return Fixtures.teams;
      case '/templates':
        return Fixtures.templates;
      case '/saved-views':
        return switch (query['entityType']) {
          'tasks' => Fixtures.savedViewsTasks,
          'deals' => Fixtures.savedViewsDeals,
          _ => const <Map<String, dynamic>>[],
        };
      case '/bookmarks':
        return Fixtures.bookmarks;
      case '/roles':
        return Fixtures.roles;
      case '/audit-logs':
        return Fixtures.auditLog;
      case '/automations':
        return Fixtures.automations;
      case '/recycle-bin':
        return Fixtures.recycleBin;
      case '/exchange-rates':
        return Fixtures.exchangeRates;
      case '/search':
        return _globalSearch(query);
    }

    // ---- Detail routes ------------------------------------------------
    final byId = <String, List<Map<String, dynamic>>>{
      '/projects/': Fixtures.projects,
      '/tasks/': Fixtures.tasks,
      '/deals/': Fixtures.deals,
      '/accounts/': Fixtures.accounts,
      '/contacts/': Fixtures.contacts,
      '/invoices/': Fixtures.invoices,
      '/sprints/': Fixtures.sprints,
      '/teams/': Fixtures.teams,
    };
    for (final entry in byId.entries) {
      if (path.startsWith(entry.key)) {
        final id = path.substring(entry.key.length).split('/').first;
        for (final row in entry.value) {
          if (row['id'] == id) return row;
        }
      }
    }

    if (path.startsWith('/teams/') && path.endsWith('/members')) {
      return Fixtures.teamMembers;
    }

    // Project sub-collections.
    if (path.startsWith('/projects/') && path.endsWith('/tasks')) {
      final id = path.split('/')[2];
      return Fixtures.tasks.where((t) => t['projectId'] == id).toList();
    }

    return null;
  }

  List<Map<String, dynamic>> _tasks(Map<String, dynamic> query) {
    var rows = Fixtures.tasks;
    final projectId = query['projectId'];
    if (projectId != null) {
      rows = rows.where((t) => t['projectId'] == projectId).toList();
    }
    final sprintId = query['sprintId'];
    if (sprintId != null) {
      rows = rows.where((t) => t['sprintId'] == sprintId).toList();
    }
    return _search(rows, query, ['title']);
  }

  List<Map<String, dynamic>> _filter(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> query,
    String key,
  ) {
    final value = query[key];
    if (value == null) return rows;
    return rows.where((r) => r[key] == value).toList();
  }

  List<Map<String, dynamic>> _search(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> query,
    List<String> fields,
  ) {
    final term = (query['search'] ?? query['q'])?.toString().toLowerCase();
    if (term == null || term.isEmpty) return rows;
    return rows.where((row) {
      for (final field in fields) {
        final value = '${row[field] ?? ''}'.toLowerCase();
        if (value.contains(term)) return true;
      }
      return false;
    }).toList();
  }

  Map<String, dynamic> _globalSearch(Map<String, dynamic> query) => {
        'tasks': _search(Fixtures.tasks, query, ['title']),
        'projects': _search(Fixtures.projects, query, ['name']),
        'deals': _search(Fixtures.deals, query, ['name']),
        'accounts': _search(Fixtures.accounts, query, ['name']),
        'contacts': _search(Fixtures.contacts, query, ['firstName', 'lastName']),
      };
}
