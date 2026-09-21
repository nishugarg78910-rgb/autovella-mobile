import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../providers/app_providers.dart';

/// A write that could not be sent because the device was offline.
class PendingWrite {
  const PendingWrite({
    required this.id,
    required this.method,
    required this.path,
    required this.label,
    this.body,
    required this.queuedAt,
    this.attempts = 0,
  });

  final String id;

  /// 'POST' | 'PUT' | 'PATCH' | 'DELETE'
  final String method;
  final String path;

  /// Human description, shown in the pending list — "Log 7.5h on Apollo".
  final String label;
  final Map<String, dynamic>? body;
  final DateTime queuedAt;
  final int attempts;

  PendingWrite copyWith({int? attempts}) => PendingWrite(
        id: id,
        method: method,
        path: path,
        label: label,
        body: body,
        queuedAt: queuedAt,
        attempts: attempts ?? this.attempts,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'label': label,
        'body': body,
        'queuedAt': queuedAt.toIso8601String(),
        'attempts': attempts,
      };

  static PendingWrite? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String) return null;
    return PendingWrite(
      id: id,
      method: '${json['method'] ?? 'POST'}',
      path: '${json['path'] ?? ''}',
      label: '${json['label'] ?? 'Change'}',
      body: json['body'] is Map<String, dynamic>
          ? json['body'] as Map<String, dynamic>
          : null,
      queuedAt: DateTime.tryParse('${json['queuedAt']}') ?? DateTime.now(),
      attempts: json['attempts'] is int ? json['attempts'] as int : 0,
    );
  }
}

/// Holds writes made while offline and replays them when the network returns.
///
/// Scope is deliberate: **writes only**. Reads already fail gracefully with a
/// retry. A field engineer logging time in a basement should not lose the
/// entry, so the write is queued, shown as pending, and sent on reconnect.
///
/// A queued write is dropped after [_maxAttempts] failures that are *not*
/// network failures — a 400 will never succeed on retry, and silently retrying
/// it forever would hide a real error from the user.
class OfflineQueue extends StateNotifier<List<PendingWrite>> {
  OfflineQueue(this._prefs, this._api) : super(const []) {
    _load();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _online) {
        _online = online;
        if (online) unawaited(flush());
      }
    });
    unawaited(_checkConnectivity());
  }

  static const _key = 'autovella.offline.queue';
  static const _maxAttempts = 3;

  final SharedPreferences _prefs;
  final ApiClient _api;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _online = true;
  bool get isOnline => _online;

  bool _flushing = false;

  Future<void> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _online = results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      _online = true;
    }
  }

  void _load() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      state = decoded
          .whereType<Map<String, dynamic>>()
          .map(PendingWrite.fromJson)
          .whereType<PendingWrite>()
          .toList();
    } catch (e) {
      debugPrint('Could not read the offline queue: $e');
    }
  }

  Future<void> _persist() async {
    try {
      await _prefs.setString(
        _key,
        jsonEncode(state.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Could not persist the offline queue: $e');
    }
  }

  /// Sends [body] to [path] now, or queues it if the device is offline.
  ///
  /// Returns true when it went out over the wire, false when it was queued.
  /// Anything that is not a network failure is rethrown, so real validation
  /// errors still reach the user immediately.
  Future<bool> send({
    required String method,
    required String path,
    required String label,
    Map<String, dynamic>? body,
  }) async {
    try {
      await _dispatch(method, path, body);
      return true;
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      await enqueue(
        method: method,
        path: path,
        label: label,
        body: body,
      );
      return false;
    }
  }

  Future<void> enqueue({
    required String method,
    required String path,
    required String label,
    Map<String, dynamic>? body,
  }) async {
    final write = PendingWrite(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      method: method,
      path: path,
      label: label,
      body: body,
      queuedAt: DateTime.now(),
    );
    state = [...state, write];
    await _persist();
  }

  Future<dynamic> _dispatch(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) {
    switch (method.toUpperCase()) {
      case 'PUT':
        return _api.put(path, body: body);
      case 'PATCH':
        return _api.patch(path, body: body);
      case 'DELETE':
        return _api.delete(path, body: body);
      default:
        return _api.post(path, body: body);
    }
  }

  /// Attempts every queued write, oldest first.
  Future<int> flush() async {
    if (_flushing || state.isEmpty) return 0;
    _flushing = true;
    var sent = 0;
    final remaining = <PendingWrite>[];

    // Everything below runs inside try/finally: an unexpected error must not
    // leave `_flushing` stuck true, which would block every later sync for
    // the lifetime of the app.
    try {
      for (final write in state) {
        try {
          await _dispatch(write.method, write.path, write.body);
          sent++;
        } on ApiException catch (e) {
          if (e.isNetwork) {
            // Still offline — keep it, unchanged.
            remaining.add(write);
          } else {
            final next = write.copyWith(attempts: write.attempts + 1);
            if (next.attempts < _maxAttempts) {
              remaining.add(next);
            } else {
              debugPrint('Dropping "${write.label}" after ${next.attempts} '
                  'failed attempts: ${e.message}');
            }
          }
        } catch (e) {
          // Not an API failure at all — a serialisation bug, say. Count an
          // attempt so it cannot spin forever, but keep the entry.
          debugPrint('Unexpected error replaying "${write.label}": $e');
          final next = write.copyWith(attempts: write.attempts + 1);
          if (next.attempts < _maxAttempts) remaining.add(next);
        }
      }

      state = remaining;
      await _persist();
    } finally {
      _flushing = false;
    }
    return sent;
  }

  Future<void> remove(String id) async {
    state = state.where((w) => w.id != id).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _persist();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final offlineQueueProvider =
    StateNotifierProvider<OfflineQueue, List<PendingWrite>>(
  (ref) => OfflineQueue(ref.watch(prefsProvider), ref.watch(apiClientProvider)),
);

/// Live connectivity, for the offline banner.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  yield* Connectivity().onConnectivityChanged.map(
        (results) => results.any((r) => r != ConnectivityResult.none),
      );
});
