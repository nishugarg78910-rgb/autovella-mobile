/// Every REST route the mobile client talks to.
///
/// These are no longer guesses. Each path below was taken from the web
/// platform's own JavaScript bundles (`/assets/dist/chunks/*.js`), which is
/// the authoritative client of this API, and cross-checked against the MCP
/// tool surface. The previous version of this file inferred paths from page
/// route names, which is why several modules failed on device.
///
/// Probing note: an unknown *top-level* path answers 500, a real one answers
/// 401 when unauthenticated. Sub-paths always answer 401 (auth middleware
/// runs before routing), so sub-paths here come from the bundles, not probes.
class Api {
  const Api._();

  static const baseUrl = String.fromEnvironment(
    'AUTOVELLA_BASE_URL',
    defaultValue: 'https://autovella.cloud',
  );

  static const apiRoot = '$baseUrl/api';

  // ---- Auth & identity -------------------------------------------------
  // POST /auth/login takes {identifier, password, timezone} and answers
  // {success, data: {user, token}}. The token is a bearer token; there is no
  // session cookie and no server-side logout route — signing out is purely
  // discarding the token client-side.
  static const login = '/auth/login';
  static const me = '/auth/me';
  static const profile = '/auth/profile';
  static const changePassword = '/auth/password';
  static const loginAccess = '/auth/login-access';
  static const appConfig = '/appconfig';

  /// Lightweight people list: id, name, email, role — and crucially *not*
  /// the base64 avatar blobs that make `/auth/users` enormous.
  static const usersDirectory = '/auth/users/directory';
  static const users = '/auth/users';
  static String user(String id) => '/auth/users/$id';
  static String person(String id) => '/people/$id';

  // ---- Work management -------------------------------------------------
  static const projects = '/projects';
  static String project(String id) => '/projects/$id';
  static const projectSearch = '/projects/search';
  static const resourcePlanner = '/projects/resource-planner';

  static const tasks = '/tasks';
  static String task(String id) => '/tasks/$id';
  static const subtasks = '/subtasks';
  static String subtask(String id) => '/subtasks/$id';
  static const sections = '/sections';
  static const sprints = '/sprints';
  static String sprint(String id) => '/sprints/$id';
  static const sprintVelocity = '/sprints/velocity';
  static const taskSchedules = '/task-schedules';
  static const taskSchedulesBulk = '/task-schedules/bulk';
  static const search = '/search';

  // ---- CRM -------------------------------------------------------------
  // NOTE: /leads, /customers, /vehicles, /inventory and /resources do NOT
  // exist on this platform. They were in an earlier build by mistake.
  static const accounts = '/accounts';
  static String account(String id) => '/accounts/$id';
  static const accountSearch = '/accounts/search';
  static const contacts = '/contacts';
  static String contact(String id) => '/contacts/$id';
  static const deals = '/deals';
  static String deal(String id) => '/deals/$id';

  // ---- Time & attendance ----------------------------------------------
  static const attendance = '/attendance';
  static String attendanceRecord(String id) => '/attendance/$id';
  static const attendanceToday = '/attendance/me/today';
  static const attendancePunch = '/attendance/punch';

  static const timesheets = '/timesheets';
  static String timesheet(String id) => '/timesheets/$id';
  static String timesheetSubmit(String id) => '/timesheets/$id/submit';
  static String timesheetApprove(String id) => '/timesheets/$id/approve';
  static String timesheetReject(String id) => '/timesheets/$id/reject';

  static const timeOff = '/time-off';
  static String timeOffRecord(String id) => '/time-off/$id';
  static String timeOffApprove(String id) => '/time-off/$id/approve';
  static String timeOffReject(String id) => '/time-off/$id/reject';
  static String timeOffCancel(String id) => '/time-off/$id/cancel';
  static const timeOffSummary = '/time-off/summary';
  static const timeOffTeam = '/time-off/team';

  static const holidays = '/holidays';
  static String holiday(String id) => '/holidays/$id';
  static const upcomingHolidays = '/holidays/upcoming';
  static const holidayLocations = '/holidays/locations';

  // ---- Finance ---------------------------------------------------------
  static const invoices = '/invoices';
  static String invoice(String id) => '/invoices/$id';
  static String invoiceSend(String id) => '/invoices/$id/send';
  static String invoicePay(String id) => '/invoices/$id/pay';
  static const generateInvoice = '/invoices/generate';

  static const expenses = '/expenses';
  static String expense(String id) => '/expenses/$id';
  static String expenseApprove(String id) => '/expenses/$id/approve';
  static String expenseReject(String id) => '/expenses/$id/reject';

  static const exchangeRates = '/exchange-rates';

  // ---- Org -------------------------------------------------------------
  static const teams = '/teams';
  static String team(String id) => '/teams/$id';
  static String teamMembers(String id) => '/teams/$id/members';
  static const roles = '/roles';
  static String role(String id) => '/roles/$id';
  static const rolePermissions = '/roles/permissions';

  // ---- Collaboration ---------------------------------------------------
  static const comments = '/comments';
  static String comment(String id) => '/comments/$id';
  static const attachments = '/attachments';
  static const latestImages = '/attachments/latest-images';
  static const notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const notificationsUnread = '/notifications/unread-count';
  static const notificationsReadAll = '/notifications/read-all';
  static const notificationPrefs = '/notifications/preferences';
  static const mentions = '/notifications/mentions';
  static const bookmarks = '/bookmarks';
  static String bookmark(String id) => '/bookmarks/$id';

  // ---- Configuration ---------------------------------------------------
  static const automations = '/automations';
  static String automation(String id) => '/automations/$id';
  static String automationToggle(String id) => '/automations/$id/toggle';
  static String automationRuns(String id) => '/automations/$id/runs';
  static const templates = '/templates';
  static String templateUse(String id) => '/templates/$id/use';
  static const savedViews = '/saved-views';
  static const dataImport = '/import';

  // ---- Analytics & governance -----------------------------------------
  static const analyticsSummary = '/analytics/summary';
  static const analyticsKpis = '/analytics/kpis';
  static const analyticsTeams = '/analytics/teams';

  /// Plural. The singular `/audit-log` does not exist — that was the bug
  /// behind "audit log isn't opening".
  static const auditLogs = '/audit-logs';
  static const auditActors = '/audit-logs/actors';

  static const recycleBin = '/recycle-bin';
  static String recycleRestore(String id) => '/recycle-bin/$id/restore';
  static const recycleEmpty = '/recycle-bin/empty';
}
