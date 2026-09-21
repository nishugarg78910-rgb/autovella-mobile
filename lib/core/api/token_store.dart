import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the bearer token issued by `POST /auth/login`.
///
/// The platform authenticates with `Authorization: Bearer <token>` — there is
/// no session cookie. An earlier build kept the token in memory only, so the
/// app forgot the user on every launch. It lives in the Keychain / Android
/// keystore, not shared preferences, because it is a credential.
class TokenStore {
  const TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'autovella.auth.token';
  static const _rememberKey = 'autovella.auth.remember';

  factory TokenStore.standard() => const TokenStore(
        FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        ),
      );

  Future<String?> read() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      // A corrupt keystore entry must not brick the app; treat it as signed
      // out rather than crashing on launch.
      return null;
    }
  }

  Future<void> write(String token, {required bool remember}) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _rememberKey, value: remember.toString());
    } catch (_) {
      // Non-fatal: the session still works for this run.
    }
  }

  Future<bool> shouldRemember() async {
    try {
      final value = await _storage.read(key: _rememberKey);
      return value != 'false';
    } catch (_) {
      return true;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _rememberKey);
    } catch (_) {
      // Nothing more we can do; the in-memory token is cleared regardless.
    }
  }
}
