import '../core/util/json.dart';
import 'common.dart';

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    this.status,
    this.accountId,
    this.account,
    this.projectId,
    this.project,
    this.issueDate,
    this.dueDate,
    this.paidAt,
    this.subtotal,
    this.taxAmount,
    this.total,
    this.amountPaid,
    this.currency,
    this.notes,
    this.discount,
    this.paymentTerms,
    this.lineItems = const [],
    this.createdAt,
  });

  final String id;
  final String number;
  final String? status;
  final String? accountId;
  final EntityRef? account;
  final String? projectId;
  final EntityRef? project;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final double? subtotal;
  final double? taxAmount;
  final double? total;
  final double? amountPaid;
  final String? currency;
  final String? notes;
  final double? discount;
  final String? paymentTerms;
  final List<InvoiceLine> lineItems;
  final DateTime? createdAt;

  String get _statusKey =>
      (status ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  bool get isPaid => paidAt != null || _statusKey == 'paid';
  bool get isCancelled => _statusKey == 'cancelled' || _statusKey == 'canceled';
  bool get isDraft => _statusKey == 'draft';

  /// Unpaid and past its due date — what the collections view keys on.
  bool get isOverdue =>
      !isPaid &&
      !isCancelled &&
      dueDate != null &&
      dueDate!.isBefore(DateTime.now());

  double get balanceDue {
    final t = total ?? 0;
    return (t - (amountPaid ?? 0)).clamp(0, double.infinity);
  }

  int get daysOverdue {
    if (!isOverdue) return 0;
    return DateTime.now().difference(dueDate!).inDays;
  }

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: J.str(json['id']),
        number: J.str(
          J.pick(json, ['invoiceNumber', 'number', 'reference']),
          'Draft',
        ),
        status: J.strOrNull(json['status']),
        accountId: J.strOrNull(json['accountId']),
        account: EntityRef.fromJson(json['account'] ?? json['customer']),
        projectId: J.strOrNull(json['projectId']),
        project: EntityRef.fromJson(json['project']),
        issueDate: J.date(J.pick(json, ['issueDate', 'invoiceDate', 'date'])),
        dueDate: J.date(json['dueDate']),
        paidAt: J.date(J.pick(json, ['paidAt', 'paidDate'])),
        subtotal: J.dblOrNull(json['subtotal']),
        taxAmount: J.dblOrNull(J.pick(json, ['taxAmount', 'tax'])),
        discount: J.dblOrNull(json['discount']),
        paymentTerms: J.strOrNull(json['paymentTerms']),
        total: J.dblOrNull(J.pick(json, ['total', 'totalAmount', 'amount'])),
        amountPaid: J.dblOrNull(J.pick(json, ['paidAmount', 'amountPaid'])),
        currency: J.strOrNull(json['currency']),
        notes: J.strOrNull(json['notes']),
        // The API splits lines three ways: ad-hoc `customItems`, plus
        // billable `timeEntries` and `expenseEntries` pulled from delivery.
        // An earlier build looked for `lineItems`, which does not exist, so
        // every invoice rendered with no lines.
        lineItems: [
          ...J.objects(json['customItems'], InvoiceLine.fromJson),
          ...J.objects(json['timeEntries'], InvoiceLine.fromJson),
          ...J.objects(json['expenseEntries'], InvoiceLine.fromJson),
        ],
        createdAt: J.date(json['createdAt']),
      );
}

class InvoiceLine {
  const InvoiceLine({
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.amount = 0,
  });

  final String description;
  final double quantity;
  final double unitPrice;
  final double amount;

  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    final qty = J.dbl(J.pick(json, ['quantity', 'qty']), 1);
    final unit = J.dbl(J.pick(json, ['unitPrice', 'rate', 'price']));
    return InvoiceLine(
      description: J.str(J.pick(json, ['description', 'name', 'item']), 'Item'),
      quantity: qty,
      unitPrice: unit,
      amount: J.dbl(J.pick(json, ['amount', 'total']), qty * unit),
    );
  }
}

class Expense {
  const Expense({
    required this.id,
    required this.description,
    this.amount = 0,
    this.currency,
    this.category,
    this.status,
    this.date,
    this.projectId,
    this.project,
    this.user,
    this.isBillable = false,
    this.isReimbursable = false,
    this.receiptUrl,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String description;
  final double amount;
  final String? currency;
  final String? category;
  final String? status;
  final DateTime? date;
  final String? projectId;
  final EntityRef? project;
  final UserRef? user;
  final bool isBillable;
  final bool isReimbursable;
  final String? receiptUrl;
  final String? notes;
  final DateTime? createdAt;

  bool get hasReceipt => (receiptUrl ?? '').isNotEmpty;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: J.str(json['id']),
        description: J.str(
          J.pick(json, ['description', 'title', 'name']),
          'Expense',
        ),
        amount: J.dbl(J.pick(json, ['amount', 'total'])),
        currency: J.strOrNull(json['currency']),
        category: J.strOrNull(json['category']),
        status: J.strOrNull(json['status']),
        date: J.date(J.pick(json, ['date', 'expenseDate', 'incurredAt'])),
        projectId: J.strOrNull(json['projectId']),
        project: EntityRef.fromJson(json['project']),
        user: UserRef.fromJson(json['user'] ?? json['createdBy']),
        isBillable: J.boolVal(json['isBillable']),
        isReimbursable: J.boolVal(json['isReimbursable']),
        receiptUrl: J.strOrNull(J.pick(json, ['receiptUrl', 'receipt', 'attachmentUrl'])),
        notes: J.strOrNull(json['notes']),
        createdAt: J.date(json['createdAt']),
      );

  Map<String, dynamic> toCreateJson() => {
        'description': description,
        'amount': amount,
        if (currency != null) 'currency': currency,
        if (category != null) 'category': category,
        if (projectId != null) 'projectId': projectId,
        if (date != null)
          'date': '${date!.year.toString().padLeft(4, '0')}-'
              '${date!.month.toString().padLeft(2, '0')}-'
              '${date!.day.toString().padLeft(2, '0')}',
        'isBillable': isBillable,
        'isReimbursable': isReimbursable,
        if (notes != null) 'notes': notes,
      };
}
