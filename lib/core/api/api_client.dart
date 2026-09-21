import 'dart:async';

import 'package:dio/dio.dart';

import '../offline/response_cache.dart';
import 'api_exception.dart';
import 'endpoints.dart';

/// Thin, typed wrapper over Dio for the Autovella REST API.
///
/// Authentication is a bearer token: the web client sends
/// `Authorization: Bearer <token>` on every request and sets no cookies, so
/// this client does the same. (An earlier version carried a persistent cookie
/// jar, which did nothing — the API never issues a session cookie.)
class ApiClient {
  ApiClient._(this._dio);

  final Dio _dio;

  String? _token;
  String? get token => _token;

  /// Set once shared preferences are ready. Until then, reads are uncached —
  /// which only affects the very first moments of a cold start.
  ResponseCache? cache;

  /// Paths currently being served from cache, so the UI can say so.
  final Set<String> servedFromCache = <String>{};

  /// Fired when the server rejects the token (HTTP 401) on any request.
  final _unauthorized = StreamController<void>.broadcast();
  Stream<void> get onUnauthorized => _unauthorized.stream;

  factory ApiClient.create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: Api.apiRoot,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 45),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );

    final client = ApiClient._(dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = client._token;
          if (token != null && token.isNotEmpty) {
            options.headers['authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            client._unauthorized.add(null);
          }
          return handler.next(error);
        },
      ),
    );
    return client;
  }

  /// Kept for the demo build, which swaps the transport for fixtures.
  factory ApiClient.ephemeral() => ApiClient.create();

  void setToken(String? token) => _token = token;

  void addInterceptor(Interceptor interceptor) =>
      _dio.interceptors.add(interceptor);

  // ---- Verbs -----------------------------------------------------------

  /// GET, with a read-through cache.
  ///
  /// A successful response is cached; a *network* failure falls back to the
  /// cached copy if there is one. Anything else — 401, 403, 404, 500 — is
  /// raised as normal, because serving stale data over a real error would
  /// hide the problem.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
    bool useCache = true,
  }) async {
    try {
      final data = await _send(() => _dio.get<dynamic>(
            path,
            queryParameters: _clean(query),
            cancelToken: cancelToken,
          ));
      servedFromCache.remove(path);
      if (useCache) unawaited(cache?.write(path, query, data) ?? Future.value());
      return data;
    } on ApiException catch (e) {
      if (!useCache || !e.isNetwork) rethrow;
      final cached = cache?.read(path, query);
      if (cached == null) rethrow;
      servedFromCache.add(path);
      return cached;
    }
  }

  /// When the cached copy backing [path] was stored, if it is being served.
  DateTime? cacheAge(String path, [Map<String, dynamic>? query]) =>
      servedFromCache.contains(path) ? cache?.ageOf(path, query) : null;

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send(() => _dio.post<dynamic>(
            path,
            data: body,
            queryParameters: _clean(query),
          ));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<dynamic>(path, data: body));

  Future<dynamic> upload(
    String path, {
    required String filePath,
    String field = 'file',
    Map<String, dynamic>? fields,
    ProgressCallback? onProgress,
  }) async {
    final form = FormData.fromMap({
      ...?fields,
      field: await MultipartFile.fromFile(
        filePath,
        filename: Uri.file(filePath).pathSegments.last,
      ),
    });
    return _send(() => _dio.post<dynamic>(
          path,
          data: form,
          onSendProgress: onProgress,
          options: Options(contentType: 'multipart/form-data'),
        ));
  }

  // ---- Typed helpers ---------------------------------------------------

  Future<List<T>> list<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final data = await get(path, query: query, cancelToken: cancelToken);
    return asList(data)
        .whereType<Map<String, dynamic>>()
        .map(parse)
        .toList(growable: false);
  }

  Future<T> one<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
  }) async {
    final data = await get(path, query: query);
    if (data is Map<String, dynamic>) return parse(data);
    throw ApiException(message: 'Unexpected response shape for $path.');
  }

  // ---- Internals -------------------------------------------------------

  Future<dynamic> _send(Future<Response<dynamic>> Function() run) async {
    try {
      final response = await run();
      return unwrap(response.data);
    } catch (error) {
      throw ApiException.from(error);
    }
  }

  /// Strips the `{success, data}` envelope when present.
  ///
  /// Some endpoints answer outside the envelope — `/notifications/unread-count`
  /// returns `{success, count}` — so anything without a `data` key passes
  /// through untouched.
  static dynamic unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body['success'] == false) {
        throw ApiException(
          message: (body['message'] as String?) ?? 'Request failed.',
        );
      }
      if (body.containsKey('data')) return body['data'];
    }
    return body;
  }

  /// Normalises the shapes a list endpoint can answer with.
  static List<dynamic> asList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final key in const [
        'items', 'results', 'rows', 'records', 'data', 'users', 'logs'
      ]) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null) out[key] = value;
    });
    return out.isEmpty ? null : out;
  }

  void dispose() => _unauthorized.close();
}
