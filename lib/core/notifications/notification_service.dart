import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../providers/app_providers.dart';
import '../util/json.dart';

/// OS-level notifications.
///
/// Scope, stated plainly: this asks for permission and delivers notifications
/// the app raises itself, including when it polls and finds something new.
/// It is *not* server push — that needs FCM on Android, APNs on iOS, and a
/// backend endpoint to register a device token, none of which the platform
/// exposes today. Everything here works without server changes.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'autovella_general';
  static const _seenKey = 'autovella.notifications.lastSeenId';

  bool _ready = false;

  /// Route a notification tap should open. Set when the app is launched *by*
  /// a notification (cold start), so the router can consume it once it is
  /// ready, and pushed live when a tap arrives while running.
  String? pendingRoute;
  final _taps = StreamController<String>.broadcast();
  Stream<String> get onTap => _taps.stream;

  static NotificationService create() =>
      NotificationService(FlutterLocalNotificationsPlugin());

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      // Asked for explicitly later, so the prompt appears at a moment the
      // user understands rather than on first launch.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  /// Whether the OS currently allows notifications.
  Future<bool> isAllowed() async {
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Prompts for permission. Returns true if granted.
  Future<bool> requestPermission() async {
    await init();
    try {
      final status = await Permission.notification.request();
      if (status.isGranted) return true;

      // iOS needs its own ask through the plugin.
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    String? body,
    String? route,
  }) async {
    await init();
    if (!await isAllowed()) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Autovella',
            channelDescription: 'Mentions, assignments and approvals',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: route,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// Fetches unread notifications and raises one for anything not seen yet.
  ///
  /// The newest id seen is remembered, so re-checking does not re-notify for
  /// the same item.
  Future<void> pollAndNotify(ApiClient api, SharedPreferences prefs) async {
    if (!await isAllowed()) return;
    try {
      final data = await api.get(Api.notifications, query: {'limit': 15});
      final rows = J.maps(ApiClient.asList(data));
      final unread = rows
          .where((r) => !J.boolVal(J.pick(r, ['isRead', 'read'])))
          .toList();
      if (unread.isEmpty) return;

      final lastSeen = prefs.getString(_seenKey);
      final newest = J.str(unread.first['id']);

      // First run just records where we are — otherwise the user gets a burst
      // of notifications for history they have already scrolled past.
      if (lastSeen == null) {
        await prefs.setString(_seenKey, newest);
        return;
      }
      if (newest == lastSeen) return;

      final fresh = <Map<String, dynamic>>[];
      for (final row in unread) {
        if (J.str(row['id']) == lastSeen) break;
        fresh.add(row);
      }

      for (var i = 0; i < fresh.length && i < 5; i++) {
        final row = fresh[i];
        await show(
          id: row['id'].hashCode & 0x7fffffff,
          title: J.str(
            J.pick(row, ['title', 'subject', 'message']),
            'Autovella',
          ),
          body: J.strOrNull(J.pick(row, ['body', 'description'])),
          route: routeFor(row),
        );
      }
      await prefs.setString(_seenKey, newest);
    } catch (e) {
      debugPrint('Notification poll failed: $e');
    }
  }
}

/// Maps a notification to the screen it is about.
String? routeFor(Map<String, dynamic> row) {
  final id = J.strOrNull(J.pick(row, ['entityId', 'resourceId']));
  if (id == null) return '/notifications';
  final type = J.str(J.pick(row, ['entityType', 'resourceType'])).toLowerCase();
  return switch (type) {
    'task' => '/tasks/$id',
    'project' => '/projects/$id',
    'deal' => '/deals/$id',
    'account' => '/accounts/$id',
    'contact' => '/contacts/$id',
    'invoice' => '/invoices/$id',
    'sprint' => '/sprints/$id',
    'timesheet' || 'timeoff' || 'expense' => '/approvals',
    _ => '/notifications',
  };
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.create(),
);

/// Whether the OS permission is currently granted.
final notificationsAllowedProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  return ref.watch(notificationServiceProvider).isAllowed();
});

/// Server-side notification preferences (`/notifications/preferences`).
final notificationPrefsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final data = await ref.watch(apiClientProvider).get(Api.notificationPrefs);
    return J.map(data);
  } catch (_) {
    return const {};
  }
});
