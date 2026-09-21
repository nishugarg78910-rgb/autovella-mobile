import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../core/util/json.dart';

/// A lightweight reference to another record.
///
/// List endpoints expand relations shallowly — a task carries
/// `project: {id, name, status, color}` rather than the whole project — so
/// most screens can render without a second round trip.
class EntityRef {
  const EntityRef({required this.id, required this.name, this.color});

  final String id;
  final String name;
  final String? color;

  static EntityRef? fromJson(dynamic value) {
    final json = J.mapOrNull(value);
    if (json == null) return null;
    final id = J.str(json['id']);
    if (id.isEmpty) return null;
    return EntityRef(
      id: id,
      name: J.str(J.pick(json, ['name', 'title', 'label']), 'Untitled'),
      color: J.strOrNull(json['color']),
    );
  }
}

/// A person as embedded in other records (`owner`, `createdBy`, `assignedTo`).
class UserRef {
  const UserRef({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.avatar,
    this.role,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? avatar;
  final String? role;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    if (name.isNotEmpty) return name;
    return email ?? 'Unknown';
  }

  /// Two-letter monogram for avatar fallbacks.
  String get initials {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isNotEmpty && l.isNotEmpty) {
      return '${f[0]}${l[0]}'.toUpperCase();
    }
    final source = f.isNotEmpty ? f : (email ?? '?');
    return source.characters.take(2).toString().toUpperCase();
  }

  /// Deterministic avatar tint, so the same person is always the same colour.
  Color get tint {
    const palette = [
      AppColors.brand600,
      AppColors.teal,
      AppColors.purple,
      Color(0xFFD97706),
      Color(0xFFDB2777),
      Color(0xFF0891B2),
      Color(0xFF65A30D),
      Color(0xFF9333EA),
    ];
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }

  static UserRef? fromJson(dynamic value) {
    final json = J.mapOrNull(value);
    if (json == null) return null;
    final id = J.str(json['id']);
    if (id.isEmpty) return null;
    return UserRef(
      id: id,
      firstName: J.str(json['firstName']),
      lastName: J.str(json['lastName']),
      email: J.strOrNull(json['email']),
      avatar: J.strOrNull(json['avatar']),
      role: J.strOrNull(json['role']),
    );
  }

  /// Task assignees arrive as join rows: `[{userId, user: {...}}]`.
  static List<UserRef> listFromAssignments(dynamic value) {
    final out = <UserRef>[];
    for (final row in J.maps(value)) {
      final user = UserRef.fromJson(row['user']) ?? UserRef.fromJson(row);
      if (user != null) out.add(user);
    }
    return out;
  }
}

/// How a status or priority string should be presented.
///
/// Autovella lets each organisation define its own statuses, so this maps the
/// well-known values and falls back to a neutral treatment for custom ones
/// rather than guessing wrong or crashing.
class Tone {
  const Tone(this.label, this.fg, this.bg);

  final String label;
  final Color fg;
  final Color bg;

  static const _neutral = Tone('—', AppColors.slate600, AppColors.slate100);

  static Tone status(String? raw) {
    final key = _key(raw);
    if (key.isEmpty) return _neutral;
    switch (key) {
      case 'todo':
      case 'backlog':
      case 'open':
      case 'new':
      case 'notstarted':
        return Tone(_pretty(raw!), AppColors.slate600, AppColors.slate100);
      case 'inprogress':
      case 'active':
      case 'doing':
      case 'started':
      case 'wip':
        return Tone(_pretty(raw!), AppColors.brand700, AppColors.brand50);
      case 'inreview':
      case 'review':
      case 'qa':
      case 'testing':
      case 'pending':
      case 'submitted':
        return Tone(_pretty(raw!), AppColors.warning, AppColors.warningSoft);
      case 'blocked':
      case 'onhold':
      case 'rejected':
      case 'overdue':
      case 'cancelled':
      case 'canceled':
      case 'failed':
        return Tone(_pretty(raw!), AppColors.danger, AppColors.dangerSoft);
      case 'done':
      case 'completed':
      case 'complete':
      case 'closed':
      case 'approved':
      case 'paid':
      case 'closedwon':
      case 'won':
        return Tone(_pretty(raw!), AppColors.success, AppColors.successSoft);
      case 'archived':
      case 'draft':
        return Tone(_pretty(raw!), AppColors.slate500, AppColors.slate100);
      case 'closedlost':
      case 'lost':
        return Tone(_pretty(raw!), AppColors.danger, AppColors.dangerSoft);
      default:
        return Tone(_pretty(raw!), AppColors.purple, AppColors.purpleSoft);
    }
  }

  static Tone priority(String? raw) {
    final key = _key(raw);
    switch (key) {
      case 'urgent':
      case 'critical':
      case 'highest':
        return Tone(_pretty(raw!), AppColors.danger, AppColors.dangerSoft);
      case 'high':
        return Tone(_pretty(raw!), AppColors.warning, AppColors.warningSoft);
      case 'medium':
      case 'normal':
        return Tone(_pretty(raw!), AppColors.brand700, AppColors.brand50);
      case 'low':
      case 'lowest':
        return Tone(_pretty(raw!), AppColors.slate600, AppColors.slate100);
      default:
        return key.isEmpty ? _neutral : Tone(_pretty(raw!), AppColors.slate600, AppColors.slate100);
    }
  }

  static String _key(String? raw) =>
      (raw ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  /// `in_progress` / `inProgress` / `Closed Won` → `In Progress` / `Closed Won`.
  static String _pretty(String raw) {
    final spaced = raw
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAllMapped(
          RegExp(r'(?<=[a-z])(?=[A-Z])'),
          (_) => ' ',
        )
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

/// Paging envelope for list screens.
class Paged<T> {
  const Paged({required this.items, required this.page, required this.hasMore});

  final List<T> items;
  final int page;
  final bool hasMore;

  bool get isEmpty => items.isEmpty;
}
