import '../core/util/json.dart';

/// One clause of a saved view's filter.
class FilterCondition {
  const FilterCondition({
    required this.field,
    required this.operator,
    this.value,
  });

  final String field;
  final String operator;
  final dynamic value;

  factory FilterCondition.fromJson(Map<String, dynamic> json) =>
      FilterCondition(
        field: J.str(J.pick(json, ['field', 'key', 'column'])),
        operator: J.str(J.pick(json, ['operator', 'op']), 'equals'),
        value: J.pick(json, ['value', 'val']),
      );

  Map<String, dynamic> toJson() =>
      {'field': field, 'operator': operator, 'value': value};

  /// A human sentence, for the chip that says what is being filtered.
  String describe() {
    final verb = switch (operator) {
      'equals' => 'is',
      'notEquals' => 'is not',
      'contains' => 'contains',
      'notContains' => 'does not contain',
      'before' => 'before',
      'after' => 'after',
      'isEmpty' => 'is empty',
      'isNotEmpty' => 'is set',
      'greaterThan' => '>',
      'lessThan' => '<',
      _ => operator,
    };
    final label = _humanise(field);
    if (operator == 'isEmpty' || operator == 'isNotEmpty') {
      return '$label $verb';
    }
    return '$label $verb ${value ?? ''}'.trim();
  }

  static String _humanise(String key) {
    final spaced = key
        .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
        .replaceAll('_', ' ')
        .replaceAll('.', ' · ')
        .trim();
    if (spaced.isEmpty) return key;
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}

/// A saved view's filter: a set of conditions combined with all/any.
///
/// Mirrors the web app's own `filterSpec` — `{match, conditions}` — so a view
/// saved there behaves identically here.
class FilterSpec {
  const FilterSpec({this.match = 'all', this.conditions = const []});

  /// 'all' (AND) or 'any' (OR).
  final String match;
  final List<FilterCondition> conditions;

  bool get isEmpty => conditions.isEmpty;

  factory FilterSpec.fromJson(dynamic value) {
    final json = J.mapOrNull(value);
    if (json == null) return const FilterSpec();
    return FilterSpec(
      match: J.str(json['match'], 'all'),
      conditions: J.objects(
        J.pick(json, ['conditions', 'rules', 'filters']),
        FilterCondition.fromJson,
      ),
    );
  }

  /// Evaluates the spec against a record.
  ///
  /// Applied client-side on purpose: the list endpoints take a handful of
  /// fixed query parameters, not an arbitrary condition tree, so the only way
  /// a saved view can behave the same here as on the web is to fetch and
  /// filter. Fine at the page sizes this app uses; it would need a
  /// server-side filter API to scale past that.
  bool matches(Map<String, dynamic> record) {
    if (conditions.isEmpty) return true;
    final results = conditions.map((c) => _test(c, record));
    return match.toLowerCase() == 'any'
        ? results.any((r) => r)
        : results.every((r) => r);
  }

  bool _test(FilterCondition c, Map<String, dynamic> record) {
    final actual = _read(record, c.field);
    final expected = c.value;

    switch (c.operator) {
      case 'isEmpty':
        return actual == null || '$actual'.trim().isEmpty;
      case 'isNotEmpty':
        return actual != null && '$actual'.trim().isNotEmpty;
    }

    if (actual == null) return false;

    final a = '$actual'.toLowerCase();
    final b = '${expected ?? ''}'.toLowerCase();

    switch (c.operator) {
      case 'equals':
        return a == b;
      case 'notEquals':
        return a != b;
      case 'contains':
        return a.contains(b);
      case 'notContains':
        return !a.contains(b);
      case 'in':
        return expected is List &&
            expected.map((e) => '$e'.toLowerCase()).contains(a);
      case 'startsWith':
        return a.startsWith(b);
      case 'endsWith':
        return a.endsWith(b);
    }

    // Comparisons: dates first, then numbers, then plain string order.
    final da = J.date(actual);
    final db = J.date(expected);
    if (da != null && db != null) {
      return switch (c.operator) {
        'before' => da.isBefore(db),
        'after' => da.isAfter(db),
        'on' => da.year == db.year && da.month == db.month && da.day == db.day,
        'greaterThan' => da.isAfter(db),
        'lessThan' => da.isBefore(db),
        _ => false,
      };
    }

    final na = J.dblOrNull(actual);
    final nb = J.dblOrNull(expected);
    if (na != null && nb != null) {
      return switch (c.operator) {
        'greaterThan' || 'after' => na > nb,
        'lessThan' || 'before' => na < nb,
        _ => false,
      };
    }

    return false;
  }

  /// Reads `a.b.c` style paths, so `project.name` and `customFields.Region`
  /// both work.
  static dynamic _read(Map<String, dynamic> record, String field) {
    if (field.isEmpty) return null;
    dynamic node = record;
    for (final part in field.split('.')) {
      if (node is Map) {
        node = node[part];
      } else {
        return null;
      }
    }
    return node;
  }
}

/// A saved list view.
class SavedView {
  const SavedView({
    required this.id,
    required this.name,
    required this.entityType,
    this.filter = const FilterSpec(),
    this.columns = const [],
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String entityType;
  final FilterSpec filter;
  final List<String> columns;
  final bool isDefault;

  factory SavedView.fromJson(Map<String, dynamic> json) => SavedView(
        id: J.str(json['id']),
        name: J.str(J.pick(json, ['name', 'title']), 'Saved view'),
        entityType: J.str(J.pick(json, ['entityType', 'entity']), 'tasks'),
        filter: FilterSpec.fromJson(
          J.pick(json, ['filter', 'filterSpec', 'config']),
        ),
        columns: J.strings(json['columns']),
        isDefault: J.boolVal(J.pick(json, ['isDefault', 'default'])),
      );
}
