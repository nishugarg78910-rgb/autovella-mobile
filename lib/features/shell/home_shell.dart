import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/endpoints.dart';
import '../../core/providers/app_providers.dart';
import '../auth/auth_controller.dart';

/// Unread notification badge count, polled when the shell builds.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final data = await api.get(Api.notificationsUnread);
    if (data is int) return data;
    if (data is Map) {
      for (final key in const ['count', 'unread', 'unreadCount', 'total']) {
        final v = data[key];
        if (v is int) return v;
        if (v is num) return v.toInt();
      }
    }
    return 0;
  } catch (_) {
    // A badge is not worth surfacing an error for.
    return 0;
  }
});

/// The five-tab shell.
///
/// The web app carries a 30-item sidebar. That does not survive contact with a
/// phone, so mobile promotes the four things people open daily — Home, My
/// Work, Projects, CRM — and puts the full module list behind "More". Nothing
/// is dropped; it is re-ranked for the smaller surface.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final perms = ref.watch(permissionsProvider);

    // Hide CRM entirely when the plan or the role does not include it, rather
    // than showing a tab that dead-ends in a 403.
    final showCrm = (user?.organization?.hasFeature('crm') ?? true) &&
        perms.canRead('deals');

    // Android back on a non-Home tab should return to Home rather than
    // closing the app — the previous build exited from whichever tab you
    // happened to be on.
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0, initialLocation: true);
        }
      },
      child: Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the active tab pops that branch back to its root, which
          // is the behaviour people expect from every native app.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded),
            label: 'My Work',
          ),
          const NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(
              showCrm ? Icons.handshake_outlined : Icons.calendar_today_outlined,
            ),
            selectedIcon: Icon(
              showCrm ? Icons.handshake_rounded : Icons.calendar_today_rounded,
            ),
            label: showCrm ? 'CRM' : 'Calendar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'More',
          ),
        ],
      ),
      ),
    );
  }
}

/// Shared app bar action: notifications bell with an unread badge.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider).value ?? 0;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notifications',
        ),
        if (count > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
