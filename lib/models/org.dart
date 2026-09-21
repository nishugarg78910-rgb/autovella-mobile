import '../core/util/json.dart';
import 'common.dart';

/// Per-module CRUD grid plus per-field grants, as returned by `/auth/me`
/// under `rolePermissions`:
///
/// ```json
/// "tasks": {
///   "read": true, "create": true, "update": true, "delete": false,
///   "fields": {
///     "estimatedHours": {"read": true, "edit": false},
///     "customFields.Environment": {"read": true, "edit": true}
///   }
/// }
/// ```
///
/// Field grants are a real feature of this platform and are enforced here:
/// a role that cannot read `budget` should not see the budget, not merely be
/// unable to save it. Modules that declare no `fields` map are unrestricted,
/// which is the common case.
class Permissions {
  const Permissions(this._grid, [this._fields = const {}]);

  final Map<String, Map<String, bool>> _grid;
  final Map<String, Map<String, FieldGrant>> _fields;

  static Permissions fromJson(dynamic value) {
    final grid = <String, Map<String, bool>>{};
    final fields = <String, Map<String, FieldGrant>>{};

    J.map(value).forEach((module, perms) {
      final row = <String, bool>{};
      final fieldRow = <String, FieldGrant>{};
      J.map(perms).forEach((action, allowed) {
        if (action == 'fields') {
          J.map(allowed).forEach((String field, dynamic grant) {
            final g = J.map(grant);
            fieldRow[field] = FieldGrant(
              read: J.boolVal(g['read'], true),
              edit: J.boolVal(g['edit'], true),
            );
          });
          return;
        }
        row[action] = J.boolVal(allowed);
      });
      grid[module] = row;
      if (fieldRow.isNotEmpty) fields[module] = fieldRow;
    });

    return Permissions(grid, fields);
  }

  bool can(String module, String action) => _grid[module]?[action] ?? false;

  bool canRead(String module) => can(module, 'read');
  bool canCreate(String module) => can(module, 'create');
  bool canUpdate(String module) => can(module, 'update');
  bool canDelete(String module) => can(module, 'delete');

  bool isHidden(String module) => !canRead(module);

  /// Whether this module declares any field-level restrictions at all.
  bool hasFieldGrants(String module) => _fields.containsKey(module);

  /// Whether [field] may be shown. Unlisted fields are visible — the grid is
  /// an allow-list of *restrictions*, not an exhaustive schema, so hiding
  /// everything unlisted would blank the app for every restricted role.
  bool canReadField(String module, String field) {
    final grant = _fields[module]?[field];
    if (grant == null) return canRead(module);
    return grant.read;
  }

  /// Whether [field] may be edited. Requires module update rights too.
  bool canEditField(String module, String field) {
    if (!canUpdate(module)) return false;
    final grant = _fields[module]?[field];
    if (grant == null) return true;
    return grant.edit;
  }

  Iterable<String> get modules => _grid.keys;
}

/// Read/edit rights for one field.
class FieldGrant {
  const FieldGrant({required this.read, required this.edit});

  final bool read;
  final bool edit;
}

class Organization {
  const Organization({
    required this.id,
    required this.name,
    this.slug,
    this.status,
    this.planName,
    this.planKey,
    this.timezone,
    this.location,
    this.featureFlags = const [],
    this.usedBytes = 0,
    this.quotaBytes = 0,
  });

  final String id;
  final String name;
  final String? slug;
  final String? status;
  final String? planName;
  final String? planKey;
  final String? timezone;
  final String? location;
  final List<String> featureFlags;
  final int usedBytes;
  final int quotaBytes;

  bool hasFeature(String flag) => featureFlags.contains(flag);

  double get storageUsed {
    if (quotaBytes <= 0) return 0;
    return (usedBytes / quotaBytes).clamp(0, 1);
  }

  factory Organization.fromJson(Map<String, dynamic> json) {
    final plan = J.map(json['plan']);
    return Organization(
      id: J.str(json['id']),
      name: J.str(json['name'], 'Organization'),
      slug: J.strOrNull(json['slug']),
      status: J.strOrNull(json['status']),
      planName: J.strOrNull(plan['name']),
      planKey: J.strOrNull(plan['key']),
      timezone: J.strOrNull(json['timezone']),
      location: J.strOrNull(json['location']),
      featureFlags: J.strings(json['featureFlags']),
      usedBytes: J.intVal(json['usedBytes']),
      quotaBytes: J.intVal(
        J.pick(json, ['effectiveQuotaBytes', 'quotaBytes']) ?? plan['quotaBytes'],
      ),
    );
  }
}

/// The signed-in user, from `/auth/me`.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.username,
    this.role,
    this.avatar,
    this.location,
    this.timezone,
    this.isActive = true,
    required this.permissions,
    this.organization,
    this.featureFlags = const [],
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? username;
  final String? role;
  final String? avatar;
  final String? location;
  final String? timezone;
  final bool isActive;
  final Permissions permissions;
  final Organization? organization;
  final List<String> featureFlags;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    final s = fullName;
    return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
  }

  bool get isAdmin => (role ?? '').toLowerCase() == 'admin';

  /// A module is usable only when the plan enables it *and* the role grants
  /// read on it.
  bool canUse(String module, {String? feature}) {
    if (feature != null && organization != null) {
      if (!organization!.hasFeature(feature)) return false;
    }
    return permissions.canRead(module);
  }

  UserRef get asRef => UserRef(
        id: id,
        firstName: firstName,
        lastName: lastName,
        email: email,
        avatar: avatar,
      );

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    // `/auth/me` may answer either the user object directly or wrap it.
    final root = J.mapOrNull(json['user']) ?? json;
    return CurrentUser(
      id: J.str(root['id']),
      email: J.str(root['email']),
      firstName: J.str(root['firstName']),
      lastName: J.str(root['lastName']),
      username: J.strOrNull(root['username']),
      role: J.strOrNull(root['role']),
      avatar: J.strOrNull(root['avatar']),
      location: J.strOrNull(root['location']),
      timezone: J.strOrNull(
        J.pick(root, ['effectiveTimezone', 'timezone']),
      ),
      isActive: J.boolVal(root['isActive'], true),
      permissions: Permissions.fromJson(root['rolePermissions']),
      organization: J.mapOrNull(root['organization']) == null
          ? null
          : Organization.fromJson(J.map(root['organization'])),
      featureFlags: J.strings(root['featureFlags']),
    );
  }
}

class Team {
  const Team({
    required this.id,
    required this.name,
    this.description,
    this.lead,
    this.memberCount = 0,
    this.members = const [],
  });

  final String id;
  final String name;
  final String? description;
  final UserRef? lead;
  final int memberCount;
  final List<UserRef> members;

  factory Team.fromJson(Map<String, dynamic> json) {
    final members = <UserRef>[];
    for (final row in J.maps(json['members'])) {
      final u = UserRef.fromJson(row['user']) ?? UserRef.fromJson(row);
      if (u != null) members.add(u);
    }
    return Team(
      id: J.str(json['id']),
      name: J.str(J.pick(json, ['name', 'title']), 'Team'),
      description: J.strOrNull(json['description']),
      lead: UserRef.fromJson(json['lead'] ?? json['manager']),
      memberCount: J.intVal(
        J.pick(json, ['memberCount', 'membersCount']) ?? members.length,
      ),
      members: members,
    );
  }
}

class Role {
  const Role({
    required this.id,
    required this.name,
    this.description,
    this.userCount = 0,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final String? description;
  final int userCount;
  final bool isSystem;

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: J.str(json['id']),
        name: J.str(J.pick(json, ['name', 'title']), 'Role'),
        description: J.strOrNull(json['description']),
        userCount: J.intVal(J.pick(json, ['userCount', 'usersCount'])),
        isSystem: J.boolVal(J.pick(json, ['isSystem', 'system'])),
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.type,
    this.isRead = false,
    this.createdAt,
    this.entityType,
    this.entityId,
    this.actor,
  });

  final String id;
  final String title;
  final String? body;
  final String? type;
  final bool isRead;
  final DateTime? createdAt;
  final String? entityType;
  final String? entityId;
  final UserRef? actor;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: J.str(json['id']),
        title: J.str(
          J.pick(json, ['title', 'subject', 'message']),
          'Notification',
        ),
        body: J.strOrNull(J.pick(json, ['body', 'description', 'message'])),
        type: J.strOrNull(json['type']),
        isRead: J.boolVal(J.pick(json, ['isRead', 'read'])),
        createdAt: J.date(json['createdAt']),
        entityType: J.strOrNull(J.pick(json, ['entityType', 'resourceType'])),
        entityId: J.strOrNull(J.pick(json, ['entityId', 'resourceId'])),
        actor: UserRef.fromJson(json['actor'] ?? json['createdBy']),
      );
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    this.action,
    this.entityType,
    this.entityId,
    this.actor,
    this.createdAt,
    this.summary,
  });

  final String id;
  final String? action;
  final String? entityType;
  final String? entityId;
  final UserRef? actor;
  final DateTime? createdAt;
  final String? summary;

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: J.str(json['id']),
        action: J.strOrNull(J.pick(json, ['action', 'event', 'type'])),
        entityType: J.strOrNull(J.pick(json, ['entityType', 'resourceType'])),
        entityId: J.strOrNull(J.pick(json, ['entityId', 'resourceId'])),
        actor: UserRef.fromJson(json['actor'] ?? json['user']),
        createdAt: J.date(json['createdAt']),
        summary: J.strOrNull(J.pick(json, ['summary', 'description', 'message'])),
      );
}

class Automation {
  const Automation({
    required this.id,
    required this.name,
    this.description,
    this.isEnabled = false,
    this.triggerType,
    this.runCount = 0,
    this.lastRunAt,
  });

  final String id;
  final String name;
  final String? description;
  final bool isEnabled;
  final String? triggerType;
  final int runCount;
  final DateTime? lastRunAt;

  factory Automation.fromJson(Map<String, dynamic> json) => Automation(
        id: J.str(json['id']),
        name: J.str(J.pick(json, ['name', 'title']), 'Automation'),
        description: J.strOrNull(json['description']),
        isEnabled: J.boolVal(J.pick(json, ['isEnabled', 'enabled', 'isActive'])),
        triggerType: J.strOrNull(J.pick(json, ['triggerType', 'trigger'])),
        runCount: J.intVal(J.pick(json, ['runCount', 'executions'])),
        lastRunAt: J.date(J.pick(json, ['lastRunAt', 'lastExecutedAt'])),
      );
}
