import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_service.dart';
import 'core/offline/offline_queue.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/security/app_lock.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'core/widgets/brand.dart';
import 'features/auth/auth_controller.dart';
import 'features/settings/notification_settings_screen.dart';

class AutovellaApp extends ConsumerWidget {
  const AutovellaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authProvider).status;

    if (status == AuthStatus.checking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ref.watch(themeModeProvider),
        home: const _Splash(),
      );
    }

    return MaterialApp.router(
      title: 'Autovella',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return AppLockGate(
          child: NotificationPoller(
            child: _DeepLinkListener(
              child: MediaQuery(
                // Past ~1.3 the dense rows overflow, and a clipped layout
                // serves nobody who needed the larger type.
                data: media.copyWith(
                  textScaler: media.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.3,
                  ),
                ),
                child: Column(
                  children: [
                    const _OfflineBanner(),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens the record a notification was about — including when the tap is what
/// launched the app, which arrives before the router exists.
class _DeepLinkListener extends ConsumerStatefulWidget {
  const _DeepLinkListener({required this.child});

  final Widget child;

  @override
  ConsumerState<_DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<_DeepLinkListener> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _wire());
  }

  void _wire() {
    if (!mounted) return;
    final service = ref.read(notificationServiceProvider);

    // Cold start: consume the route stashed during init.
    final pending = service.pendingRoute;
    if (pending != null) {
      service.pendingRoute = null;
      _go(pending);
    }

    _sub = service.onTap.listen(_go);
  }

  void _go(String route) {
    if (!mounted) return;
    if (!ref.read(authProvider).isAuthenticated) return;
    ref.read(routerProvider).push(route);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A slim bar that appears only while the device is offline, and says what is
/// waiting to go out.
class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).value ?? true;
    final pending = ref.watch(offlineQueueProvider);
    if (online && pending.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final message = online
        ? '${pending.length} change${pending.length == 1 ? '' : 's'} waiting to sync'
        : pending.isEmpty
            ? 'Offline — changes will be saved and sent later'
            : "Offline — ${pending.length} change${pending.length == 1 ? '' : 's'} queued";

    return Material(
      color: online ? AppColors.warning : AppColors.slate700,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => ref.read(offlineQueueProvider.notifier).flush(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: 6,
            ),
            child: Row(
              children: [
                Icon(
                  online ? Icons.sync_rounded : Icons.cloud_off_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                if (online && pending.isNotEmpty)
                  const Text(
                    'SYNC NOW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandNavy, AppColors.heroGradientEnd],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AutovellaLockup(height: 76, onDark: true),
              SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
