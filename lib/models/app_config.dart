import 'package:flutter/material.dart';

import '../core/util/json.dart';

/// One configurable status, as the organisation defines it.
class StatusDef {
  const StatusDef({
    required this.value,
    required this.label,
    this.color,
    this.isDefault = false,
    this.isCompleted = false,
  });

  /// The value stored on the record — e.g. `in-progress`.
  final String value;

  /// What the organisation calls it — e.g. "In Progress".
  final String label;

  /// Their colour, as `#RRGGBB`.
  final String? color;

  /// Applied to newly created records.
  final bool isDefault;

  /// **This is what "done" means.** Not the name — the flag. An org can call
  /// its completed status "Shipped" or "Signed off".
  final bool isCompleted;

  Color? get parsedColor {
    final hex = color?.replaceAll('#', '').trim();
    if (hex == null || hex.isEmpty) return null;
    final full = hex.length == 6 ? 'FF$hex' : hex;
    final v = int.tryParse(full, radix: 16);
    return v == null ? null : Color(v);
  }

  factory StatusDef.fromJson(Map<String, dynamic> json) => StatusDef(
        value: J.str(J.pick(json, ['value', 'key', 'id'])),
        label: J.str(J.pick(json, ['label', 'name']), J.str(json['value'])),
        color: J.strOrNull(json['color']),
        isDefault: J.boolVal(json['isDefault']),
        isCompleted: J.boolVal(json['isCompleted']),
      );
}

/// A set of statuses for one entity, with the lookups the UI needs.
class StatusCatalog {
  const StatusCatalog(this.statuses);

  final List<StatusDef> statuses;

  bool get isEmpty => statuses.isEmpty;

  StatusDef? find(String? value) {
    if (value == null) return null;
    for (final s in statuses) {
      if (s.value == value) return s;
    }
    // Tolerate the hyphen/underscore drift that creeps into stored data.
    final norm = _norm(value);
    for (final s in statuses) {
      if (_norm(s.value) == norm) return s;
    }
    return null;
  }

  /// Whether [value] means completed, per the organisation's own config.
  ///
  /// Falls back to name-matching only when the status is unknown to the
  /// catalog — better than treating an unrecognised status as open forever,
  /// but the catalog is the authority.
  bool isCompleted(String? value) {
    final def = find(value);
    if (def != null) return def.isCompleted;
    if (value == null) return false;
    return const {'done', 'completed', 'complete', 'closed'}
        .contains(_norm(value));
  }

  String labelFor(String? value) =>
      find(value)?.label ?? _prettify(value ?? '');

  Color? colorFor(String? value) => find(value)?.parsedColor;

  /// The status a new record should get.
  String? get defaultValue {
    for (final s in statuses) {
      if (s.isDefault) return s.value;
    }
    return statuses.isEmpty ? null : statuses.first.value;
  }

  static String _norm(String v) =>
      v.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  static String _prettify(String raw) {
    final spaced = raw
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
        .trim();
    if (spaced.isEmpty) return raw;
    return spaced
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}

/// The organisation's configuration, from `GET /appconfig`.
///
/// This is the web client's own source of truth: it hydrates this at login
/// and every list screen reads statuses and currency from it. Inferring those
/// instead — matching on the word "done", assuming rupees — produces an app
/// that looks right and is quietly wrong for any org that customised them.
class AppConfig {
  const AppConfig({
    this.taskStatuses = const StatusCatalog(_defaultTaskStatuses),
    this.projectStatuses = const StatusCatalog(_defaultProjectStatuses),
    this.defaultCurrency = 'INR',
    this.raw = const {},
  });

  final StatusCatalog taskStatuses;
  final StatusCatalog projectStatuses;
  final String defaultCurrency;
  final Map<String, dynamic> raw;

  /// The web client's built-in fallbacks, copied exactly, used when the org
  /// has not customised its statuses.
  static const _defaultTaskStatuses = [
    StatusDef(value: 'todo', label: 'To Do', color: '#3B82F6', isDefault: true),
    StatusDef(value: 'in-progress', label: 'In Progress', color: '#F59E0B'),
    StatusDef(value: 'review', label: 'Review', color: '#8B5CF6'),
    StatusDef(
      value: 'done',
      label: 'Done',
      color: '#10B981',
      isCompleted: true,
    ),
  ];

  static const _defaultProjectStatuses = [
    StatusDef(value: 'draft', label: 'Draft', color: '#6B7280'),
    StatusDef(
      value: 'active',
      label: 'Active',
      color: '#3B82F6',
      isDefault: true,
    ),
    StatusDef(value: 'on_hold', label: 'On Hold', color: '#F59E0B'),
    StatusDef(
      value: 'completed',
      label: 'Completed',
      color: '#10B981',
      isCompleted: true,
    ),
    StatusDef(value: 'cancelled', label: 'Cancelled', color: '#EF4444'),
  ];

  factory AppConfig.fromJson(dynamic value) {
    final json = J.map(value);

    StatusCatalog read(String key, List<StatusDef> fallback) {
      final rows = J.objects(json[key], StatusDef.fromJson)
          .where((s) => s.value.isNotEmpty)
          .toList();
      return StatusCatalog(rows.isEmpty ? fallback : rows);
    }

    return AppConfig(
      taskStatuses: read('taskStatuses', _defaultTaskStatuses),
      projectStatuses: read('projectStatuses', _defaultProjectStatuses),
      defaultCurrency:
          J.strOrNull(json['defaultCurrency'])?.toUpperCase() ?? 'INR',
      raw: json,
    );
  }
}
