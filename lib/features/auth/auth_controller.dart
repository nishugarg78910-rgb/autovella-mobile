import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/token_store.dart';
import '../../core/providers/app_providers.dart';
import '../../models/org.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.checking,
    this.user,
    this.error,
    this.isSubmitting = false,
  });

  final AuthStatus status;
  final CurrentUser? user;
  final String? error;
  final bool isSubmitting;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    CurrentUser? user,
    String? error,
    bool? isSubmitting,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: clearError ? null : (error ?? this.error),
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );
}

/// Owns the session.
///
/// `POST /auth/login` answers `{data: {user, token}}`; that token is the only
/// credential the API accepts, so it is written to secure storage and loaded
/// back before the first request on launch. That is what keeps the user
/// signed in between app starts.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api, this._tokens) : super(const AuthState()) {
    _sub = _api.onUnauthorized.listen((_) {
      if (state.status == AuthStatus.authenticated) {
        unawaited(_tokens.clear());
        _api.setToken(null);
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Your session expired. Please sign in again.',
        );
      }
    });
    unawaited(restore());
  }

  final ApiClient _api;
  final TokenStore _tokens;
  StreamSubscription<void>? _sub;

  /// Reloads the stored token and confirms it is still valid.
  Future<void> restore() async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    _api.setToken(token);
    try {
      final user = await _api.one(Api.me, CurrentUser.fromJson);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // The token is genuinely dead — forget it.
        await _tokens.clear();
        _api.setToken(null);
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        // Offline or a server blip is *not* a sign-out. Keep the token and
        // let the user back in; individual screens will show their own error.
        state = AuthState(
          status: AuthStatus.unauthenticated,
          error: e.message,
        );
      }
    }
  }

  Future<bool> signIn({
    required String identifier,
    required String password,
    bool remember = true,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final data = await _api.post(
        Api.login,
        body: {
          'identifier': identifier.trim(),
          'password': password,
          'timezone': deviceTimezone(),
        },
      );

      final map = data is Map ? data : const {};
      final token = '${map['token'] ?? ''}';
      if (token.isEmpty) {
        state = state.copyWith(
          isSubmitting: false,
          error: 'The server did not return a session token.',
        );
        return false;
      }

      _api.setToken(token);
      await _tokens.write(token, remember: remember);

      // The login response embeds the user, but /auth/me is the canonical
      // shape (it carries rolePermissions and the organization).
      final user = await _api.one(Api.me, CurrentUser.fromJson);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.message);
      return false;
    }
  }

  /// There is no server-side logout route — the web client simply discards
  /// the token, so this does the same.
  Future<void> signOut() async {
    await _tokens.clear();
    _api.setToken(null);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> refreshUser() async {
    if (!state.isAuthenticated) return;
    try {
      final user = await _api.one(Api.me, CurrentUser.fromJson);
      state = state.copyWith(user: user);
    } on ApiException {
      // Keep the cached user; a 401 is handled by the listener.
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// Best-effort IANA timezone.
  ///
  /// Dart exposes only an abbreviation (`IST`) and a UTC offset, not an IANA
  /// name, and the login endpoint wants the latter. Rather than add a plugin
  /// for one string, the common offsets are mapped directly — India first,
  /// since that is where this platform is used — and anything unrecognised
  /// falls back to UTC, which the server accepts.
  static String deviceTimezone() {
    final offset = DateTime.now().timeZoneOffset;
    const byMinutes = <int, String>{
      330: 'Asia/Kolkata',
      345: 'Asia/Kathmandu',
      300: 'Asia/Karachi',
      360: 'Asia/Dhaka',
      240: 'Asia/Dubai',
      480: 'Asia/Singapore',
      540: 'Asia/Tokyo',
      0: 'Etc/UTC',
      60: 'Europe/Paris',
      120: 'Europe/Athens',
      -300: 'America/New_York',
      -360: 'America/Chicago',
      -480: 'America/Los_Angeles',
    };
    return byMinutes[offset.inMinutes] ?? 'Etc/UTC';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);

final currentUserProvider =
    Provider<CurrentUser?>((ref) => ref.watch(authProvider).user);

final permissionsProvider = Provider<Permissions>(
  (ref) => ref.watch(currentUserProvider)?.permissions ?? const Permissions({}),
);
