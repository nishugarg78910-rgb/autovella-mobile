import 'package:intl/intl.dart';

/// Display formatting.
///
/// Autovella is India-first, so money defaults to INR and uses the Indian
/// digit grouping people there actually read (₹12,50,000 — not ₹1,250,000).
/// `intl`'s `en_IN` locale handles the 2-2-3 grouping correctly.
class Fmt {
  const Fmt._();

  static const _symbols = <String, String>{
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'AED': 'د.إ',
    'SGD': 'S\$',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'JPY': '¥',
  };

  static String symbolFor(String? currency) =>
      _symbols[(currency ?? 'INR').toUpperCase()] ??
      '${(currency ?? '').toUpperCase()} ';

  /// Full amount, e.g. `₹12,50,000`.
  ///
  /// The Indian grouping (2-2-3, lakh/crore) comes from the *pattern*, not the
  /// locale: passing an explicit `#,##0` pattern overrides whatever grouping
  /// `en_IN` would have applied, which silently produced `₹1,250,000`. The
  /// pattern is therefore selected per currency, which also means this does
  /// not depend on `intl` locale data being initialised.
  static String money(num? amount, {String? currency, bool decimals = false}) {
    if (amount == null) return '—';
    final code = (currency ?? 'INR').toUpperCase();
    final indian = code == 'INR';
    final pattern = indian
        ? (decimals ? '#,##,##0.00' : '#,##,##0')
        : (decimals ? '#,##0.00' : '#,##0');
    final formatted = NumberFormat(pattern).format(amount);
    return '${symbolFor(code)}$formatted';
  }

  /// Abbreviated for tiles and chart axes. Uses lakh/crore for INR, because
  /// "₹1.2Cr" is what an Indian sales lead reads, not "₹12.0M".
  static String moneyShort(num? amount, {String? currency}) {
    if (amount == null) return '—';
    final code = (currency ?? 'INR').toUpperCase();
    final symbol = symbolFor(code);
    final value = amount.abs();
    final sign = amount < 0 ? '-' : '';

    if (code == 'INR') {
      if (value >= 10000000) {
        return '$sign$symbol${_trim(value / 10000000)}Cr';
      }
      if (value >= 100000) {
        return '$sign$symbol${_trim(value / 100000)}L';
      }
      if (value >= 1000) {
        return '$sign$symbol${_trim(value / 1000)}K';
      }
      return '$sign$symbol${value.toStringAsFixed(0)}';
    }

    if (value >= 1000000000) return '$sign$symbol${_trim(value / 1000000000)}B';
    if (value >= 1000000) return '$sign$symbol${_trim(value / 1000000)}M';
    if (value >= 1000) return '$sign$symbol${_trim(value / 1000)}K';
    return '$sign$symbol${value.toStringAsFixed(0)}';
  }

  /// Splits an abbreviated amount into its pieces so the UI can render the
  /// unit smaller than the digits.
  ///
  /// "0M" read as "OM" on a stat tile because the suffix sat at the same
  /// weight and size as the number. Returning the parts lets the tile set the
  /// unit in a lighter, smaller style, which removes the ambiguity — and a
  /// value under a thousand is never abbreviated at all.
  static (String symbol, String number, String unit) moneyParts(
    num? amount, {
    String? currency,
  }) {
    if (amount == null) return ('', '—', '');
    final code = (currency ?? 'INR').toUpperCase();
    final symbol = symbolFor(code);
    final value = amount.abs();
    final sign = amount < 0 ? '-' : '';

    (String, String) scaled(double divisor, String unit) =>
        ('$sign${_trim(value / divisor)}', unit);

    final (number, unit) = code == 'INR'
        ? (value >= 10000000
            ? scaled(10000000, 'Cr')
            : value >= 100000
                ? scaled(100000, 'L')
                : value >= 1000
                    ? scaled(1000, 'K')
                    : ('$sign${NumberFormat('#,##,##0').format(value)}', ''))
        : (value >= 1000000000
            ? scaled(1000000000, 'B')
            : value >= 1000000
                ? scaled(1000000, 'M')
                : value >= 1000
                    ? scaled(1000, 'K')
                    : ('$sign${NumberFormat('#,##0').format(value)}', ''));

    return (symbol, number, unit);
  }

  static String _trim(double value) {
    final s = value.toStringAsFixed(value >= 100 ? 0 : 1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String number(num? value) {
    if (value == null) return '—';
    return NumberFormat('#,##,##0').format(value);
  }

  static String percent(double fraction, {int decimals = 0}) =>
      '${(fraction * 100).toStringAsFixed(decimals)}%';

  // ---- Dates -----------------------------------------------------------

  static final _dayMonth = DateFormat('d MMM');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _weekdayDay = DateFormat('EEE, d MMM');
  static final _time = DateFormat('h:mm a');
  static final _dayMonthTime = DateFormat('d MMM, h:mm a');
  static final _monthYear = DateFormat('MMMM yyyy');
  static final _iso = DateFormat('yyyy-MM-dd');

  /// `12 Mar` when this year, `12 Mar 2024` otherwise.
  static String date(DateTime? value) {
    if (value == null) return '—';
    return value.year == DateTime.now().year
        ? _dayMonth.format(value)
        : _dayMonthYear.format(value);
  }

  static String fullDate(DateTime? value) =>
      value == null ? '—' : _dayMonthYear.format(value);

  static String weekday(DateTime? value) =>
      value == null ? '—' : _weekdayDay.format(value);

  static String time(DateTime? value) =>
      value == null ? '—' : _time.format(value);

  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dayMonthTime.format(value);

  static String monthYear(DateTime? value) =>
      value == null ? '—' : _monthYear.format(value);

  /// `yyyy-MM-dd`, the shape the API expects for date-only fields.
  static String apiDate(DateTime value) => _iso.format(value);

  /// Human date for list rows: Today / Yesterday / Tomorrow, else the date.
  static String friendlyDate(DateTime? value) {
    if (value == null) return '—';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(value.year, value.month, value.day);
    final diff = that.difference(today).inDays;
    switch (diff) {
      case 0:
        return 'Today';
      case 1:
        return 'Tomorrow';
      case -1:
        return 'Yesterday';
      default:
        return date(value);
    }
  }

  /// `3m ago`, `2h ago`, `4d ago` — for comments and activity feeds.
  static String relative(DateTime? value) {
    if (value == null) return '';
    final diff = DateTime.now().difference(value);
    if (diff.isNegative) {
      final ahead = value.difference(DateTime.now());
      if (ahead.inDays > 0) return 'in ${ahead.inDays}d';
      if (ahead.inHours > 0) return 'in ${ahead.inHours}h';
      return 'shortly';
    }
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// `7h 30m` — timesheet and attendance durations.
  static String duration(Duration d) {
    if (d.inMinutes <= 0) return '0m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String hours(double? value) {
    if (value == null || value == 0) return '0h';
    if (value % 1 == 0) return '${value.toInt()}h';
    return '${value.toStringAsFixed(1)}h';
  }

  /// Strips HTML so a rich-text body can be previewed on one line.
  static String plainText(String? html, {int max = 140}) {
    if (html == null || html.isEmpty) return '';
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length > max) text = '${text.substring(0, max).trimRight()}…';
    return text;
  }
}
