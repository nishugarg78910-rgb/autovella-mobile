import '../core/util/json.dart';
import 'common.dart';

/// A company record.
class Account {
  const Account({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.website,
    this.industry,
    this.type,
    this.city,
    this.country,
    this.annualRevenue,
    this.employeeCount,
    this.currency,
    this.owner,
    this.description,
    this.customFields,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? website;
  final String? industry;
  final String? type;
  final String? city;
  final String? country;
  final double? annualRevenue;
  final int? employeeCount;
  final String? currency;
  final UserRef? owner;
  final String? description;
  final Map<String, dynamic>? customFields;
  final DateTime? createdAt;

  String get location =>
      [city, country].where((e) => e != null && e.isNotEmpty).join(', ');

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) {
      final w = words.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: J.str(json['id']),
        name: J.str(J.pick(json, ['name', 'companyName']), 'Unnamed account'),
        email: J.strOrNull(json['email']),
        phone: J.strOrNull(J.pick(json, ['phone', 'phoneNumber'])),
        website: J.strOrNull(json['website']),
        industry: J.strOrNull(json['industry']),
        type: J.strOrNull(json['type']),
        city: J.strOrNull(J.pick(json, ['city', 'billingCity'])),
        country: J.strOrNull(J.pick(json, ['country', 'billingCountry'])),
        annualRevenue: J.dblOrNull(json['annualRevenue']),
        employeeCount: J.intOrNull(J.pick(json, ['employeeCount', 'employees'])),
        currency: J.strOrNull(json['currency']),
        owner: UserRef.fromJson(json['owner']),
        description: J.strOrNull(json['description']),
        customFields: J.mapOrNull(json['customFields']),
        createdAt: J.date(json['createdAt']),
      );

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (website != null) 'website': website,
        if (industry != null) 'industry': industry,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
      };
}

/// A person at an account.
class Contact {
  const Contact({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.mobile,
    this.title,
    this.accountId,
    this.account,
    this.owner,
    this.leadSource,
    this.isPrimary = false,
    this.customFields,
    this.createdAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? mobile;
  final String? title;
  final String? accountId;
  final EntityRef? account;
  final UserRef? owner;
  final String? leadSource;
  final bool isPrimary;
  final Map<String, dynamic>? customFields;
  final DateTime? createdAt;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? (email ?? 'Unnamed contact') : name;
  }

  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    final s = fullName;
    return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
  }

  /// Best number to dial — mobile wins, which matters for field sales.
  String? get callableNumber {
    for (final n in [mobile, phone]) {
      if (n != null && n.trim().isNotEmpty) return n.trim();
    }
    return null;
  }

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: J.str(json['id']),
        firstName: J.str(json['firstName']),
        lastName: J.str(json['lastName']),
        email: J.strOrNull(json['email']),
        phone: J.strOrNull(J.pick(json, ['phone', 'phoneNumber', 'workPhone'])),
        mobile: J.strOrNull(J.pick(json, ['mobile', 'mobilePhone'])),
        title: J.strOrNull(J.pick(json, ['title', 'jobTitle', 'designation'])),
        accountId: J.strOrNull(json['accountId']),
        account: EntityRef.fromJson(json['account']),
        owner: UserRef.fromJson(json['owner']),
        leadSource: J.strOrNull(json['leadSource']),
        isPrimary: J.boolVal(json['isPrimary']),
        customFields: J.mapOrNull(json['customFields']),
        createdAt: J.date(json['createdAt']),
      );

  Map<String, dynamic> toCreateJson() => {
        'firstName': firstName,
        'lastName': lastName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (mobile != null) 'mobile': mobile,
        if (title != null) 'title': title,
        if (accountId != null) 'accountId': accountId,
      };
}

/// An opportunity. `stage` is free text on this platform ("Closed Won",
/// "Qualification", …) and organisations customise it, so nothing here
/// hard-codes a fixed pipeline.
class Deal {
  const Deal({
    required this.id,
    required this.name,
    this.stage,
    this.amount,
    this.currency,
    this.closeDate,
    this.probability,
    this.type,
    this.leadSource,
    this.description,
    this.notes,
    this.isActive = true,
    this.accountId,
    this.contactId,
    this.account,
    this.contact,
    this.owner,
    this.customFields,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? stage;
  final double? amount;
  final String? currency;
  final DateTime? closeDate;
  final int? probability;
  final String? type;
  final String? leadSource;
  final String? description;
  final String? notes;
  final bool isActive;
  final String? accountId;
  final String? contactId;
  final EntityRef? account;
  final EntityRef? contact;
  final UserRef? owner;
  final Map<String, dynamic>? customFields;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get _stageKey =>
      (stage ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  bool get isWon => _stageKey.contains('won');
  bool get isLost => _stageKey.contains('lost');
  bool get isOpen => !isWon && !isLost;

  /// Pipeline value weighted by probability — the number a sales lead
  /// actually forecasts on.
  double get weightedAmount {
    final value = amount ?? 0;
    final p = probability;
    if (p == null) return value;
    return value * (p / 100);
  }

  bool get isClosingSoon {
    if (closeDate == null || !isOpen) return false;
    final days = closeDate!.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 14;
  }

  bool get isSlipping =>
      closeDate != null && isOpen && closeDate!.isBefore(DateTime.now());

  factory Deal.fromJson(Map<String, dynamic> json) {
    final contactJson = J.mapOrNull(json['contact']);
    EntityRef? contactRef;
    if (contactJson != null) {
      final id = J.str(contactJson['id']);
      if (id.isNotEmpty) {
        final name =
            '${J.str(contactJson['firstName'])} ${J.str(contactJson['lastName'])}'
                .trim();
        contactRef = EntityRef(id: id, name: name.isEmpty ? 'Contact' : name);
      }
    }

    return Deal(
      id: J.str(json['id']),
      name: J.str(J.pick(json, ['name', 'title']), 'Untitled deal'),
      stage: J.strOrNull(J.pick(json, ['stage', 'status'])),
      amount: J.dblOrNull(J.pick(json, ['amount', 'value'])),
      currency: J.strOrNull(json['currency']),
      closeDate: J.date(J.pick(json, ['closeDate', 'expectedCloseDate'])),
      probability: J.intOrNull(json['probability']),
      type: J.strOrNull(json['type']),
      leadSource: J.strOrNull(json['leadSource']),
      description: J.strOrNull(json['description']),
      notes: J.strOrNull(json['notes']),
      isActive: J.boolVal(json['isActive'], true),
      accountId: J.strOrNull(json['accountId']),
      contactId: J.strOrNull(json['contactId']),
      account: EntityRef.fromJson(json['account']),
      contact: contactRef,
      owner: UserRef.fromJson(json['owner']),
      customFields: J.mapOrNull(json['customFields']),
      createdAt: J.date(json['createdAt']),
      updatedAt: J.date(json['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (stage != null) 'stage': stage,
        if (amount != null) 'amount': amount,
        if (currency != null) 'currency': currency,
        if (probability != null) 'probability': probability,
        if (accountId != null) 'accountId': accountId,
        if (contactId != null) 'contactId': contactId,
        if (leadSource != null) 'leadSource': leadSource,
        if (closeDate != null)
          'closeDate': '${closeDate!.year.toString().padLeft(4, '0')}-'
              '${closeDate!.month.toString().padLeft(2, '0')}-'
              '${closeDate!.day.toString().padLeft(2, '0')}',
      };
}
