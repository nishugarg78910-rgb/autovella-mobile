/// Fixture data for the demo build.
///
/// Shapes mirror the live API exactly (verified against real `/projects`,
/// `/tasks` and `/deals` responses), so the demo exercises the real parsers,
/// repositories and screens — only the transport is replaced.
library;

String _d(int daysFromNow) {
  final now = DateTime.now().add(Duration(days: daysFromNow));
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String _ts(Duration offset) =>
    DateTime.now().add(offset).toUtc().toIso8601String();

const _orgId = '01D0070maONyC87000';

const _uPriya = {
  'id': '0U1007033w0QnA0000',
  'firstName': 'Priya',
  'lastName': 'Sharma',
  'email': 'priya@example.com',
  'avatar': null,
};
const _uArjun = {
  'id': '0U100707JXdUrDV000',
  'firstName': 'Arjun',
  'lastName': 'Rao',
  'email': 'arjun@example.com',
  'role': 'Frontend Developer',
  'avatar': null,
};
const _uMeera = {
  'id': '0U10070H8e8Gpbs000',
  'firstName': 'Meera',
  'lastName': 'Pillai',
  'email': 'meera@example.com',
  'role': 'Account Executive',
  'avatar': null,
};
const _uDev = {
  'id': '0U10070DevKapoor00',
  'firstName': 'Dev',
  'lastName': 'Kapoor',
  'email': 'dev@example.com',
  'role': 'Delivery Lead',
  'avatar': null,
};
const _uSara = {
  'id': '0U10070SaraKhan000',
  'firstName': 'Sara',
  'lastName': 'Khan',
  'email': 'sara@example.com',
  'role': 'QA Engineer',
  'avatar': null,
};

Map<String, dynamic> _assignee(Map<String, dynamic> user, String taskId) => {
      'id': 'as-$taskId-${user['id']}',
      'taskId': taskId,
      'userId': user['id'],
      'user': user,
    };

class Fixtures {
  const Fixtures._();

  // ---- Identity --------------------------------------------------------

  static final me = <String, dynamic>{
    ..._uPriya,
    'username': null,
    'role': 'admin',
    'location': 'Product',
    'isActive': true,
    'timezone': 'Asia/Calcutta',
    'effectiveTimezone': 'Asia/Calcutta',
    'featureFlags': <String>[],
    'rolePermissions': {
      for (final m in [
        'deals', 'gantt', 'tasks', 'teams', 'users', 'myWork', 'reports',
        'sprints', 'timeOff', 'accounts', 'calendar', 'contacts', 'expenses',
        'holidays', 'invoices', 'projects', 'settings', 'analytics',
        'approvals', 'bookmarks', 'timesheets', 'attendance',
      ])
        m: {'read': true, 'create': true, 'update': true, 'delete': true},
    },
    'organization': {
      'id': _orgId,
      'slug': 'demoautovella',
      'name': 'Demo Account',
      'status': 'active',
      'plan': {'key': 'starter', 'name': 'Starter', 'quotaBytes': '10737418240'},
      'usedBytes': '2129591600',
      'effectiveQuotaBytes': '10737418240',
      'featureFlags': [
        'projects', 'sprints', 'crm', 'invoicing', 'expenses', 'timesheets',
        'attendance', 'time_off', 'automation', 'templates',
        'email_integration', 'teams', 'multicurrency',
      ],
      'timezone': 'Asia/Calcutta',
      'location': 'Bangalore, India',
    },
  };

  // ---- Projects ---------------------------------------------------------

  static final projects = <Map<String, dynamic>>[
    {
      'id': 'p1',
      'organizationId': _orgId,
      'name': 'North India B2B expansion rollout',
      'description': '<p>Outbound motion for the North India mid-market '
          'segment, covering list build, sequencing and handover to AE.</p>',
      'status': 'active',
      'priority': 'high',
      'color': '#2563EB',
      'currency': 'INR',
      'budget': 1000000,
      'budgetSpent': 642000,
      'progressPercent': 0,
      'startDate': _d(-28),
      'dueDate': _d(12),
      'account': {'id': 'a1', 'name': 'Harbour Labs Ltd'},
      'owner': _uMeera,
      'createdBy': _uPriya,
      'taskStats': {'total': 8, 'done': 3},
      'teamMembers': [
        {'id': 'pm1', 'userId': _uArjun['id'], 'access': 'editor', 'user': _uArjun},
        {'id': 'pm2', 'userId': _uMeera['id'], 'access': 'owner', 'user': _uMeera},
        {'id': 'pm3', 'userId': _uDev['id'], 'access': 'editor', 'user': _uDev},
        {'id': 'pm4', 'userId': _uSara['id'], 'access': 'viewer', 'user': _uSara},
      ],
      'createdAt': _ts(const Duration(days: -28)),
    },
    {
      'id': 'p2',
      'organizationId': _orgId,
      'name': 'Warehouse fleet digitisation',
      'description': '<p>Bring the Pune and Nashik depots onto the vehicles '
          'and inventory modules.</p>',
      'status': 'active',
      'priority': 'medium',
      'color': '#0D9488',
      'currency': 'INR',
      'budget': 2400000,
      'budgetSpent': 2280000,
      'progressPercent': 72,
      'startDate': _d(-60),
      'dueDate': _d(-3),
      'owner': _uDev,
      'createdBy': _uPriya,
      'taskStats': {'total': 14, 'done': 10},
      'teamMembers': [
        {'id': 'pm5', 'userId': _uDev['id'], 'access': 'owner', 'user': _uDev},
        {'id': 'pm6', 'userId': _uSara['id'], 'access': 'editor', 'user': _uSara},
      ],
      'createdAt': _ts(const Duration(days: -60)),
    },
    {
      'id': 'p3',
      'organizationId': _orgId,
      'name': 'Mobile app launch — Android & iOS',
      'description': '<p>Ship the Autovella mobile client to both stores.</p>',
      'status': 'active',
      'priority': 'high',
      'color': '#7C3AED',
      'currency': 'INR',
      'budget': 1800000,
      'budgetSpent': 310000,
      'progressPercent': 18,
      'startDate': _d(-10),
      'dueDate': _d(45),
      'owner': _uPriya,
      'createdBy': _uPriya,
      'taskStats': {'total': 22, 'done': 4},
      'teamMembers': [
        {'id': 'pm7', 'userId': _uPriya['id'], 'access': 'owner', 'user': _uPriya},
        {'id': 'pm8', 'userId': _uArjun['id'], 'access': 'editor', 'user': _uArjun},
      ],
      'createdAt': _ts(const Duration(days: -10)),
    },
    {
      'id': 'p4',
      'organizationId': _orgId,
      'name': 'LG washing machine 20L — warranty programme',
      'status': 'on_hold',
      'priority': 'low',
      'color': '#D97706',
      'currency': 'INR',
      'budget': 50000,
      'budgetSpent': 12000,
      'progressPercent': 25,
      'startDate': _d(-14),
      'owner': _uArjun,
      'createdBy': _uArjun,
      'taskStats': {'total': 4, 'done': 1},
      'teamMembers': [
        {'id': 'pm9', 'userId': _uArjun['id'], 'access': 'owner', 'user': _uArjun},
      ],
      'createdAt': _ts(const Duration(days: -14)),
    },
    {
      'id': 'p5',
      'organizationId': _orgId,
      'name': 'Q3 delivery reporting refresh',
      'status': 'completed',
      'priority': 'medium',
      'color': '#16A34A',
      'currency': 'INR',
      'budget': 400000,
      'budgetSpent': 388000,
      'progressPercent': 100,
      'startDate': _d(-90),
      'dueDate': _d(-12),
      'completedAt': _ts(const Duration(days: -12)),
      'owner': _uDev,
      'createdBy': _uPriya,
      'taskStats': {'total': 11, 'done': 11},
      'teamMembers': [
        {'id': 'pm10', 'userId': _uDev['id'], 'access': 'owner', 'user': _uDev},
      ],
      'createdAt': _ts(const Duration(days: -90)),
    },
  ];

  // ---- Tasks ------------------------------------------------------------

  static final tasks = <Map<String, dynamic>>[
    _task('t1', 'Confirm 1+ year extended warranty terms with vendor',
        project: 'p4', status: 'in_progress', priority: 'high',
        endDate: _d(-3), points: 5, assignees: [_uPriya, _uArjun],
        description: '<p>Vendor quoted two tiers. Need the <b>written</b> '
            'confirmation before the customer callback on Friday.</p>'),
    _task('t2', 'Publish Q3 delivery report to leadership',
        project: 'p5', status: 'done', endDate: _d(0), assignees: [_uPriya]),
    _task('t3', 'Import North India lead list into sequences',
        project: 'p1', status: 'in_progress', priority: 'urgent',
        endDate: _d(0), points: 8, assignees: [_uPriya, _uMeera],
        description: '<p>4,200 rows from the Apollo export. Dedupe against '
            'existing accounts before load.</p>'),
    _task('t4', 'Depot walkthrough — Nashik', project: 'p2',
        status: 'blocked', priority: 'high', endDate: _d(-1),
        assignees: [_uPriya, _uPriya]),
    _task('t5', 'Wire attendance check-in to GPS', project: 'p3',
        status: 'in_review', priority: 'medium', endDate: _d(0), points: 3,
        assignees: [_uPriya]),
    _task('t6', 'Design review: mobile navigation', project: 'p3',
        status: 'todo', priority: 'medium', endDate: _d(2), points: 2,
        assignees: [_uPriya, _uArjun]),
    _task('t7', 'Reconcile depot stock counts', project: 'p2',
        status: 'todo', priority: 'low', endDate: _d(5), assignees: [_uPriya]),
    _task('t8', 'Draft SOW for Harbour Labs renewal', project: 'p1',
        status: 'todo', priority: 'high', endDate: _d(7), points: 5,
        assignees: [_uPriya, _uMeera], milestone: true),
    _task('t9', 'Store listing copy + screenshots', project: 'p3',
        status: 'todo', priority: 'medium', endDate: _d(14),
        assignees: [_uPriya]),
    _task('t10', 'Backfill missing cost rates for contractors',
        project: null, status: 'todo', priority: 'low', assignees: [_uPriya]),
    _task('t11', 'Close out Q3 invoices', project: 'p5', status: 'done',
        endDate: _d(-10), assignees: [_uPriya]),
    _task('t12', 'Vendor security questionnaire', project: 'p2',
        status: 'done', endDate: _d(-6), assignees: [_uPriya]),
  ];

  static Map<String, dynamic> _task(
    String id,
    String title, {
    String? project,
    String status = 'todo',
    String priority = 'medium',
    String? endDate,
    int? points,
    bool milestone = false,
    String? description,
    List<Map<String, dynamic>> assignees = const [],
  }) {
    final p = project == null
        ? null
        : projects.firstWhere((e) => e['id'] == project);
    return {
      'id': id,
      'organizationId': _orgId,
      'projectId': project,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'endDate': endDate,
      'startDate': endDate,
      'storyPoints': points,
      'milestone': milestone,
      'isBillable': project != null,
      'estimatedHours': points == null ? null : points * 1.5,
      'actualHours': status == 'done' ? (points ?? 2) * 1.4 : (points ?? 1) * 0.6,
      'progress': status == 'done' ? 100 : 0,
      'completedAt': status == 'done' ? _ts(const Duration(days: -1)) : null,
      'tags': milestone ? ['milestone', 'commercial'] : <String>[],
      'project': p == null
          ? null
          : {'id': p['id'], 'name': p['name'], 'color': p['color'], 'status': p['status']},
      'assignedTo': [for (final u in assignees) _assignee(u, id)],
      'createdBy': _uPriya,
      'dependencies': <dynamic>[],
      'createdAt': _ts(const Duration(days: -9)),
      'updatedAt': _ts(const Duration(hours: -5)),
    };
  }

  // ---- CRM --------------------------------------------------------------

  static final accounts = <Map<String, dynamic>>[
    {
      'id': 'a1',
      'name': 'Harbour Labs Ltd',
      'email': 'hello@example.com',
      'phone': '+91 80 4123 9900',
      'website': 'example.com',
      'industry': 'Life sciences',
      'city': 'Bengaluru',
      'country': 'India',
      'employeeCount': 640,
      'annualRevenue': 890000000,
      'currency': 'INR',
      'owner': _uMeera,
      'description': 'Long-standing account; renewal due this quarter.',
    },
    {
      'id': 'a2',
      'name': 'Northwind Systems',
      'email': 'hello@example.com',
      'phone': '+91 22 6644 1200',
      'website': 'example.com',
      'industry': 'Software',
      'city': 'Mumbai',
      'country': 'India',
      'employeeCount': 180,
      'annualRevenue': 240000000,
      'currency': 'INR',
      'owner': _uPriya,
    },
    {
      'id': 'a3',
      'name': 'Western Freight Pvt Ltd',
      'email': 'ops@example.com',
      'phone': '+91 20 2556 8811',
      'industry': 'Transport & logistics',
      'city': 'Pune',
      'country': 'India',
      'employeeCount': 2100,
      'annualRevenue': 1750000000,
      'currency': 'INR',
      'owner': _uPriya,
    },
    {
      'id': 'a4',
      'name': 'Lotus Retail Group',
      'email': 'buying@example.com',
      'industry': 'Retail',
      'city': 'Jaipur',
      'country': 'India',
      'employeeCount': 900,
      'currency': 'INR',
      'owner': _uMeera,
    },
  ];

  static final contacts = <Map<String, dynamic>>[
    {
      'id': 'c1',
      'firstName': 'Ravi',
      'lastName': 'Menon',
      'email': 'michael.zhang@example.com',
      'mobile': '+91 98450 22119',
      'title': 'VP Operations',
      'accountId': 'a1',
      'account': {'id': 'a1', 'name': 'Harbour Labs Ltd'},
      'leadSource': 'Web',
      'owner': _uMeera,
    },
    {
      'id': 'c2',
      'firstName': 'Kavya',
      'lastName': 'Reddy',
      'email': 'ananya.iyer@example.com',
      'mobile': '+91 99200 31847',
      'title': 'Head of Fleet',
      'accountId': 'a3',
      'account': {'id': 'a3', 'name': 'Western Freight Pvt Ltd'},
      'leadSource': 'Referral',
      'owner': _uPriya,
    },
    {
      'id': 'c3',
      'firstName': 'Nikhil',
      'lastName': 'Rao',
      'email': 'vikram.rao@example.com',
      'phone': '+91 141 400 7722',
      'title': 'Procurement Manager',
      'accountId': 'a4',
      'account': {'id': 'a4', 'name': 'Lotus Retail Group'},
      'leadSource': 'Trade show',
      'owner': _uMeera,
    },
    {
      'id': 'c4',
      'firstName': 'Anjali',
      'lastName': 'Joshi',
      'email': 'neha@example.com',
      'mobile': '+91 90040 55123',
      'title': 'Engineering Manager',
      'accountId': 'a2',
      'account': {'id': 'a2', 'name': 'Northwind Systems'},
      'owner': _uPriya,
    },
  ];

  static final deals = <Map<String, dynamic>>[
    {
      'id': 'd1',
      'name': 'Harbour Labs — platform renewal',
      'stage': 'Proposal',
      'amount': 1000000,
      'currency': 'INR',
      'probability': 60,
      'closeDate': _d(9),
      'type': 'Renewal',
      'leadSource': 'Web',
      'accountId': 'a1',
      'contactId': 'c1',
      'account': {'id': 'a1', 'name': 'Harbour Labs Ltd'},
      'contact': {'id': 'c1', 'firstName': 'Ravi', 'lastName': 'Menon'},
      'owner': _uMeera,
      'notes': 'Champion identified and budget confirmed; commercial review '
          'pending with procurement. Next step: scope walkthrough.',
      'customFields': {'Lead Type': 'Inbound Marketing Qualified'},
    },
    {
      'id': 'd2',
      'name': 'Western Freight — fleet module',
      'stage': 'Negotiation',
      'amount': 4200000,
      'currency': 'INR',
      'probability': 75,
      'closeDate': _d(4),
      'type': 'New Business',
      'leadSource': 'Referral',
      'accountId': 'a3',
      'contactId': 'c2',
      'account': {'id': 'a3', 'name': 'Western Freight Pvt Ltd'},
      'contact': {'id': 'c2', 'firstName': 'Kavya', 'lastName': 'Reddy'},
      'owner': _uPriya,
      'notes': 'Legal redlines returned. Pricing agreed at 4.2Cr over 3 years.',
    },
    {
      'id': 'd3',
      'name': 'Lotus Retail — pilot',
      'stage': 'Qualification',
      'amount': 650000,
      'currency': 'INR',
      'probability': 25,
      'closeDate': _d(-5),
      'type': 'New Business',
      'leadSource': 'Trade show',
      'accountId': 'a4',
      'contactId': 'c3',
      'account': {'id': 'a4', 'name': 'Lotus Retail Group'},
      'contact': {'id': 'c3', 'firstName': 'Nikhil', 'lastName': 'Rao'},
      'owner': _uMeera,
      'notes': 'Slipped past close date — procurement freeze until next month.',
    },
    {
      'id': 'd4',
      'name': 'Nimbus Forge — seat expansion',
      'stage': 'Closed Won',
      'amount': 1850000,
      'currency': 'INR',
      'probability': 100,
      'closeDate': _d(-18),
      'type': 'Upsell',
      'accountId': 'a2',
      'account': {'id': 'a2', 'name': 'Northwind Systems'},
      'owner': _uPriya,
    },
    {
      'id': 'd5',
      'name': 'Regional distributor — discovery',
      'stage': 'Closed Lost',
      'amount': 300000,
      'currency': 'INR',
      'probability': 0,
      'closeDate': _d(-30),
      'owner': _uMeera,
      'notes': 'Lost to incumbent on price.',
    },
  ];

  // ---- Finance -----------------------------------------------------------

  static final invoices = <Map<String, dynamic>>[
    _invoice('i1', 'INV-2026-0148', 'a3', 'Western Freight Pvt Ltd',
        1260000, 0, 'sent', _d(-22)),
    _invoice('i2', 'INV-2026-0151', 'a1', 'Harbour Labs Ltd',
        480000, 240000, 'partial', _d(-6)),
    _invoice('i3', 'INV-2026-0155', 'a2', 'Northwind Systems',
        925000, 925000, 'paid', _d(-2)),
    _invoice('i4', 'INV-2026-0158', 'a4', 'Lotus Retail Group',
        185000, 0, 'sent', _d(11)),
    _invoice('i5', 'INV-2026-0160', 'a1', 'Harbour Labs Ltd',
        340000, 0, 'draft', _d(20)),
  ];

  static Map<String, dynamic> _invoice(
    String id,
    String number,
    String accountId,
    String accountName,
    num total,
    num paid,
    String status,
    String dueDate,
  ) =>
      {
        'id': id,
        'invoiceNumber': number,
        'status': status,
        'accountId': accountId,
        'account': {'id': accountId, 'name': accountName},
        'issueDate': _d(-30),
        'dueDate': dueDate,
        'paidAt': status == 'paid' ? _ts(const Duration(days: -2)) : null,
        'subtotal': total / 1.18,
        'taxAmount': total - (total / 1.18),
        'total': total,
        'amountPaid': paid,
        'currency': 'INR',
        'lineItems': [
          {'description': 'Platform subscription', 'quantity': 1,
            'unitPrice': total / 1.18, 'amount': total / 1.18},
        ],
      };

  static final expenses = <Map<String, dynamic>>[
    _expense('e1', 'Cab to Nashik depot', 2450, 'Travel', 'approved', -2, true),
    _expense('e2', 'Client lunch — Harbour Labs', 4820, 'Meals', 'pending', -1, true),
    _expense('e3', 'Hotel — Pune site visit', 11600, 'Accommodation', 'pending', -4, true),
    _expense('e4', 'Figma annual seat', 13400, 'Software', 'approved', -12, false),
    _expense('e5', 'Barcode scanners (×4)', 28900, 'Equipment', 'rejected', -18, false),
  ];

  static Map<String, dynamic> _expense(String id, String description, num amount,
          String category, String status, int daysAgo, bool billable) =>
      {
        'id': id,
        'description': description,
        'amount': amount,
        'currency': 'INR',
        'category': category,
        'status': status,
        'date': _d(daysAgo),
        'isBillable': billable,
        'isReimbursable': true,
        'receiptUrl': 'https://autovella.cloud/receipts/$id.jpg',
        'user': _uPriya,
        'project': {'id': 'p2', 'name': 'Warehouse fleet digitisation'},
      };

  // ---- Time & attendance -------------------------------------------------

  // Shape verified against the live API: a day is a list of punches, not a
  // check-in/check-out pair.
  static final attendanceToday = <String, dynamic>{
    'id': 'at-today',
    'user': _uPriya,
    'date': _d(0),
    'status': 'present',
    'punches': [
      {
        'type': 'in',
        'timestamp': _ts(const Duration(hours: -6, minutes: -24)),
        'location': 'Koramangala, Bengaluru',
      },
    ],
  };

  static final attendance = <Map<String, dynamic>>[
    attendanceToday,
    for (var i = 1; i <= 12; i++)
      {
        'id': 'at-$i',
        'user': _uPriya,
        'date': _d(-i),
        'checkInAt': _ts(Duration(days: -i, hours: -9)),
        'checkOutAt': _ts(Duration(days: -i, hours: -1)),
        'status': i % 5 == 0 ? 'half_day' : 'present',
        'workedMinutes': i % 5 == 0 ? 245 : 480 + (i * 7) % 45,
        'checkInLocation': i.isEven
            ? 'Koramangala, Bengaluru'
            : 'Nashik depot, Maharashtra',
      },
  ];

  static final timesheets = <Map<String, dynamic>>[
    for (var i = 0; i < 14; i++)
      {
        'id': 'ts-$i',
        'user': _uPriya,
        'project': {
          'id': ['p1', 'p2', 'p3'][i % 3],
          'name': [
            'North India B2B expansion rollout',
            'Warehouse fleet digitisation',
            'Mobile app launch — Android & iOS',
          ][i % 3],
        },
        'task': {'id': 't${(i % 9) + 1}', 'name': tasks[i % 9]['title']},
        'date': _d(-i),
        'hours': [8, 7.5, 6, 4, 8, 5.5, 7][i % 7],
        'status': i < 5 ? 'draft' : (i < 10 ? 'submitted' : 'approved'),
        'isBillable': i % 3 != 2,
        'description': 'Delivery work',
      },
  ];

  static final timeOff = <Map<String, dynamic>>[
    {
      'id': 'to1',
      'user': _uPriya,
      'type': 'Annual leave',
      'status': 'pending',
      'startDate': _d(21),
      'endDate': _d(25),
      'days': 5,
      'reason': 'Family wedding in Jaipur',
    },
    {
      'id': 'to2',
      'user': _uPriya,
      'type': 'Sick leave',
      'status': 'approved',
      'startDate': _d(-9),
      'endDate': _d(-9),
      'days': 1,
      'approvedBy': _uDev,
    },
    {
      'id': 'to3',
      'user': _uPriya,
      'type': 'Work from home',
      'status': 'approved',
      'startDate': _d(6),
      'endDate': _d(6),
      'days': 1,
    },
  ];

  static final holidays = <Map<String, dynamic>>[
    {'id': 'h1', 'name': 'Gandhi Jayanti', 'date': _d(14), 'type': 'National'},
    {'id': 'h2', 'name': 'Diwali', 'date': _d(45), 'type': 'National'},
    {'id': 'h3', 'name': 'Independence Day', 'date': _d(-34), 'type': 'National'},
    {'id': 'h4', 'name': 'Karnataka Rajyotsava', 'date': _d(44), 'type': 'Regional'},
  ];

  // ---- Collaboration -----------------------------------------------------

  static final notifications = <Map<String, dynamic>>[
    {
      'id': 'n1',
      'title': 'Meera Pillai mentioned you',
      'body': 'Can you confirm the renewal pricing before Friday?',
      'type': 'mention',
      'isRead': false,
      'entityType': 'deal',
      'entityId': 'd1',
      'actor': _uMeera,
      'createdAt': _ts(const Duration(minutes: -24)),
    },
    {
      'id': 'n2',
      'title': 'Task assigned to you',
      'body': 'Depot walkthrough — Nashik',
      'type': 'assignment',
      'isRead': false,
      'entityType': 'task',
      'entityId': 't4',
      'actor': _uPriya,
      'createdAt': _ts(const Duration(hours: -3)),
    },
    {
      'id': 'n3',
      'title': 'Timesheet approved',
      'body': 'Your week of last Monday was approved.',
      'type': 'approval',
      'isRead': true,
      'actor': _uPriya,
      'createdAt': _ts(const Duration(days: -1)),
    },
    {
      'id': 'n4',
      'title': 'Invoice INV-2026-0148 is overdue',
      'body': 'Western Freight — ₹12,60,000 outstanding.',
      'type': 'billing',
      'isRead': true,
      'entityType': 'invoice',
      'entityId': 'i1',
      'createdAt': _ts(const Duration(days: -2)),
    },
  ];

  static final attachments = <Map<String, dynamic>>[
    {
      'id': 'at1',
      'name': 'vendor-warranty-terms.pdf',
      'url': 'https://autovella.cloud/files/vendor-warranty-terms.pdf',
      'size': 284512,
      'mimeType': 'application/pdf',
      'uploadedBy': _uArjun,
      'createdAt': _ts(const Duration(hours: -20)),
    },
    {
      'id': 'at2',
      'name': 'whiteboard-scope.jpg',
      'url': 'https://picsum.photos/seed/autovella1/1200/800',
      'size': 1841222,
      'mimeType': 'image/jpeg',
      'uploadedBy': _uPriya,
      'createdAt': _ts(const Duration(days: -1)),
    },
    {
      'id': 'at3',
      'name': 'depot-layout.jpg',
      'url': 'https://picsum.photos/seed/autovella2/1200/800',
      'size': 992014,
      'mimeType': 'image/jpeg',
      'uploadedBy': _uPriya,
      'createdAt': _ts(const Duration(days: -2)),
    },
  ];

  static final comments = <Map<String, dynamic>>[
    {
      'id': 'cm1',
      'body': '<p>Vendor came back — tier 2 covers parts <b>and</b> labour '
          'for 18 months. Pricing attached.</p>',
      'author': _uArjun,
      'createdAt': _ts(const Duration(hours: -20)),
    },
    {
      'id': 'cm2',
      'body': '<p>Good. Let\'s hold the customer callback until we have it in '
          'writing.</p>',
      'author': _uPriya,
      'createdAt': _ts(const Duration(hours: -4)),
    },
  ];

  static final subtasks = <Map<String, dynamic>>[
    {'id': 'st1', 'title': 'Get written confirmation from vendor', 'completed': true},
    {'id': 'st2', 'title': 'Compare tier 1 vs tier 2 pricing', 'completed': true},
    {'id': 'st3', 'title': 'Update the customer-facing warranty sheet', 'completed': false},
    {'id': 'st4', 'title': 'Schedule the Friday callback', 'completed': false},
  ];

  // ---- Sprints -----------------------------------------------------------

  static final sprints = <Map<String, dynamic>>[
    {
      'id': 's1',
      'name': 'Sprint 14 — Mobile foundations',
      'goal': 'Auth, navigation and the work module end to end.',
      'status': 'active',
      'projectId': 'p3',
      'startDate': _d(-6),
      'endDate': _d(8),
      'taskStats': {'total': 12, 'done': 5},
      'totalPoints': 34,
      'completedPoints': 15,
    },
    {
      'id': 's2',
      'name': 'Sprint 13 — Fleet cutover',
      'status': 'completed',
      'projectId': 'p2',
      'startDate': _d(-20),
      'endDate': _d(-6),
      'taskStats': {'total': 15, 'done': 15},
      'totalPoints': 40,
      'completedPoints': 40,
    },
  ];

  // ---- Long-tail modules --------------------------------------------------




  static final teams = <Map<String, dynamic>>[
    {'id': 'tm1', 'name': 'Delivery', 'description': '6 members', 'status': 'active'},
    {'id': 'tm2', 'name': 'Sales — North', 'description': '4 members', 'status': 'active'},
    {'id': 'tm3', 'name': 'Platform engineering', 'description': '9 members', 'status': 'active'},
  ];

  /// Directory rows: name, email and job title — no avatar blobs.
  static final users = <Map<String, dynamic>>[
    {..._uPriya, 'position': 'Product Owner', 'team': 'Product', 'isActive': true},
    {..._uArjun, 'position': 'Frontend Developer', 'team': 'Platform', 'isActive': true},
    {..._uMeera, 'position': 'Account Executive', 'team': 'Sales', 'isActive': true},
    {..._uDev, 'position': 'Delivery Lead', 'team': 'Delivery', 'isActive': true},
    {..._uSara, 'position': 'QA Engineer', 'team': 'Platform', 'isActive': true},
    {
      'id': '0U10070Former000',
      'firstName': 'Imran',
      'lastName': 'Qureshi',
      'email': 'former@example.com',
      'position': 'Backend Developer',
      'isActive': false,
    },
  ];

  static final automations = <Map<String, dynamic>>[
    {'id': 'au1', 'name': 'Notify owner when a deal slips past close date', 'isEnabled': true, 'description': 'Trigger: deal.closeDate passed'},
    {'id': 'au2', 'name': 'Create onboarding tasks on Closed Won', 'isEnabled': true, 'description': 'Trigger: deal.stage = Closed Won'},
    {'id': 'au3', 'name': 'Weekly timesheet reminder (Fri 4pm)', 'isEnabled': false, 'description': 'Trigger: schedule'},
  ];

  /// Ten days of allocations across the team, deliberately uneven so the
  /// planner shows free days, full days and one person over capacity.
  static final taskSchedules = <Map<String, dynamic>>[
    for (var d = 0; d < 10; d++)
      for (var u = 0; u < 5; u++)
        if ((d + u) % 3 != 0)
          {
            'id': 'sch-$d-$u',
            'userId': [
              _uPriya,
              _uArjun,
              _uMeera,
              _uDev,
              _uSara,
            ][u]['id'],
            'date': _d(d - 2),
            'hours': [4.0, 8.0, 6.0, 8.0, 10.0][(d + u) % 5],
            'title': 'Sprint 14 delivery',
          },
  ];

  static final analyticsKpis = <String, dynamic>{
    'scheduleVarianceDays': -3,
    'costPerformanceIndex': 0.94,
    'onTimeDeliveryRate': 0.82,
    'teamVelocity': 34,
    'avgCycleTimeDays': 4.6,
    'reopenRate': 0.07,
  };

  static final analyticsSummary = <String, dynamic>{
    'activeProjects': 4,
    'openTasks': 31,
    'billableHoursThisMonth': 486,
    'expenseTotal': 61170,
    'invoicedAmount': 3190000,
    'outstandingAmount': 1785000,
  };

  static final analyticsTeams = <String, dynamic>{
    'teams': 3,
    'peopleAllocated': 5,
    'utilisationRate': 0.78,
    'overAllocated': 1,
  };

  static final imports = <Map<String, dynamic>>[
    {
      'id': 'im1',
      'entityType': 'contacts',
      'fileName': 'north-india-contacts.csv',
      'status': 'completed',
      'total': 412,
      'succeeded': 401,
      'failed': 11,
      'createdAt': _ts(const Duration(days: -1)),
      'userName': 'Priya Sharma',
    },
    {
      'id': 'im2',
      'entityType': 'accounts',
      'fileName': 'apollo-accounts.xlsx',
      'status': 'completed',
      'total': 96,
      'succeeded': 96,
      'failed': 0,
      'createdAt': _ts(const Duration(days: -6)),
      'userName': 'Meera Pillai',
    },
  ];

  static final teamMembers = <Map<String, dynamic>>[
    {'id': 'tmm1', 'user': _uDev},
    {'id': 'tmm2', 'user': _uArjun},
    {'id': 'tmm3', 'user': _uSara},
  ];

  static final auditLog = <Map<String, dynamic>>[
    {'id': 'al1', 'action': 'update', 'entityType': 'deal', 'entityName': 'Harbour Labs — platform renewal', 'userName': 'Meera Pillai', 'createdAt': _ts(const Duration(hours: -2)), 'changes': {'stage': 'Qualification → Proposal', 'probability': '40 → 60'}},
    {'id': 'al2', 'action': 'create', 'entityType': 'invoice', 'entityName': 'INV-2026-0158', 'userName': 'Priya Sharma', 'createdAt': _ts(const Duration(hours: -5))},
    {'id': 'al3', 'action': 'approve', 'entityType': 'timesheet', 'entityName': 'Week of 8 Sep — Arjun Rao', 'userName': 'Dev Kapoor', 'createdAt': _ts(const Duration(hours: -7))},
    {'id': 'al4', 'action': 'delete', 'entityType': 'task', 'entityName': 'Duplicate: depot walkthrough', 'userName': 'Priya Sharma', 'createdAt': _ts(const Duration(hours: -9))},
    {'id': 'al5', 'action': 'update', 'entityType': 'user', 'entityName': 'Sara Khan', 'userName': 'Priya Sharma', 'createdAt': _ts(const Duration(days: -1)), 'changes': {'role': 'Developer → QA Engineer'}},
    {'id': 'al6', 'action': 'create', 'entityType': 'project', 'entityName': 'Mobile app launch — Android & iOS', 'userName': 'Priya Sharma', 'createdAt': _ts(const Duration(days: -1, hours: -3))},
    {'id': 'al7', 'action': 'login', 'entityType': 'session', 'entityName': 'meera@example.com', 'userName': 'Meera Pillai', 'createdAt': _ts(const Duration(days: -2))},
  ];


  static final templates = <Map<String, dynamic>>[
    {'id': 'tp1', 'name': 'Client onboarding (14 tasks)', 'description': 'Project template'},
    {'id': 'tp2', 'name': 'Depot cutover checklist', 'description': 'Project template'},
    {'id': 'tp3', 'name': 'Sprint retro', 'description': 'Task template'},
  ];

  static final roles = <Map<String, dynamic>>[
    {'id': 'r1', 'name': 'Admin', 'description': 'Full access', 'status': 'system'},
    {'id': 'r2', 'name': 'Delivery Lead', 'description': 'Projects, tasks, timesheets, approvals'},
    {'id': 'r3', 'name': 'Account Executive', 'description': 'CRM and invoices'},
    {'id': 'r4', 'name': 'Contractor', 'description': 'My work and timesheets only'},
  ];

  // Real recycle-bin rows use entityType/entityName/deletedByName.
  static final recycleBin = <Map<String, dynamic>>[
    {
      'id': 'rb1',
      'entityType': 'project',
      'entityName': 'Communication Management',
      'deletedByName': 'Priya Sharma',
      'deletedAt': _ts(const Duration(days: -3)),
      'expiresAt': _ts(const Duration(days: 27)),
    },
    {
      'id': 'rb2',
      'entityType': 'task',
      'entityName': 'Old pricing sheet review',
      'deletedByName': 'Meera Pillai',
      'deletedAt': _ts(const Duration(days: -8)),
      'expiresAt': _ts(const Duration(days: 22)),
    },
    {
      'id': 'rb3',
      'entityType': 'contact',
      'entityName': 'Duplicate — V. Rao',
      'deletedByName': 'Dev Kapoor',
      'deletedAt': _ts(const Duration(days: -12)),
      'expiresAt': _ts(const Duration(days: 18)),
    },
  ];

  static final exchangeRates = <Map<String, dynamic>>[
    {'id': 'er1', 'name': 'USD → INR', 'amount': 88.42, 'currency': 'INR', 'date': _d(0)},
    {'id': 'er2', 'name': 'EUR → INR', 'amount': 95.18, 'currency': 'INR', 'date': _d(0)},
    {'id': 'er3', 'name': 'GBP → INR', 'amount': 111.60, 'currency': 'INR', 'date': _d(0)},
  ];

  static final bookmarks = <Map<String, dynamic>>[
    {'id': 'bk1', 'name': 'North India B2B expansion rollout', 'description': 'Project'},
    {'id': 'bk2', 'name': 'Western Freight — fleet module', 'description': 'Deal'},
  ];

  static final savedViewsTasks = <Map<String, dynamic>>[
    {
      'id': 'sv1',
      'name': 'My overdue work',
      'entityType': 'tasks',
      'isDefault': true,
      'filter': {
        'match': 'all',
        'conditions': [
          {'field': 'status', 'operator': 'notEquals', 'value': 'done'},
          {'field': 'priority', 'operator': 'equals', 'value': 'high'},
        ],
      },
    },
    {
      'id': 'sv2',
      'name': 'Blocked or urgent',
      'entityType': 'tasks',
      'filter': {
        'match': 'any',
        'conditions': [
          {'field': 'status', 'operator': 'equals', 'value': 'blocked'},
          {'field': 'priority', 'operator': 'equals', 'value': 'urgent'},
        ],
      },
    },
    {
      'id': 'sv3',
      'name': 'Unestimated work',
      'entityType': 'tasks',
      'filter': {
        'match': 'all',
        'conditions': [
          {'field': 'storyPoints', 'operator': 'isEmpty'},
          {'field': 'status', 'operator': 'notEquals', 'value': 'done'},
        ],
      },
    },
  ];

  static final savedViewsDeals = <Map<String, dynamic>>[
    {
      'id': 'sv4',
      'name': 'Closing this quarter',
      'entityType': 'deals',
      'filter': {
        'match': 'all',
        'conditions': [
          {'field': 'stage', 'operator': 'notEquals', 'value': 'Closed Lost'},
        ],
      },
    },
  ];

  static final savedViews = <Map<String, dynamic>>[
    {'id': 'sv1', 'name': 'My overdue work', 'description': 'Tasks · assignee = me, due < today'},
    {'id': 'sv2', 'name': 'Pipeline closing this month', 'description': 'Deals · open, close date ≤ 30d'},
  ];


}
