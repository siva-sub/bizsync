import '../crdt/hybrid_logical_clock.dart';
import '../crdt/crdt_types.dart';
import '../crdt/vector_clock.dart';

/// Base class for all CRDT-enabled business entities
abstract class CRDTModel {
  String get id;
  String get nodeId;
  HLCTimestamp get createdAt;
  HLCTimestamp get updatedAt;
  CRDTVectorClock get version;
  bool get isDeleted;

  Map<String, dynamic> toJson();
  Map<String, dynamic> toCRDTJson();
  void mergeWith(CRDTModel other);
}

/// CRDT-enabled Customer model
class CRDTCustomer implements CRDTModel {
  @override
  final String id;

  @override
  final String nodeId;

  @override
  final HLCTimestamp createdAt;

  @override
  HLCTimestamp updatedAt;

  @override
  CRDTVectorClock version;

  @override
  bool isDeleted;

  // Business fields as CRDT registers
  late CRDTRegister<String> name;
  late CRDTRegister<String> email;
  late CRDTRegister<String> phone;
  late CRDTRegister<String> address;
  late CRDTCounter loyaltyPoints;

  CRDTCustomer({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.loyaltyPoints,
    this.isDeleted = false,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name.value,
      'email': email.value,
      'phone': phone.value,
      'address': address.value,
      'loyalty_points': loyaltyPoints.value,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
      'is_deleted': isDeleted,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toJson(),
      'updated_at': updatedAt.toJson(),
      'version': version.toJson(),
      'is_deleted': isDeleted,
      'name': name.toJson(),
      'email': email.toJson(),
      'phone': phone.toJson(),
      'address': address.toJson(),
      'loyalty_points': loyaltyPoints.toJson(),
    };
  }

  static CRDTCustomer fromCRDTJson(Map<String, dynamic> json) {
    return CRDTCustomer(
      id: json['id'] as String,
      nodeId: json['node_id'] as String,
      createdAt:
          HLCTimestamp.fromJson(json['created_at'] as Map<String, dynamic>),
      updatedAt:
          HLCTimestamp.fromJson(json['updated_at'] as Map<String, dynamic>),
      version: VectorClock.fromJson(
          json['version'] as Map<String, dynamic>, json['node_id'] as String),
      name: CRDTRegister.fromJson<String>(json['name'] as Map<String, dynamic>),
      email:
          CRDTRegister.fromJson<String>(json['email'] as Map<String, dynamic>),
      phone:
          CRDTRegister.fromJson<String>(json['phone'] as Map<String, dynamic>),
      address: CRDTRegister.fromJson<String>(
          json['address'] as Map<String, dynamic>),
      loyaltyPoints:
          CRDTCounter.fromJson(json['loyalty_points'] as Map<String, dynamic>),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTCustomer || other.id != id) return;

    // Merge all CRDT fields
    name.mergeWith(other.name);
    email.mergeWith(other.email);
    phone.mergeWith(other.phone);
    address.mergeWith(other.address);
    loyaltyPoints.mergeWith(other.loyaltyPoints);

    // Update timestamps and version
    if (other.updatedAt.compareTo(updatedAt) > 0) {
      updatedAt = other.updatedAt;
    }
    version = version.update(other.version);

    // Handle deletion (tombstone)
    isDeleted = isDeleted || other.isDeleted;
  }
}

/// CRDT-enabled Invoice model (simplified for demo)
class CRDTInvoice implements CRDTModel {
  @override
  final String id;

  @override
  final String nodeId;

  @override
  final HLCTimestamp createdAt;

  @override
  HLCTimestamp updatedAt;

  @override
  CRDTVectorClock version;

  @override
  bool isDeleted;

  // Business fields
  late CRDTRegister<String> invoiceNumber;
  late CRDTRegister<String> customerId;
  late CRDTRegister<String> status;
  late CRDTRegister<double> totalAmount;
  late CRDTRegister<String> currency;

  CRDTInvoice({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.invoiceNumber,
    required this.customerId,
    required this.status,
    required this.totalAmount,
    required this.currency,
    this.isDeleted = false,
  });

  double get remainingBalance => totalAmount.value; // Simplified for demo

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber.value,
      'customer_id': customerId.value,
      'status': status.value,
      'total_amount': totalAmount.value,
      'currency': currency.value,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
      'is_deleted': isDeleted,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toJson(),
      'updated_at': updatedAt.toJson(),
      'version': version.toJson(),
      'is_deleted': isDeleted,
      'invoice_number': invoiceNumber.toJson(),
      'customer_id': customerId.toJson(),
      'status': status.toJson(),
      'total_amount': totalAmount.toJson(),
      'currency': currency.toJson(),
    };
  }

  static CRDTInvoice fromCRDTJson(Map<String, dynamic> json) {
    return CRDTInvoice(
      id: json['id'] as String,
      nodeId: json['node_id'] as String,
      createdAt:
          HLCTimestamp.fromJson(json['created_at'] as Map<String, dynamic>),
      updatedAt:
          HLCTimestamp.fromJson(json['updated_at'] as Map<String, dynamic>),
      version: VectorClock.fromJson(
          json['version'] as Map<String, dynamic>, json['node_id'] as String),
      invoiceNumber: CRDTRegister.fromJson<String>(
          json['invoice_number'] as Map<String, dynamic>),
      customerId: CRDTRegister.fromJson<String>(
          json['customer_id'] as Map<String, dynamic>),
      status:
          CRDTRegister.fromJson<String>(json['status'] as Map<String, dynamic>),
      totalAmount: CRDTRegister.fromJson<double>(
          json['total_amount'] as Map<String, dynamic>),
      currency: CRDTRegister.fromJson<String>(
          json['currency'] as Map<String, dynamic>),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTInvoice || other.id != id) return;

    // Merge all CRDT fields
    invoiceNumber.mergeWith(other.invoiceNumber);
    customerId.mergeWith(other.customerId);
    status.mergeWith(other.status);
    totalAmount.mergeWith(other.totalAmount);
    currency.mergeWith(other.currency);

    // Update timestamps and version
    if (other.updatedAt.compareTo(updatedAt) > 0) {
      updatedAt = other.updatedAt;
    }
    version = version.update(other.version);

    // Handle deletion
    isDeleted = isDeleted || other.isDeleted;
  }
}

/// CRDT-enabled Accounting Transaction model for double-entry bookkeeping
class CRDTAccountingTransaction implements CRDTModel {
  @override
  final String id;

  @override
  final String nodeId;

  @override
  final HLCTimestamp createdAt;

  @override
  HLCTimestamp updatedAt;

  @override
  CRDTVectorClock version;

  @override
  bool isDeleted;

  // Transaction fields
  late CRDTRegister<String> transactionNumber;
  late CRDTRegister<String> description;
  late CRDTRegister<DateTime> transactionDate;
  late CRDTRegister<String> reference;
  late CRDTRegister<double> amount;
  late CRDTRegister<String> currency;
  late CRDTRegister<String> debitAccount;
  late CRDTRegister<String> creditAccount;
  late CRDTRegister<String> category;
  late CRDTRegister<String> status;

  CRDTAccountingTransaction({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.transactionNumber,
    required this.description,
    required this.transactionDate,
    required this.reference,
    required this.amount,
    required this.currency,
    required this.debitAccount,
    required this.creditAccount,
    required this.category,
    required this.status,
    this.isDeleted = false,
  });

  // Double-entry bookkeeping getters
  bool get isBalanced => totalDebit == totalCredit;
  double get totalDebit => amount.value;
  double get totalCredit => amount.value;

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_number': transactionNumber.value,
      'description': description.value,
      'transaction_date': transactionDate.value.millisecondsSinceEpoch,
      'reference': reference.value,
      'amount': amount.value,
      'currency': currency.value,
      'debit_account': debitAccount.value,
      'credit_account': creditAccount.value,
      'category': category.value,
      'status': status.value,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
      'is_deleted': isDeleted,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toJson(),
      'updated_at': updatedAt.toJson(),
      'version': version.toJson(),
      'is_deleted': isDeleted,
      'transaction_number': transactionNumber.toJson(),
      'description': description.toJson(),
      'transaction_date': transactionDate.toJson(),
      'reference': reference.toJson(),
      'amount': amount.toJson(),
      'currency': currency.toJson(),
      'debit_account': debitAccount.toJson(),
      'credit_account': creditAccount.toJson(),
      'category': category.toJson(),
      'status': status.toJson(),
    };
  }

  static CRDTAccountingTransaction fromCRDTJson(Map<String, dynamic> json) {
    return CRDTAccountingTransaction(
      id: json['id'] as String,
      nodeId: json['node_id'] as String,
      createdAt:
          HLCTimestamp.fromJson(json['created_at'] as Map<String, dynamic>),
      updatedAt:
          HLCTimestamp.fromJson(json['updated_at'] as Map<String, dynamic>),
      version: VectorClock.fromJson(
          json['version'] as Map<String, dynamic>, json['node_id'] as String),
      transactionNumber: CRDTRegister.fromJson<String>(
          json['transaction_number'] as Map<String, dynamic>),
      description: CRDTRegister.fromJson<String>(
          json['description'] as Map<String, dynamic>),
      transactionDate: CRDTRegister.fromJson<DateTime>(
          json['transaction_date'] as Map<String, dynamic>),
      reference: CRDTRegister.fromJson<String>(
          json['reference'] as Map<String, dynamic>),
      amount:
          CRDTRegister.fromJson<double>(json['amount'] as Map<String, dynamic>),
      currency: CRDTRegister.fromJson<String>(
          json['currency'] as Map<String, dynamic>),
      debitAccount: CRDTRegister.fromJson<String>(
          json['debit_account'] as Map<String, dynamic>),
      creditAccount: CRDTRegister.fromJson<String>(
          json['credit_account'] as Map<String, dynamic>),
      category: CRDTRegister.fromJson<String>(
          json['category'] as Map<String, dynamic>),
      status:
          CRDTRegister.fromJson<String>(json['status'] as Map<String, dynamic>),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTAccountingTransaction || other.id != id) return;

    // Merge all CRDT fields
    transactionNumber.mergeWith(other.transactionNumber);
    description.mergeWith(other.description);
    transactionDate.mergeWith(other.transactionDate);
    reference.mergeWith(other.reference);
    amount.mergeWith(other.amount);
    currency.mergeWith(other.currency);
    debitAccount.mergeWith(other.debitAccount);
    creditAccount.mergeWith(other.creditAccount);
    category.mergeWith(other.category);
    status.mergeWith(other.status);

    // Update timestamps and version
    if (other.updatedAt.compareTo(updatedAt) > 0) {
      updatedAt = other.updatedAt;
    }
    version = version.update(other.version);

    // Handle deletion
    isDeleted = isDeleted || other.isDeleted;
  }
}
