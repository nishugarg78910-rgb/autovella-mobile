import 'package:autovella_mobile/core/util/format.dart';
import 'package:autovella_mobile/core/util/json.dart';
import 'package:autovella_mobile/features/crm/crm_providers.dart';
import 'package:autovella_mobile/features/psa/psa_providers.dart';
import 'package:autovella_mobile/features/work/work_providers.dart';
import 'package:autovella_mobile/models/common.dart';
import 'package:autovella_mobile/models/crm.dart';
import 'package:autovella_mobile/models/finance.dart';
import 'package:autovella_mobile/features/people/people_screen.dart';
import 'package:autovella_mobile/models/hr.dart';
import 'package:autovella_mobile/core/offline/offline_queue.dart';
import 'package:autovella_mobile/features/config/app_config_provider.dart';
import 'package:autovella_mobile/models/app_config.dart';
import 'package:autovella_mobile/models/org.dart';
import 'package:autovella_mobile/models/work.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fmt.money', () {
    test('uses Indian grouping for INR', () {
      // 12,50,000 — not 1,250,000.
      expect(Fmt.money(1250000, currency: 'INR'), '₹12,50,000');
    });

    test('uses western grouping for USD', () {
      expect(Fmt.money(1250000, currency: 'USD'), r'$1,250,000');
    });

    test('abbreviates INR in lakh and crore', () {
      expect(Fmt.moneyShort(1250000, currency: 'INR'), '₹12.5L');
      expect(Fmt.moneyShort(25000000, currency: 'INR'), '₹2.5Cr');
      expect(Fmt.moneyShort(5000, currency: 'INR'), '₹5K');
    });

    test('abbreviates other currencies in K/M/B', () {
      expect(Fmt.moneyShort(2500000, currency: 'USD'), r'$2.5M');
    });

    test('renders null as an em dash rather than zero', () {
      expect(Fmt.money(null), '—');
    });
  });

  group('Fmt.plainText', () {
    test('strips HTML and entities from rich-text bodies', () {
      expect(
        Fmt.plainText('<p>Ship&nbsp;the <b>report</b> &amp; invoice</p>'),
        'Ship the report & invoice',
      );
    });

    test('truncates with an ellipsis', () {
      expect(Fmt.plainText('a' * 200, max: 10).length, 11);
    });
  });

  group('Tone', () {
    test('prettifies snake_case and camelCase statuses', () {
      expect(Tone.status('in_progress').label, 'In Progress');
      expect(Tone.status('inReview').label, 'In Review');
    });

    test('keeps multi-word API stages readable', () {
      expect(Tone.status('Closed Won').label, 'Closed Won');
    });

    test('falls back gracefully for org-defined custom statuses', () {
      expect(Tone.status('Awaiting Vendor').label, 'Awaiting Vendor');
    });
  });

  group('J (defensive JSON)', () {
    test('coerces numbers that arrive as strings', () {
      expect(J.dbl('12.5'), 12.5);
      expect(J.intVal('7'), 7);
    });

    test('survives a null or malformed field without throwing', () {
      expect(J.str(null), '');
      expect(J.date('not-a-date'), isNull);
      expect(J.maps('oops'), isEmpty);
    });

    test('pick returns the first present key', () {
      expect(J.pick({'dueDate': '2026-01-01'}, ['endDate', 'dueDate']),
          '2026-01-01');
    });
  });

  group('Task', () {
    Task make(Map<String, dynamic> overrides) =>
        Task.fromJson({'id': 't1', 'title': 'Task', ...overrides});

    test('reads endDate, falling back to dueDate', () {
      expect(make({'dueDate': '2026-03-01'}).endDate, isNotNull);
    });

    test('treats a completed status as done regardless of casing', () {
      expect(make({'status': 'Done'}).isDone, isTrue);
      expect(make({'status': 'in_progress'}).isDone, isFalse);
    });

    test('is overdue only when unfinished and past due', () {
      final past = Fmt.apiDate(DateTime.now().subtract(const Duration(days: 3)));
      expect(make({'endDate': past}).isOverdue, isTrue);
      expect(make({'endDate': past, 'status': 'done'}).isOverdue, isFalse);
    });
  });

  group('MyWorkBuckets', () {
    test('sorts each task into exactly one bucket', () {
      final now = DateTime.now();
      final tasks = [
        Task.fromJson({
          'id': '1',
          'title': 'overdue',
          'endDate': Fmt.apiDate(now.subtract(const Duration(days: 2))),
        }),
        Task.fromJson({
          'id': '2',
          'title': 'today',
          'endDate': Fmt.apiDate(now),
        }),
        Task.fromJson({
          'id': '3',
          'title': 'later',
          'endDate': Fmt.apiDate(now.add(const Duration(days: 5))),
        }),
        Task.fromJson({'id': '4', 'title': 'someday'}),
        Task.fromJson({'id': '5', 'title': 'shipped', 'status': 'done'}),
      ];

      final buckets = MyWorkBuckets.from(tasks, const AppConfig().taskStatuses);

      expect(buckets.overdue.single.title, 'overdue');
      expect(buckets.today.single.title, 'today');
      expect(buckets.upcoming.single.title, 'later');
      expect(buckets.noDate.single.title, 'someday');
      expect(buckets.completed.single.title, 'shipped');
      expect(buckets.openCount, 4);
    });
  });

  group('Deal', () {
    test('weights the amount by probability', () {
      final deal = Deal.fromJson({
        'id': 'd1',
        'name': 'Deal',
        'amount': 1000000,
        'probability': 20,
      });
      expect(deal.weightedAmount, 200000);
    });

    test('classifies won and lost from free-text stages', () {
      expect(Deal.fromJson({'id': '1', 'stage': 'Closed Won'}).isWon, isTrue);
      expect(Deal.fromJson({'id': '2', 'stage': 'Closed Lost'}).isLost, isTrue);
      expect(
        Deal.fromJson({'id': '3', 'stage': 'Qualification'}).isOpen,
        isTrue,
      );
    });
  });

  group('PipelineSummary', () {
    test('counts only open deals toward pipeline, won toward revenue', () {
      final summary = PipelineSummary.from([
        Deal.fromJson({
          'id': '1',
          'amount': 100000,
          'stage': 'Proposal',
          'probability': 50,
          'currency': 'INR',
        }),
        Deal.fromJson({
          'id': '2',
          'amount': 500000,
          'stage': 'Closed Won',
          'currency': 'INR',
        }),
      ]);

      expect(summary.openValue, 100000);
      expect(summary.weightedValue, 50000);
      expect(summary.wonValue, 500000);
      expect(summary.openCount, 1);
      expect(summary.currency, 'INR');
    });
  });

  group('Invoice', () {
    test('computes balance due and overdue state', () {
      final overdue = Invoice.fromJson({
        'id': 'i1',
        'invoiceNumber': 'INV-1',
        'total': 100000,
        'amountPaid': 40000,
        'status': 'sent',
        'dueDate':
            Fmt.apiDate(DateTime.now().subtract(const Duration(days: 10))),
      });

      expect(overdue.balanceDue, 60000);
      expect(overdue.isOverdue, isTrue);
      expect(overdue.daysOverdue, greaterThanOrEqualTo(9));
    });

    test('a paid invoice is never overdue', () {
      final paid = Invoice.fromJson({
        'id': 'i2',
        'total': 1000,
        'status': 'paid',
        'dueDate':
            Fmt.apiDate(DateTime.now().subtract(const Duration(days: 30))),
      });
      expect(paid.isOverdue, isFalse);
    });
  });

  group('InvoiceSummary', () {
    test('excludes drafts and cancelled invoices from outstanding', () {
      final summary = InvoiceSummary.from([
        Invoice.fromJson({'id': '1', 'total': 1000, 'status': 'draft'}),
        Invoice.fromJson({'id': '2', 'total': 2000, 'status': 'cancelled'}),
        Invoice.fromJson({'id': '3', 'total': 3000, 'status': 'sent'}),
      ]);
      expect(summary.outstanding, 3000);
    });
  });

  group('Project', () {
    test('falls back to task ratio when the server reports no progress', () {
      final project = Project.fromJson({
        'id': 'p1',
        'name': 'Project',
        'progressPercent': 0,
        'taskStats': {'total': 4, 'done': 1},
      });
      expect(project.progress, 0.25);
    });

    test('prefers the server-reported percentage', () {
      final project = Project.fromJson({
        'id': 'p2',
        'name': 'Project',
        'progressPercent': 80,
        'taskStats': {'total': 4, 'done': 1},
      });
      expect(project.progress, 0.8);
    });
  });

  group('Attendance (punch model)', () {
    Attendance make(List<Map<String, dynamic>> punches, {double? workHours}) =>
        Attendance.fromJson({
          'id': 'a1',
          'punches': punches,
          if (workHours != null) 'workHours': workHours,
        });

    test('is clocked in while the last punch is an "in"', () {
      final a = make([
        {'type': 'in', 'timestamp': '2026-09-18T09:00:00.000Z'},
      ]);
      expect(a.isCheckedIn, isTrue);
      expect(a.isComplete, isFalse);
    });

    test('is complete once an "out" closes the pair', () {
      final a = make([
        {'type': 'in', 'timestamp': '2026-09-18T09:00:00.000Z'},
        {'type': 'out', 'timestamp': '2026-09-18T17:30:00.000Z'},
      ]);
      expect(a.isCheckedIn, isFalse);
      expect(a.isComplete, isTrue);
      expect(a.worked, const Duration(hours: 8, minutes: 30));
    });

    test('sums multiple in/out pairs across a split day', () {
      final a = make([
        {'type': 'in', 'timestamp': '2026-09-18T09:00:00.000Z'},
        {'type': 'out', 'timestamp': '2026-09-18T13:00:00.000Z'},
        {'type': 'in', 'timestamp': '2026-09-18T14:00:00.000Z'},
        {'type': 'out', 'timestamp': '2026-09-18T18:00:00.000Z'},
      ]);
      expect(a.worked, const Duration(hours: 8));
      expect(a.firstIn, isNotNull);
      expect(a.lastOut, isNotNull);
    });

    test("prefers the server's workHours when given", () {
      final a = make([
        {'type': 'in', 'timestamp': '2026-09-18T09:00:00.000Z'},
        {'type': 'out', 'timestamp': '2026-09-18T17:00:00.000Z'},
      ], workHours: 7.5);
      expect(a.worked, const Duration(hours: 7, minutes: 30));
    });

    test('an empty day reports no time and is not clocked in', () {
      final a = make(const []);
      expect(a.worked, Duration.zero);
      expect(a.isCheckedIn, isFalse);
      expect(a.hasPunches, isFalse);
    });
  });

  group('Person (people directory)', () {
    test('reads a split first/last name with position and email', () {
      final p = Person.fromJson({
        'id': 'u1',
        'firstName': 'Aaditya',
        'lastName': 'Shukla',
        'email': 'aaditya@example.in',
        'position': 'Frontend Developer',
      });
      expect(p.fullName, 'Aaditya Shukla');
      expect(p.initials, 'AS');
      expect(p.position, 'Frontend Developer');
      expect(p.email, 'aaditya@example.in');
    });

    test('splits a single `name` field when that is all the API sends', () {
      final p = Person.fromJson({'id': 'u2', 'name': 'Priya Nair'});
      expect(p.firstName, 'Priya');
      expect(p.lastName, 'Nair');
      expect(p.initials, 'PN');
    });

    test('falls back to the email when there is no name at all', () {
      final p = Person.fromJson({'id': 'u3', 'email': 'ops@example.in'});
      expect(p.fullName, 'ops@example.in');
    });
  });

  group('Invoice line items', () {
    test('reads customItems, time entries and expense entries', () {
      final invoice = Invoice.fromJson({
        'id': 'i1',
        'invoiceNumber': 'INV-1',
        'total': 200000,
        'customItems': [
          {'description': 'DOLO', 'quantity': 1000, 'rate': 200, 'amount': 200000},
        ],
        'timeEntries': [],
        'expenseEntries': [],
      });
      expect(invoice.lineItems, hasLength(1));
      expect(invoice.lineItems.first.description, 'DOLO');
      expect(invoice.lineItems.first.unitPrice, 200);
      expect(invoice.lineItems.first.amount, 200000);
    });

    test('reads paidAmount, which is what the API actually sends', () {
      final invoice = Invoice.fromJson({
        'id': 'i2',
        'total': 200000,
        'paidAmount': 100000,
        'status': 'paid',
      });
      expect(invoice.balanceDue, 100000);
    });
  });

  group('HTML entity decoding', () {
    test('decodes entities stored in plain-text fields', () {
      // A real role in the platform is stored as
      // "Sales &amp; Business Development".
      expect(J.str('Sales &amp; Business Development'),
          'Sales & Business Development');
      expect(J.str('A &lt;b&gt; C'), 'A <b> C');
    });

    test('leaves ordinary text untouched', () {
      expect(J.str('Frontend Developer'), 'Frontend Developer');
    });
  });

  group('Field-level permissions', () {
    final perms = Permissions.fromJson({
      'tasks': {
        'read': true,
        'create': true,
        'update': true,
        'delete': false,
        'fields': {
          'estimatedHours': {'read': true, 'edit': false},
          'actualHours': {'read': false, 'edit': false},
        },
      },
      'invoices': {'read': true, 'update': false},
      'deals': {'read': false},
    });

    test('module CRUD still works', () {
      expect(perms.canRead('tasks'), isTrue);
      expect(perms.canDelete('tasks'), isFalse);
      expect(perms.isHidden('deals'), isTrue);
    });

    test('hides a field the role cannot read', () {
      expect(perms.canReadField('tasks', 'actualHours'), isFalse);
      expect(perms.canReadField('tasks', 'estimatedHours'), isTrue);
    });

    test('blocks editing a read-only field', () {
      expect(perms.canEditField('tasks', 'estimatedHours'), isFalse);
    });

    test('unlisted fields stay visible — the grid lists restrictions, '
        'not the whole schema', () {
      expect(perms.canReadField('tasks', 'title'), isTrue);
      expect(perms.canEditField('tasks', 'title'), isTrue);
    });

    test('a module with no update rights cannot edit any field', () {
      expect(perms.canEditField('invoices', 'total'), isFalse);
      expect(perms.canReadField('invoices', 'total'), isTrue);
    });

    test('fields of an unreadable module are unreadable', () {
      expect(perms.canReadField('deals', 'amount'), isFalse);
    });

    test('a module with no field grants is unrestricted', () {
      expect(perms.hasFieldGrants('tasks'), isTrue);
      expect(perms.hasFieldGrants('invoices'), isFalse);
    });
  });

  group('Fmt.moneyParts', () {
    test('never abbreviates a value under a thousand', () {
      // "0M" was reading as "OM" on a stat tile; a small value now carries no
      // unit at all.
      final (symbol, number, unit) = Fmt.moneyParts(0, currency: 'INR');
      expect(symbol, '₹');
      expect(number, '0');
      expect(unit, isEmpty);
    });

    test('splits lakh and crore into digits and unit', () {
      expect(Fmt.moneyParts(1250000, currency: 'INR'), ('₹', '12.5', 'L'));
      expect(Fmt.moneyParts(25000000, currency: 'INR'), ('₹', '2.5', 'Cr'));
      expect(Fmt.moneyParts(5000, currency: 'INR'), ('₹', '5', 'K'));
    });

    test('uses K/M/B for other currencies', () {
      expect(Fmt.moneyParts(2500000, currency: 'USD'), (r'$', '2.5', 'M'));
      expect(Fmt.moneyParts(999, currency: 'USD'), (r'$', '999', ''));
    });

    test('groups a sub-thousand INR value the Indian way', () {
      expect(Fmt.moneyParts(999, currency: 'INR').$2, '999');
    });

    test('carries the sign on negatives', () {
      expect(Fmt.moneyParts(-1250000, currency: 'INR').$2, '-12.5');
    });

    test('null reads as an em dash, not zero', () {
      expect(Fmt.moneyParts(null), ('', '—', ''));
    });
  });

  group('PendingWrite', () {
    test('round-trips through JSON', () {
      final write = PendingWrite(
        id: '42',
        method: 'POST',
        path: '/timesheets',
        label: 'Log 2h',
        body: const {'hours': 2},
        queuedAt: DateTime(2026, 9, 18, 10, 30),
        attempts: 1,
      );
      final restored = PendingWrite.fromJson(write.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, '42');
      expect(restored.method, 'POST');
      expect(restored.path, '/timesheets');
      expect(restored.label, 'Log 2h');
      expect(restored.body, {'hours': 2});
      expect(restored.attempts, 1);
      expect(restored.queuedAt, DateTime(2026, 9, 18, 10, 30));
    });

    test('rejects a row with no id rather than inventing one', () {
      expect(PendingWrite.fromJson({'method': 'POST'}), isNull);
    });

    test('copyWith bumps attempts without touching anything else', () {
      final write = PendingWrite(
        id: '1',
        method: 'PUT',
        path: '/tasks/1',
        label: 'Rename',
        queuedAt: DateTime(2026, 1, 1),
      );
      final next = write.copyWith(attempts: 2);
      expect(next.attempts, 2);
      expect(next.path, '/tasks/1');
      expect(next.queuedAt, write.queuedAt);
    });
  });

  group('J.str coercion (regression)', () {
    test('stringifies a number rather than returning a literal template', () {
      // This returned the literal "\$value" when the interpolation was
      // accidentally escaped — every non-string field would have rendered as
      // "\$value" on screen.
      expect(J.str(42), '42');
      expect(J.str(12.5), '12.5');
      expect(J.str(true), 'true');
    });

    test('still handles strings and nulls', () {
      expect(J.str('hello'), 'hello');
      expect(J.str(null, 'fallback'), 'fallback');
    });
  });

  group('Status catalog (organisation-defined completion)', () {
    // An org that renamed its completed status — exactly the case that
    // name-matching on "done" gets wrong.
    const custom = StatusCatalog([
      StatusDef(value: 'backlog', label: 'Backlog', isDefault: true),
      StatusDef(value: 'building', label: 'Building'),
      StatusDef(value: 'shipped', label: 'Shipped', isCompleted: true),
    ]);

    test('completion comes from the flag, not the name', () {
      expect(custom.isCompleted('shipped'), isTrue);
      expect(custom.isCompleted('building'), isFalse);
      // "done" is not even a status in this org.
      expect(custom.isCompleted('backlog'), isFalse);
    });

    test('a task in a renamed completed status counts as done', () {
      final task = Task.fromJson({
        'id': 't1',
        'title': 'Ship it',
        'status': 'shipped',
      });
      // The old name-matching getter gets this wrong...
      expect(task.isDone, isFalse);
      // ...the catalog-aware one does not.
      expect(task.isDoneIn(custom), isTrue);
    });

    test('and is therefore never counted as overdue', () {
      final task = Task.fromJson({
        'id': 't2',
        'title': 'Ship it',
        'status': 'shipped',
        'endDate': '2020-01-01',
      });
      expect(task.isOverdueIn(custom), isFalse);
    });

    test('uses the org label and default, not invented ones', () {
      expect(custom.labelFor('building'), 'Building');
      expect(custom.defaultValue, 'backlog');
    });

    test('tolerates hyphen/underscore drift in stored values', () {
      const stock = AppConfig();
      // The real stored value is `in-progress`; a client that writes
      // `in_progress` should still resolve.
      expect(stock.taskStatuses.find('in_progress')?.value, 'in-progress');
      expect(stock.taskStatuses.isCompleted('done'), isTrue);
    });

    test('falls back to name-matching for a status it has never seen', () {
      expect(custom.isCompleted('completed'), isTrue);
      expect(custom.isCompleted('in-flight'), isFalse);
    });
  });

  group('AppConfig parsing', () {
    test('reads customised statuses and currency', () {
      final config = AppConfig.fromJson({
        'defaultCurrency': 'usd',
        'taskStatuses': [
          {'value': 'open', 'label': 'Open', 'isDefault': true},
          {'value': 'closed', 'label': 'Closed', 'isCompleted': true},
        ],
      });
      expect(config.defaultCurrency, 'USD');
      expect(config.taskStatuses.statuses, hasLength(2));
      expect(config.taskStatuses.isCompleted('closed'), isTrue);
      // Project statuses were not customised, so the stock set applies.
      expect(config.projectStatuses.isCompleted('completed'), isTrue);
    });

    test('an empty payload yields the stock configuration', () {
      final config = AppConfig.fromJson({});
      expect(config.defaultCurrency, 'INR');
      expect(config.taskStatuses.defaultValue, 'todo');
      expect(config.taskStatuses.isCompleted('done'), isTrue);
    });
  });
}
