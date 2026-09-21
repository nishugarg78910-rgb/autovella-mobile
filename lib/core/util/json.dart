/// Defensive JSON coercion.
///
/// The API is loosely typed in places — `budget` comes back as an int on one
/// record and a double on another, dates are ISO-8601 strings but nullable
/// almost everywhere, and `customFields` is either a map or null. Parsing
/// through these helpers means one malformed field degrades that field
/// rather than throwing and blanking an entire screen.
class J {
  const J._();

  static String str(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return unescape(value);
    return '$value';
  }

  /// Decodes HTML entities that have been stored in plain-text fields.
  ///
  /// Some records are double-escaped server-side — the role "Sales &amp;
  /// Business Development" is stored with a literal `&amp;` — so without
  /// this the raw entity shows up in the UI.
  static String unescape(String value) {
    if (!value.contains('&')) return value;
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  static String? strOrNull(dynamic value) {
    if (value == null) return null;
    final s = value is String ? value : '$value';
    return s.isEmpty ? null : s;
  }

  static int intVal(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double dbl(dynamic value, [double fallback = 0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static double? dblOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool boolVal(dynamic value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return fallback;
  }

  /// Parses ISO-8601 timestamps and bare `yyyy-MM-dd` dates alike, returning
  /// local time so date maths matches what the user sees.
  static DateTime? date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = '$value';
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return const {};
  }

  static Map<String, dynamic>? mapOrNull(dynamic value) {
    if (value == null) return null;
    final m = map(value);
    return m.isEmpty ? null : m;
  }

  static List<Map<String, dynamic>> maps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(map)
        .toList(growable: false);
  }

  static List<String> strings(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => '$e').toList(growable: false);
  }

  /// Maps a nested list of objects with [parse], skipping malformed rows.
  static List<T> objects<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parse,
  ) =>
      maps(value).map(parse).toList(growable: false);

  /// Reads the first present key — the API is inconsistent about
  /// `endDate` vs `dueDate`, `name` vs `title`, and similar pairs.
  static dynamic pick(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value;
    }
    return null;
  }
}
