import 'package:dio/dio.dart';

/// A normalised failure from the Autovella API.
///
/// The API answers with an envelope — `{"success": false, "message": "..."}` —
/// for both auth failures and validation errors, so [message] is almost always
/// safe to show to the user verbatim.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
    this.isNetwork = false,
  });

  final String message;
  final int? statusCode;

  /// Per-field validation messages, when the API supplies them.
  final Map<String, String> fieldErrors;

  /// True when the request never reached the server (offline, DNS, timeout).
  final bool isNetwork;

  bool get isUnauthorized => statusCode == 401;

  /// The user is authenticated but their role forbids this action. The MCP
  /// contract is explicit that a 403 must not be retried.
  bool get isForbidden => statusCode == 403;

  bool get isNotFound => statusCode == 404;
  bool get isServer => (statusCode ?? 0) >= 500;

  /// Builds an [ApiException] from anything Dio throws.
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return ApiException(
            message: 'The server took too long to respond. Check your '
                'connection and try again.',
            isNetwork: true,
          );
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          return ApiException(
            message: "Can't reach Autovella. You appear to be offline.",
            isNetwork: true,
          );
        case DioExceptionType.cancel:
          return ApiException(message: 'Request cancelled.');
        case DioExceptionType.badCertificate:
          return ApiException(
            message: 'The server certificate could not be verified.',
            isNetwork: true,
          );
        case DioExceptionType.badResponse:
          return ApiException._fromResponse(error.response);
      }
    }

    return ApiException(message: error.toString());
  }

  factory ApiException._fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    final data = response?.data;

    var message = _defaultFor(status);
    final fields = <String, String>{};

    if (data is Map) {
      final raw = data['message'] ?? data['error'];
      if (raw is String && raw.trim().isNotEmpty) message = raw.trim();

      // Collect `errors: {field: "msg"}` or `errors: {field: ["msg"]}`.
      final errors = data['errors'];
      if (errors is Map) {
        errors.forEach((key, value) {
          if (value is String) {
            fields['$key'] = value;
          } else if (value is List && value.isNotEmpty) {
            fields['$key'] = '${value.first}';
          }
        });
      }
    }

    return ApiException(
      message: message,
      statusCode: status,
      fieldErrors: fields,
    );
  }

  static String _defaultFor(int? status) {
    switch (status) {
      case 400:
        return 'That request was not valid.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return "You don't have permission to do that.";
      case 404:
        return 'That record no longer exists.';
      case 409:
        return 'That change conflicts with a more recent update.';
      case 422:
        return 'Please correct the highlighted fields.';
      case 429:
        return 'Too many requests. Please wait a moment.';
      default:
        if ((status ?? 0) >= 500) {
          return 'Autovella ran into a problem. Please try again shortly.';
        }
        return 'Something went wrong.';
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
