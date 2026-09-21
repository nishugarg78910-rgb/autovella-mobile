import '../core/util/json.dart';
import 'common.dart';

/// One attendance record for a day.
///
/// The API models a day as a list of punches — `{punches: [{type: "in"|"out",
/// timestamp}], workHours}` — not a single check-in/check-out pair. Someone
/// who steps out for lunch produces four punches, and an earlier build that
/// looked for `checkInAt`/`checkOutAt` fields found nothing, which is why the
/// attendance screen came up empty.
class Attendance {
  const Attendance({
    required this.id,
    this.user,
    this.date,
    this.punches = const [],
    this.status,
    this.workHours,
    this.notes,
  });

  final String id;
  final UserRef? user;
  final DateTime? date;
  final List<Punch> punches;
  final String? status;
  final double? workHours;
  final String? notes;

  Punch? get _lastPunch => punches.isEmpty ? null : punches.last;

  /// True when the most recent punch was an "in" — i.e. the clock is running.
  bool get isCheckedIn => _lastPunch?.isIn ?? false;

  bool get hasPunches => punches.isNotEmpty;

  /// A completed day: at least one pair, and not currently clocked in.
  bool get isComplete => punches.length >= 2 && !isCheckedIn;

  DateTime? get firstIn {
    for (final p in punches) {
      if (p.isIn) return p.at;
    }
    return null;
  }

  DateTime? get lastOut {
    for (final p in punches.reversed) {
      if (!p.isIn) return p.at;
    }
    return null;
  }

  /// Worked duration. Prefers the server's `workHours`; otherwise sums each
  /// in→out pair, counting an open "in" up to now.
  Duration get worked {
    if (workHours != null && workHours! > 0) {
      return Duration(minutes: (workHours! * 60).round());
    }
    var total = Duration.zero;
    DateTime? openedAt;
    for (final p in punches) {
      if (p.at == null) continue;
      if (p.isIn) {
        openedAt = p.at;
      } else if (openedAt != null) {
        final span = p.at!.difference(openedAt);
        if (!span.isNegative) total += span;
        openedAt = null;
      }
    }
    if (openedAt != null) {
      final span = DateTime.now().difference(openedAt);
      if (!span.isNegative) total += span;
    }
    return total;
  }

  String? get location {
    for (final p in punches) {
      if (p.location != null && p.location!.isNotEmpty) return p.location;
    }
    return null;
  }

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
        id: J.str(json['id']),
        user: UserRef.fromJson(json['user']),
        date: J.date(json['date']),
        punches: J.objects(json['punches'], Punch.fromJson),
        status: J.strOrNull(json['status']),
        workHours: J.dblOrNull(J.pick(json, ['workHours', 'totalHours'])),
        notes: J.strOrNull(json['notes']),
      );
}

/// A single clock event.
class Punch {
  const Punch({required this.type, this.at, this.location});

  final String type;
  final DateTime? at;
  final String? location;

  bool get isIn => type.toLowerCase() == 'in';

  factory Punch.fromJson(Map<String, dynamic> json) => Punch(
        type: J.str(json['type'], 'in'),
        at: J.date(J.pick(json, ['timestamp', 'at', 'time', 'createdAt'])),
        location: J.strOrNull(J.pick(json, ['location', 'address'])),
      );
}

class Timesheet {
  const Timesheet({
    required this.id,
    this.user,
    this.project,
    this.task,
    this.date,
    this.hours = 0,
    this.status,
    this.description,
    this.isBillable = false,
    this.weekStart,
    this.weekEnd,
    this.submittedAt,
    this.approvedBy,
  });

  final String id;
  final UserRef? user;
  final EntityRef? project;
  final EntityRef? task;
  final DateTime? date;
  final double hours;
  final String? status;
  final String? description;
  final bool isBillable;
  final DateTime? weekStart;
  final DateTime? weekEnd;
  final DateTime? submittedAt;
  final UserRef? approvedBy;

  String get _statusKey =>
      (status ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  bool get isDraft => _statusKey == 'draft' || status == null;
  bool get isSubmitted => _statusKey == 'submitted' || _statusKey == 'pending';
  bool get isApproved => _statusKey == 'approved';
  bool get isRejected => _statusKey == 'rejected';

  /// Editable only while it has not been sent for approval.
  bool get canEdit => isDraft || isRejected;

  factory Timesheet.fromJson(Map<String, dynamic> json) => Timesheet(
        id: J.str(json['id']),
        user: UserRef.fromJson(json['user']),
        project: EntityRef.fromJson(json['project']),
        task: EntityRef.fromJson(json['task']),
        date: J.date(J.pick(json, ['date', 'workDate', 'entryDate'])),
        hours: J.dbl(J.pick(json, ['hours', 'totalHours', 'duration'])),
        status: J.strOrNull(json['status']),
        description: J.strOrNull(J.pick(json, ['description', 'notes'])),
        isBillable: J.boolVal(json['isBillable']),
        weekStart: J.date(J.pick(json, ['weekStart', 'periodStart'])),
        weekEnd: J.date(J.pick(json, ['weekEnd', 'periodEnd'])),
        submittedAt: J.date(json['submittedAt']),
        approvedBy: UserRef.fromJson(json['approvedBy']),
      );

  Map<String, dynamic> toCreateJson() => {
        if (project != null) 'projectId': project!.id,
        if (task != null) 'taskId': task!.id,
        'hours': hours,
        if (date != null)
          'date': '${date!.year.toString().padLeft(4, '0')}-'
              '${date!.month.toString().padLeft(2, '0')}-'
              '${date!.day.toString().padLeft(2, '0')}',
        if (description != null) 'description': description,
        'isBillable': isBillable,
      };
}

class TimeOff {
  const TimeOff({
    required this.id,
    this.user,
    this.type,
    this.status,
    this.startDate,
    this.endDate,
    this.days,
    this.reason,
    this.approvedBy,
    this.createdAt,
  });

  final String id;
  final UserRef? user;
  final String? type;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? days;
  final String? reason;
  final UserRef? approvedBy;
  final DateTime? createdAt;

  String get _statusKey =>
      (status ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  bool get isPending => _statusKey == 'pending' || _statusKey == 'requested';
  bool get isApproved => _statusKey == 'approved';
  bool get isRejected => _statusKey == 'rejected';
  bool get isCancelled => _statusKey == 'cancelled' || _statusKey == 'canceled';

  /// Inclusive day count, so a single-day leave reads as 1, not 0.
  double get dayCount {
    if (days != null) return days!;
    if (startDate == null || endDate == null) return 0;
    return endDate!.difference(startDate!).inDays + 1;
  }

  bool get isUpcoming =>
      startDate != null && startDate!.isAfter(DateTime.now()) && isApproved;

  factory TimeOff.fromJson(Map<String, dynamic> json) => TimeOff(
        id: J.str(json['id']),
        user: UserRef.fromJson(json['user']),
        type: J.strOrNull(J.pick(json, ['type', 'leaveType', 'category'])),
        status: J.strOrNull(json['status']),
        startDate: J.date(J.pick(json, ['startDate', 'from'])),
        endDate: J.date(J.pick(json, ['endDate', 'to'])),
        days: J.dblOrNull(J.pick(json, ['days', 'totalDays', 'dayCount'])),
        reason: J.strOrNull(J.pick(json, ['reason', 'notes', 'description'])),
        approvedBy: UserRef.fromJson(json['approvedBy']),
        createdAt: J.date(json['createdAt']),
      );
}

class Holiday {
  const Holiday({
    required this.id,
    required this.name,
    this.date,
    this.type,
    this.isRecurring = false,
    this.description,
  });

  final String id;
  final String name;
  final DateTime? date;
  final String? type;
  final bool isRecurring;
  final String? description;

  bool get isUpcoming => date != null && date!.isAfter(DateTime.now());

  int get daysAway {
    if (date == null) return 0;
    final now = DateTime.now();
    return date!.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
        id: J.str(json['id']),
        name: J.str(J.pick(json, ['name', 'title']), 'Holiday'),
        date: J.date(json['date']),
        type: J.strOrNull(json['type']),
        isRecurring: J.boolVal(J.pick(json, ['isRecurring', 'recurring'])),
        description: J.strOrNull(json['description']),
      );
}
