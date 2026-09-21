import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';
import '../theme/tokens.dart';
import '../widgets/brand.dart';

/// Biometric / device-credential lock.
///
/// A phone carrying a company's pipeline, salaries and invoices should not be
/// readable by whoever picks it up. When enabled, the app locks after
/// [_graceperiod] in the background and asks for the device's own
/// authentication — no separate PIN to forget, and nothing secret stored.
class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this._prefs) : super(const AppLockState()) {
    final enabled = _prefs.getBool(_enabledKey) ?? false;
    state = AppLockState(enabled: enabled, locked: enabled);
    unawaited(_probe());
  }

  static const _enabledKey = 'autovella.lock.enabled';
  static const _graceperiod = Duration(minutes: 2);

  final SharedPreferences _prefs;
  final LocalAuthentication _auth = LocalAuthentication();

  DateTime? _backgroundedAt;

  Future<void> _probe() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final available = await _auth.canCheckBiometrics;
      state = state.copyWith(available: supported || available);
    } catch (e) {
      debugPrint('Biometric probe failed: $e');
      state = state.copyWith(available: false);
    }
  }

  Future<bool> setEnabled(bool value) async {
    if (value) {
      // Prove it works before switching it on, so nobody enables a lock they
      // then cannot pass.
      final ok = await _authenticate(
        reason: 'Confirm it\'s you to turn on the app lock',
      );
      if (!ok) return false;
    }
    await _prefs.setBool(_enabledKey, value);
    state = state.copyWith(enabled: value, locked: false);
    return true;
  }

  /// Called on lifecycle changes by [AppLockGate].
  void onBackgrounded() => _backgroundedAt = DateTime.now();

  void onResumed() {
    if (!state.enabled || state.locked) return;
    final since = _backgroundedAt;
    if (since != null && DateTime.now().difference(since) >= _graceperiod) {
      state = state.copyWith(locked: true);
    }
  }

  Future<bool> unlock() async {
    final ok = await _authenticate(reason: 'Unlock Autovella');
    if (ok) state = state.copyWith(locked: false);
    return ok;
  }

  Future<bool> _authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          // Allow the device PIN as well as a fingerprint or face: biometrics
          // fail often enough (wet hands, a mask) that biometric-only would
          // lock people out of their own work.
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint('Authentication failed: $e');
      return false;
    }
  }

  /// Clears the lock when the user signs out.
  void reset() => state = state.copyWith(locked: false);
}

class AppLockState {
  const AppLockState({
    this.enabled = false,
    this.locked = false,
    this.available = false,
  });

  final bool enabled;
  final bool locked;

  /// Whether the device can authenticate at all.
  final bool available;

  AppLockState copyWith({bool? enabled, bool? locked, bool? available}) =>
      AppLockState(
        enabled: enabled ?? this.enabled,
        locked: locked ?? this.locked,
        available: available ?? this.available,
      );
}

final appLockProvider =
    StateNotifierProvider<AppLockController, AppLockState>(
  (ref) => AppLockController(ref.watch(prefsProvider)),
);

/// Wraps the app, covering it with a lock screen when required.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appLockProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      controller.onResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.onBackgrounded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    return Stack(
      children: [
        widget.child,
        if (lock.enabled && lock.locked)
          const Positioned.fill(child: _LockScreen()),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Prompt immediately; the user expects the sheet, not another tap.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await ref.read(appLockProvider.notifier).unlock();
    if (mounted) {
      setState(() {
        _busy = false;
        _failed = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: DecoratedBox(
        decoration: const BoxDecoration(
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
              const AutovellaLockup(height: 68, onDark: true),
              const SizedBox(height: AppSpacing.xxxl),
              Icon(
                _failed ? Icons.lock_outline_rounded : Icons.fingerprint_rounded,
                size: 42,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _failed ? 'Locked' : 'Unlock to continue',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton.icon(
                onPressed: _busy ? null : _unlock,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.brandNavy,
                  minimumSize: const Size(0, 46),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
