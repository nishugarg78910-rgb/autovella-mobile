import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches GET responses so the app still reads when the network does not.
///
/// The offline queue covers writes. This covers the other half: without it,
/// opening the app on the metro shows an error on every screen, even for data
/// that was on the device a minute ago. Entries are stored as JSON under a
/// hash of the request, capped in count and age so the cache cannot grow
/// without bound on a phone.
///
/// Cached data is only ever served when the live request *fails for network
/// reasons* — never in preference to a fresh response, and never to mask a
/// 403 or a 404.
class ResponseCache {
  ResponseCache(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'autovella.cache.';
  static const _indexKey = 'autovella.cache.index';
  static const _maxEntries = 120;
  static const _maxAge = Duration(days: 7);

  /// Responses bigger than this are not worth the storage on a phone — the
  /// user list with inlined avatars would otherwise fill the cache alone.
  static const _maxBytes = 256 * 1024;

  String _key(String path, Map<String, dynamic>? query) {
    final q = (query?.entries.toList()
          ?..sort((a, b) => a.key.compareTo(b.key)))
        ?.map((e) => '${e.key}=${e.value}')
        .join('&');
    return '$_prefix${path}_${q ?? ''}'.hashCode.toRadixString(16);
  }

  Future<void> write(
    String path,
    Map<String, dynamic>? query,
    dynamic body,
  ) async {
    try {
      final encoded = jsonEncode({
        'at': DateTime.now().toIso8601String(),
        'body': body,
      });
      if (encoded.length > _maxBytes) return;

      final key = _key(path, query);
      await _prefs.setString('$_prefix$key', encoded);

      final index = _prefs.getStringList(_indexKey) ?? <String>[];
      index.remove(key);
      index.add(key);
      // Evict oldest first.
      while (index.length > _maxEntries) {
        final oldest = index.removeAt(0);
        await _prefs.remove('$_prefix$oldest');
      }
      await _prefs.setStringList(_indexKey, index);
    } catch (e) {
      debugPrint('Cache write failed for $path: $e');
    }
  }

  /// Returns the cached body, or null when there is none or it has expired.
  dynamic read(String path, Map<String, dynamic>? query) {
    try {
      final raw = _prefs.getString('$_prefix${_key(path, query)}');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final at = DateTime.tryParse('${decoded['at']}');
      if (at == null || DateTime.now().difference(at) > _maxAge) return null;
      return decoded['body'];
    } catch (e) {
      debugPrint('Cache read failed for $path: $e');
      return null;
    }
  }

  /// When the cached copy for this request was stored.
  DateTime? ageOf(String path, Map<String, dynamic>? query) {
    try {
      final raw = _prefs.getString('$_prefix${_key(path, query)}');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return DateTime.tryParse('${(decoded as Map)['at']}');
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      for (final key in _prefs.getStringList(_indexKey) ?? <String>[]) {
        await _prefs.remove('$_prefix$key');
      }
      await _prefs.remove(_indexKey);
    } catch (e) {
      debugPrint('Cache clear failed: $e');
    }
  }

  int get entryCount => (_prefs.getStringList(_indexKey) ?? const []).length;
}
