class Customer {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  final bool isActive;
  final bool gstRegistered;
  final String? uen; // Unique Entity Number for Singapore businesses
  final String? gstRegistrationNumber; // GST registration number (e.g., 200012345M)
  final String? countryCode; // For determining export/import status
  final String? billingAddress;
  final String? shippingAddress;
  
  const Customer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 0,
    this.isActive = true,
    this.gstRegistered = false,
    this.uen,
    this.gstRegistrationNumber,
    this.countryCode = 'SG',
    this.billingAddress,
    this.shippingAddress,
  });
  
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      syncStatus: json['sync_status'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      gstRegistered: json['gst_registered'] as bool? ?? false,
      uen: json['uen'] as String?,
      gstRegistrationNumber: json['gst_registration_number'] as String?,
      countryCode: json['country_code'] as String? ?? 'SG',
      billingAddress: json['billing_address'] as String?,
      shippingAddress: json['shipping_address'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'sync_status': syncStatus,
      'is_active': isActive,
      'gst_registered': gstRegistered,
      'uen': uen,
      'gst_registration_number': gstRegistrationNumber,
      'country_code': countryCode,
      'billing_address': billingAddress,
      'shipping_address': shippingAddress,
    };
  }
  
  factory Customer.fromDatabase(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      syncStatus: map['sync_status'] as int? ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      gstRegistered: map['gst_registered'] as bool? ?? false,
      uen: map['uen'] as String?,
      gstRegistrationNumber: map['gst_registration_number'] as String?,
      countryCode: map['country_code'] as String? ?? 'SG',
      billingAddress: map['billing_address'] as String?,
      shippingAddress: map['shipping_address'] as String?,
    );
  }
  
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'sync_status': syncStatus,
      'is_active': isActive,
      'gst_registered': gstRegistered,
      'uen': uen,
      'gst_registration_number': gstRegistrationNumber,
      'country_code': countryCode,
      'billing_address': billingAddress,
      'shipping_address': shippingAddress,
    };
  }
  
  Customer copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    bool? isActive,
    bool? gstRegistered,
    String? uen,
    String? gstRegistrationNumber,
    String? countryCode,
    String? billingAddress,
    String? shippingAddress,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isActive: isActive ?? this.isActive,
      gstRegistered: gstRegistered ?? this.gstRegistered,
      uen: uen ?? this.uen,
      gstRegistrationNumber: gstRegistrationNumber ?? this.gstRegistrationNumber,
      countryCode: countryCode ?? this.countryCode,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          phone == other.phone &&
          address == other.address;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      email.hashCode ^
      phone.hashCode ^
      address.hashCode;
  
  @override
  String toString() {
    return 'Customer(id: $id, name: $name, email: $email, phone: $phone, address: $address)';
  }

  /// Validates if the GST registration number format is correct for Singapore
  bool get hasValidGstNumber {
    if (gstRegistrationNumber == null || gstRegistrationNumber!.isEmpty) {
      return false;
    }
    // Singapore GST number format: 9 digits followed by 1 letter (e.g., 200012345M)
    return RegExp(r'^\d{9}[A-Z]$').hasMatch(gstRegistrationNumber!);
  }

  /// Returns true if this customer is considered an export customer
  bool get isExportCustomer {
    return countryCode != null && countryCode!.toUpperCase() != 'SG';
  }

  /// Returns the display name for GST status
  String get gstStatusDisplay {
    if (!gstRegistered) return 'Not GST Registered';
    if (hasValidGstNumber) return 'GST Registered (${gstRegistrationNumber})';
    return 'GST Registered (Invalid Number)';
  }
}