class Vendor {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final String? website;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  final bool isActive;
  final String? taxId;
  final String? bankAccount;
  final String? paymentTerms;
  final String? notes;
  final String? countryCode;

  const Vendor({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.contactPerson,
    this.website,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 0,
    this.isActive = true,
    this.taxId,
    this.bankAccount,
    this.paymentTerms,
    this.notes,
    this.countryCode = 'SG',
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      contactPerson: json['contact_person'] as String?,
      website: json['website'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      syncStatus: json['sync_status'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      taxId: json['tax_id'] as String?,
      bankAccount: json['bank_account'] as String?,
      paymentTerms: json['payment_terms'] as String?,
      notes: json['notes'] as String?,
      countryCode: json['country_code'] as String? ?? 'SG',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'contact_person': contactPerson,
      'website': website,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'sync_status': syncStatus,
      'is_active': isActive,
      'tax_id': taxId,
      'bank_account': bankAccount,
      'payment_terms': paymentTerms,
      'notes': notes,
      'country_code': countryCode,
    };
  }

  factory Vendor.fromDatabase(Map<String, dynamic> map) {
    return Vendor(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      contactPerson: map['contact_person'] as String?,
      website: map['website'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      syncStatus: map['sync_status'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      taxId: map['tax_id'] as String?,
      bankAccount: map['bank_account'] as String?,
      paymentTerms: map['payment_terms'] as String?,
      notes: map['notes'] as String?,
      countryCode: map['country_code'] as String? ?? 'SG',
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'contact_person': contactPerson,
      'website': website,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'sync_status': syncStatus,
      'is_active': isActive,
      'tax_id': taxId,
      'bank_account': bankAccount,
      'payment_terms': paymentTerms,
      'notes': notes,
      'country_code': countryCode,
    };
  }

  Vendor copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? contactPerson,
    String? website,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    bool? isActive,
    String? taxId,
    String? bankAccount,
    String? paymentTerms,
    String? notes,
    String? countryCode,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      website: website ?? this.website,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isActive: isActive ?? this.isActive,
      taxId: taxId ?? this.taxId,
      bankAccount: bankAccount ?? this.bankAccount,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      notes: notes ?? this.notes,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vendor &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          phone == other.phone;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ email.hashCode ^ phone.hashCode;

  @override
  String toString() {
    return 'Vendor(id: $id, name: $name, email: $email, phone: $phone)';
  }

  /// Returns the display name for payment terms
  String get paymentTermsDisplay {
    if (paymentTerms == null || paymentTerms!.isEmpty) return 'Not specified';
    switch (paymentTerms!.toLowerCase()) {
      case 'net30':
        return 'Net 30 days';
      case 'net15':
        return 'Net 15 days';
      case 'net7':
        return 'Net 7 days';
      case 'cod':
        return 'Cash on Delivery';
      case 'advance':
        return 'Advance Payment';
      default:
        return paymentTerms!;
    }
  }

  /// Returns true if this vendor is from a different country
  bool get isInternational {
    return countryCode != null && countryCode!.toUpperCase() != 'SG';
  }
}
