import '../core/util/json.dart';
import 'common.dart';

/// A project. Field names mirror the API payload exactly (verified against
/// live `/projects` responses) so round-tripping an edit is lossless.
class Project {
  const Project({
    required this.id,
    required this.name,
    this.description,
    this.status,
    this.priority,
    this.color,
    this.accountId,
    this.dealId,
    this.startDate,
    this.dueDate,
    this.completedAt,
    this.budget,
    this.budgetSpent,
    this.currency,
    this.progressPercent = 0,
    this.isTemplate = false,
    this.archivedAt,
    this.owner,
    this.account,
    this.team,
    this.createdBy,
    this.members = const [],
    this.customFields,
    this.taskTotal = 0,
    this.taskDone = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;

  /// Rich text — arrives as an HTML fragment, not plain text.
  final String? description;
  final String? status;
  final String? priority;
  final String? color;
  final String? accountId;
  final String? dealId;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final double? budget;
  final double? budgetSpent;
  final String? currency;
  final int progressPercent;
  final bool isTemplate;
  final DateTime? archivedAt;
  final UserRef? owner;
  final EntityRef? account;
  final EntityRef? team;
  final UserRef? createdBy;
  final List<ProjectMember> members;
  final Map<String, dynamic>? customFields;
  final int taskTotal;
  final int taskDone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isArchived => archivedAt != null;

  bool get isOverdue =>
      dueDate != null &&
      completedAt == null &&
      dueDate!.isBefore(DateTime.now());

  /// Prefer the server's own progress; fall back to task completion ratio.
  double get progress {
    if (progressPercent > 0) return (progressPercent / 100).clamp(0, 1);
    if (taskTotal == 0) return 0;
    return (taskDone / taskTotal).clamp(0, 1);
  }

  double get budgetUsed {
    final total = budget ?? 0;
    if (total <= 0) return 0;
    return ((budgetSpent ?? 0) / total).clamp(0, 1);
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    final stats = J.map(json['taskStats']);
    return Project(
      id: J.str(json['id']),
      name: J.str(json['name'], 'Untitled project'),
      description: J.strOrNull(json['description']),
      status: J.strOrNull(json['status']),
      priority: J.strOrNull(json['priority']),
      color: J.strOrNull(json['color']),
      accountId: J.strOrNull(json['accountId']),
      dealId: J.strOrNull(json['dealId']),
      startDate: J.date(json['startDate']),
      dueDate: J.date(json['dueDate']),
      completedAt: J.date(json['completedAt']),
      budget: J.dblOrNull(json['budget']),
      budgetSpent: J.dblOrNull(json['budgetSpent']),
      currency: J.strOrNull(json['currency']),
      progressPercent: J.intVal(json['progressPercent']),
      isTemplate: J.boolVal(json['isTemplate']),
      archivedAt: J.date(json['archivedAt']),
      owner: UserRef.fromJson(json['owner']),
      account: EntityRef.fromJson(json['account']),
      team: EntityRef.fromJson(json['team']),
      createdBy: UserRef.fromJson(json['createdBy']),
      members: J.objects(json['teamMembers'], ProjectMember.fromJson),
      customFields: J.mapOrNull(json['customFields']),
      taskTotal: J.intVal(stats['total']),
      taskDone: J.intVal(stats['done']),
      createdAt: J.date(json['createdAt']),
      updatedAt: J.date(json['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (color != null) 'color': color,
        if (accountId != null) 'accountId': accountId,
        if (startDate != null) 'startDate': _day(startDate!),
        if (dueDate != null) 'dueDate': _day(dueDate!),
        if (budget != null) 'budget': budget,
        if (currency != null) 'currency': currency,
      };
}

/// A person's membership of a project, carrying their billing rates.
class ProjectMember {
  const ProjectMember({
    required this.id,
    required this.userId,
    this.user,
    this.access,
    this.costRate,
    this.billRate,
  });

  final String id;
  final String userId;
  final UserRef? user;
  final String? access;
  final double? costRate;
  final double? billRate;

  factory ProjectMember.fromJson(Map<String, dynamic> json) => ProjectMember(
        id: J.str(json['id']),
        userId: J.str(json['userId']),
        user: UserRef.fromJson(json['user']),
        access: J.strOrNull(json['access']),
        costRate: J.dblOrNull(json['costRate']),
        billRate: J.dblOrNull(json['billRate']),
      );
}

/// A task. Note the API uses `endDate`, not `dueDate`, on tasks.
class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    this.projectId,
    this.sectionId,
    this.parentTaskId,
    this.sprintId,
    this.status,
    this.priority,
    this.startDate,
    this.endDate,
    this.completedAt,
    this.isBillable = false,
    this.milestone = false,
    this.estimatedHours,
    this.actualHours,
    this.progress = 0,
    this.storyPoints,
    this.tags = const [],
    this.project,
    this.section,
    this.sprint,
    this.assignees = const [],
    this.createdBy,
    this.customFields,
    this.dependencyCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? projectId;
  final String? sectionId;
  final String? parentTaskId;
  final String? sprintId;
  final String? status;
  final String? priority;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? completedAt;
  final bool isBillable;
  final bool milestone;
  final double? estimatedHours;
  final double? actualHours;
  final int progress;
  final int? storyPoints;
  final List<String> tags;
  final EntityRef? project;
  final EntityRef? section;
  final EntityRef? sprint;
  final List<UserRef> assignees;
  final UserRef? createdBy;
  final Map<String, dynamic>? customFields;
  final int dependencyCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDone =>
      completedAt != null ||
      const {'done', 'completed', 'complete', 'closed'}
          .contains((status ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''));

  bool get isOverdue =>
      endDate != null && !isDone && endDate!.isBefore(_today);

  bool get isDueToday {
    final d = endDate;
    if (d == null || isDone) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool get isSubtask => parentTaskId != null;

  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: J.str(json['id']),
        title: J.str(J.pick(json, ['title', 'name']), 'Untitled task'),
        description: J.strOrNull(json['description']),
        projectId: J.strOrNull(json['projectId']),
        sectionId: J.strOrNull(json['sectionId']),
        parentTaskId: J.strOrNull(json['parentTaskId']),
        sprintId: J.strOrNull(json['sprintId']),
        status: J.strOrNull(json['status']),
        priority: J.strOrNull(json['priority']),
        startDate: J.date(json['startDate']),
        endDate: J.date(J.pick(json, ['endDate', 'dueDate'])),
        completedAt: J.date(json['completedAt']),
        isBillable: J.boolVal(json['isBillable']),
        milestone: J.boolVal(json['milestone']),
        estimatedHours: J.dblOrNull(json['estimatedHours']),
        actualHours: J.dblOrNull(json['actualHours']),
        progress: J.intVal(json['progress']),
        storyPoints: J.intOrNull(json['storyPoints']),
        tags: J.strings(json['tags']),
        project: EntityRef.fromJson(json['project']),
        section: EntityRef.fromJson(json['section']),
        sprint: EntityRef.fromJson(json['sprint']),
        assignees: UserRef.listFromAssignments(json['assignedTo']),
        createdBy: UserRef.fromJson(json['createdBy']),
        customFields: J.mapOrNull(json['customFields']),
        dependencyCount: J.maps(json['dependencies']).length,
        createdAt: J.date(json['createdAt']),
        updatedAt: J.date(json['updatedAt']),
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        if (projectId != null) 'projectId': projectId,
        if (description != null) 'description': description,
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (sprintId != null) 'sprintId': sprintId,
        if (sectionId != null) 'sectionId': sectionId,
        if (startDate != null) 'startDate': _day(startDate!),
        if (endDate != null) 'endDate': _day(endDate!),
        if (estimatedHours != null) 'estimatedHours': estimatedHours,
        if (storyPoints != null) 'storyPoints': storyPoints,
        'isBillable': isBillable,
        'milestone': milestone,
        if (tags.isNotEmpty) 'tags': tags,
      };
}

class Subtask {
  const Subtask({
    required this.id,
    required this.title,
    this.completed = false,
    this.taskId,
    this.assignee,
  });

  final String id;
  final String title;
  final bool completed;
  final String? taskId;
  final UserRef? assignee;

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
        id: J.str(json['id']),
        title: J.str(J.pick(json, ['title', 'name']), 'Untitled'),
        completed: J.boolVal(J.pick(json, ['completed', 'isCompleted', 'done'])),
        taskId: J.strOrNull(json['taskId']),
        assignee: UserRef.fromJson(json['assignee'] ?? json['user']),
      );
}

class Sprint {
  const Sprint({
    required this.id,
    required this.name,
    this.goal,
    this.status,
    this.startDate,
    this.endDate,
    this.projectId,
    this.taskTotal = 0,
    this.taskDone = 0,
    this.pointsTotal = 0,
    this.pointsDone = 0,
  });

  final String id;
  final String name;
  final String? goal;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? projectId;
  final int taskTotal;
  final int taskDone;
  final int pointsTotal;
  final int pointsDone;

  bool get isActive {
    final now = DateTime.now();
    if (startDate == null || endDate == null) {
      return (status ?? '').toLowerCase() == 'active';
    }
    return now.isAfter(startDate!) && now.isBefore(endDate!);
  }

  /// Calendar days left, floored at zero.
  int get daysRemaining {
    if (endDate == null) return 0;
    final diff = endDate!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  double get completion {
    if (pointsTotal > 0) return (pointsDone / pointsTotal).clamp(0, 1);
    if (taskTotal > 0) return (taskDone / taskTotal).clamp(0, 1);
    return 0;
  }

  factory Sprint.fromJson(Map<String, dynamic> json) {
    final stats = J.map(json['taskStats'] ?? json['stats']);
    return Sprint(
      id: J.str(json['id']),
      name: J.str(J.pick(json, ['name', 'title']), 'Sprint'),
      goal: J.strOrNull(json['goal']),
      status: J.strOrNull(json['status']),
      startDate: J.date(json['startDate']),
      endDate: J.date(J.pick(json, ['endDate', 'dueDate'])),
      projectId: J.strOrNull(json['projectId']),
      taskTotal: J.intVal(J.pick(stats, ['total']) ?? json['taskCount']),
      taskDone: J.intVal(J.pick(stats, ['done', 'completed'])),
      pointsTotal: J.intVal(J.pick(json, ['totalPoints', 'storyPoints'])),
      pointsDone: J.intVal(J.pick(json, ['completedPoints', 'donePoints'])),
    );
  }
}

class Section {
  const Section({required this.id, required this.name, this.projectId, this.order = 0});

  final String id;
  final String name;
  final String? projectId;
  final int order;

  factory Section.fromJson(Map<String, dynamic> json) => Section(
        id: J.str(json['id']),
        name: J.str(J.pick(json, ['name', 'title']), 'Section'),
        projectId: J.strOrNull(json['projectId']),
        order: J.intVal(J.pick(json, ['order', 'position', 'rank'])),
      );
}

class Comment {
  const Comment({
    required this.id,
    required this.body,
    this.author,
    this.createdAt,
    this.edited = false,
  });

  final String id;

  /// HTML fragment authored in the web app's Quill editor.
  final String body;
  final UserRef? author;
  final DateTime? createdAt;
  final bool edited;

  factory Comment.fromJson(Map<String, dynamic> json) {
    final created = J.date(json['createdAt']);
    final updated = J.date(json['updatedAt']);
    return Comment(
      id: J.str(json['id']),
      body: J.str(J.pick(json, ['body', 'content', 'text', 'comment'])),
      author: UserRef.fromJson(json['author'] ?? json['user'] ?? json['createdBy']),
      createdAt: created,
      edited: created != null && updated != null && updated.isAfter(created),
    );
  }
}

class Attachment {
  const Attachment({
    required this.id,
    required this.name,
    this.url,
    this.sizeBytes = 0,
    this.mimeType,
    this.uploadedBy,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? url;
  final int sizeBytes;
  final String? mimeType;
  final UserRef? uploadedBy;
  final DateTime? createdAt;

  bool get isImage => (mimeType ?? '').startsWith('image/');

  String get readableSize {
    if (sizeBytes <= 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = sizeBytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size < 10 && unit > 0 ? 1 : 0)} ${units[unit]}';
  }

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: J.str(json['id']),
        name: J.str(J.pick(json, ['name', 'fileName', 'filename']), 'File'),
        url: J.strOrNull(J.pick(json, ['url', 'downloadUrl', 'path'])),
        sizeBytes: J.intVal(J.pick(json, ['size', 'sizeBytes', 'fileSize'])),
        mimeType: J.strOrNull(J.pick(json, ['mimeType', 'contentType', 'type'])),
        uploadedBy: UserRef.fromJson(json['uploadedBy'] ?? json['createdBy']),
        createdAt: J.date(json['createdAt']),
      );
}

/// Serialises a date as the bare `yyyy-MM-dd` the API uses for date-only
/// fields (`startDate`, `dueDate`, `closeDate`).
String _day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
