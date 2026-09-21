import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/analytics_screen.dart';
import '../../features/audit/audit_log_screen.dart';
import '../../features/approvals/approvals_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/crm/crm_detail_screens.dart';
import '../../features/crm/crm_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/finance/invoice_detail_screen.dart';
import '../../features/import/data_import_screen.dart';
import '../../features/planner/resource_planner_screen.dart';
import '../../features/teams/team_detail_screen.dart';
import '../../features/finance/invoices_screen.dart';
import '../../features/forms/edit_forms.dart';
import '../../features/forms/quick_forms.dart';
import '../../features/modules/module_list_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/people/people_screen.dart';
import '../../features/recycle/recycle_bin_screen.dart';
import '../../features/settings/notification_settings_screen.dart';
import '../../features/settings/security_settings_screen.dart';
import '../../features/views/saved_views_screen.dart';
import '../../features/work/sprint_detail_screen.dart';
import '../../features/profile/change_password_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/psa/expenses_screen.dart';
import '../../features/psa/psa_detail_screens.dart';
import '../../features/psa/time_off_screen.dart';
import '../../features/psa/timesheets_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/shell/home_shell.dart';
import '../../features/work/my_work_screen.dart';
import '../../features/work/project_detail_screen.dart';
import '../../features/work/projects_screen.dart';
import '../../features/work/task_detail_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Republishes auth changes as a [Listenable] so go_router re-evaluates its
/// redirect the moment the session starts or ends.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (previous?.status != next.status) notifyListeners();
      },
    );
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loggingIn = state.matchedLocation == '/login';

      // Hold on the splash while the persisted session is being checked, so
      // the login screen does not flash for an already-signed-in user.
      if (auth.status == AuthStatus.checking) return null;

      if (!auth.isAuthenticated) return loggingIn ? null : '/login';
      if (loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),

      // The five-tab shell. Each branch keeps its own navigation stack, so
      // switching tabs does not lose your place.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-work',
                builder: (_, __) => const MyWorkScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/projects',
                builder: (_, __) => const ProjectsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/crm', builder: (_, __) => const CrmScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
            ],
          ),
        ],
      ),

      // ---- Work ----------------------------------------------------------
      GoRoute(
        path: '/projects/new',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NewProjectScreen(),
      ),
      GoRoute(
        path: '/projects/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/projects/:id/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            EditProjectScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tasks/new',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            NewTaskScreen(projectId: state.uri.queryParameters['projectId']),
      ),
      GoRoute(
        path: '/tasks/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            TaskDetailScreen(taskId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tasks/:id/edit',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            EditTaskScreen(taskId: state.pathParameters['id']!),
      ),
      _module('/sprints', Modules.sprints),
      GoRoute(
        path: '/sprints/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            SprintDetailScreen(sprintId: state.pathParameters['id']!),
      ),

      // ---- CRM -----------------------------------------------------------
      GoRoute(
        path: '/deals/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            DealDetailScreen(dealId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/accounts/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            AccountDetailScreen(accountId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/contacts/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ContactDetailScreen(contactId: state.pathParameters['id']!),
      ),

      // ---- Time & attendance ---------------------------------------------
      GoRoute(
        path: '/attendance',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/timesheets',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const TimesheetsScreen(),
      ),
      GoRoute(
        path: '/timesheets/new',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NewTimesheetScreen(),
      ),
      GoRoute(
        path: '/time-off',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const TimeOffScreen(),
      ),
      GoRoute(
        path: '/time-off/new',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NewTimeOffScreen(),
      ),
      GoRoute(
        path: '/people',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PeopleScreen(),
      ),
      GoRoute(
        path: '/approvals',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ApprovalsScreen(),
      ),
      GoRoute(
        path: '/recycle-bin',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const RecycleBinScreen(),
      ),
      GoRoute(
        path: '/notification-settings',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/security',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: '/audit-log',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const AuditLogScreen(),
      ),
      GoRoute(
        path: '/resource-planner',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ResourcePlannerScreen(),
      ),
      GoRoute(
        path: '/import',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const DataImportScreen(),
      ),
      _module('/holidays', Modules.holidays),

      // ---- Finance --------------------------------------------------------
      GoRoute(
        path: '/invoices',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const InvoicesScreen(),
      ),
      GoRoute(
        path: '/invoices/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            InvoiceDetailScreen(invoiceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/expenses',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ExpensesScreen(),
      ),
      // The dashboard's "Add expense" shortcut lands on the list, whose
      // primary action is the camera.
      GoRoute(
        path: '/expenses/new',
        parentNavigatorKey: _rootKey,
        redirect: (_, __) => '/expenses',
      ),

      // Declared after the literal `/new` routes above: go_router matches
      // in order, so `:id` would otherwise capture "new".
      GoRoute(
        path: '/timesheets/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            TimesheetDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/time-off/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            TimeOffDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/expenses/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ExpenseDetailScreen(id: state.pathParameters['id']!),
      ),
      _module('/exchange-rates', Modules.exchangeRates),


      // ---- Organisation ---------------------------------------------------
      GoRoute(
        path: '/teams',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const TeamsScreen(),
      ),
      _module('/roles', Modules.roles),

      // ---- Insight & config -----------------------------------------------
      GoRoute(
        path: '/analytics',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/calendar',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile/password',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ProfileScreen(),
      ),
      // Settings on mobile is the profile screen; org-wide configuration
      // stays on the web app where it belongs.
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        redirect: (_, __) => '/profile',
      ),
      _module('/automations', Modules.automations),
      _module('/templates', Modules.templates),
      GoRoute(
        path: '/saved-views',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SavedViewsScreen(),
      ),
      _module('/bookmarks', Modules.bookmarks),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No screen for ${state.uri}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    ),
  );
});

/// Shorthand for a module that runs on the generic list screen.
GoRoute _module(String path, ModuleSpec spec) => GoRoute(
      path: path,
      parentNavigatorKey: _rootKey,
      builder: (_, __) => ModuleListScreen(spec: spec),
    );
