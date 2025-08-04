import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/crdt_types.dart';
import '../../../core/crdt/lww_register.dart';
import '../../../core/database/crdt_models.dart';

/// Invoice workflow states
enum InvoiceStatus {
  draft('draft'),
  pending('pending'),
  approved('approved'),
  sent('sent'),
  viewed('viewed'),
  partiallyPaid('partially_paid'),
  paid('paid'),
  overdue('overdue'),
  cancelled('cancelled'),
  disputed('disputed'),
  voided('voided'),
  refunded('refunded');

  const InvoiceStatus(this.value);
  final String value;

  static InvoiceStatus fromString(String value) {
    return InvoiceStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => InvoiceStatus.draft,
    );
  }
}

/// Invoice payment terms
enum PaymentTerm {
  net15('net_15', 15),
  net30('net_30', 30),
  net45('net_45', 45),
  net60('net_60', 60),
  net90('net_90', 90),
  dueOnReceipt('due_on_receipt', 0),
  custom('custom', 0);

  const PaymentTerm(this.value, this.days);
  final String value;
  final int days;

  static PaymentTerm fromString(String value) {
    return PaymentTerm.values.firstWhere(
      (term) => term.value == value,
      orElse: () => PaymentTerm.net30,
    );
  }
}

/// Invoice line item types
enum LineItemType {
  product('product'),
  service('service'),
  discount('discount'),
  shipping('shipping'),
  tax('tax'),
  custom('custom');

  const LineItemType(this.value);
  final String value;

  static LineItemType fromString(String value) {
    return LineItemType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => LineItemType.product,
    );
  }
}

/// Tax calculation method
enum TaxCalculationMethod {
  exclusive('exclusive'), // Tax added to amount
  inclusive('inclusive'), // Tax included in amount
  compound('compound'); // Tax on tax

  const TaxCalculationMethod(this.value);
  final String value;

  static TaxCalculationMethod fromString(String value) {
    return TaxCalculationMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => TaxCalculationMethod.exclusive,
    );
  }
}

/// CRDT-enabled Invoice Line Item
class CRDTInvoiceItem implements CRDTModel {
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

  // Line item fields as LWW-Registers
  late LWWRegister<String> invoiceId;
  late LWWRegister<String?> productId;
  late LWWRegister<String> description;
  late LWWRegister<LineItemType> itemType;
  late LWWRegister<double> quantity;
  late LWWRegister<double> unitPrice;
  late LWWRegister<double> discount;
  late LWWRegister<double> taxRate;
  late LWWRegister<TaxCalculationMethod> taxMethod;
  late LWWRegister<double> lineTotal;
  late LWWRegister<int> sortOrder;
  late LWWRegister<Map<String, dynamic>?> metadata;

  CRDTInvoiceItem({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String invoiceItemInvoiceId,
    String? invoiceItemProductId,
    required String invoiceItemDescription,
    LineItemType invoiceItemType = LineItemType.product,
    double invoiceItemQuantity = 1.0,
    double invoiceItemUnitPrice = 0.0,
    double invoiceItemDiscount = 0.0,
    double invoiceItemTaxRate = 0.0,
    TaxCalculationMethod invoiceItemTaxMethod = TaxCalculationMethod.exclusive,
    double invoiceItemLineTotal = 0.0,
    int invoiceItemSortOrder = 0,
    Map<String, dynamic>? invoiceItemMetadata,
    this.isDeleted = false,
  }) {
    invoiceId = LWWRegister(invoiceItemInvoiceId, createdAt);
    productId = LWWRegister(invoiceItemProductId, createdAt);
    description = LWWRegister(invoiceItemDescription, createdAt);
    itemType = LWWRegister(invoiceItemType, createdAt);
    quantity = LWWRegister(invoiceItemQuantity, createdAt);
    unitPrice = LWWRegister(invoiceItemUnitPrice, createdAt);
    discount = LWWRegister(invoiceItemDiscount, createdAt);
    taxRate = LWWRegister(invoiceItemTaxRate, createdAt);
    taxMethod = LWWRegister(invoiceItemTaxMethod, createdAt);
    lineTotal = LWWRegister(invoiceItemLineTotal, createdAt);
    sortOrder = LWWRegister(invoiceItemSortOrder, createdAt);
    metadata = LWWRegister(invoiceItemMetadata, createdAt);
  }

  /// Calculate line total based on quantity, unit price, discount, and tax
  double calculateLineTotal() {
    final qty = quantity.value;
    final price = unitPrice.value;
    final disc = discount.value;
    final tax = taxRate.value;
    final method = taxMethod.value;

    double subtotal = qty * price;

    // Apply discount
    if (disc > 0) {
      if (disc <= 1.0) {
        // Percentage discount
        subtotal = subtotal * (1 - disc);
      } else {
        // Fixed amount discount
        subtotal = subtotal - disc;
      }
    }

    // Apply tax based on calculation method
    double total = subtotal;
    if (method == TaxCalculationMethod.exclusive) {
      total = subtotal * (1 + tax / 100);
    } else if (method == TaxCalculationMethod.inclusive) {
      // Tax is already included, no calculation needed
      total = subtotal;
    }

    return total;
  }

  /// Update line item details
  void updateItem({
    String? newDescription,
    double? newQuantity,
    double? newUnitPrice,
    double? newDiscount,
    double? newTaxRate,
    TaxCalculationMethod? newTaxMethod,
    required HLCTimestamp timestamp,
  }) {
    if (newDescription != null) description.setValue(newDescription, timestamp);
    if (newQuantity != null) quantity.setValue(newQuantity, timestamp);
    if (newUnitPrice != null) unitPrice.setValue(newUnitPrice, timestamp);
    if (newDiscount != null) discount.setValue(newDiscount, timestamp);
    if (newTaxRate != null) taxRate.setValue(newTaxRate, timestamp);
    if (newTaxMethod != null) taxMethod.setValue(newTaxMethod, timestamp);

    // Recalculate and update line total
    final newTotal = calculateLineTotal();
    lineTotal.setValue(newTotal, timestamp);

    _updateTimestamp(timestamp);
  }

  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTInvoiceItem || other.id != id) {
      throw ArgumentError('Cannot merge with different invoice item');
    }

    // Merge all CRDT fields
    invoiceId.mergeWith(other.invoiceId);
    productId.mergeWith(other.productId);
    description.mergeWith(other.description);
    itemType.mergeWith(other.itemType);
    quantity.mergeWith(other.quantity);
    unitPrice.mergeWith(other.unitPrice);
    discount.mergeWith(other.discount);
    taxRate.mergeWith(other.taxRate);
    taxMethod.mergeWith(other.taxMethod);
    lineTotal.mergeWith(other.lineTotal);
    sortOrder.mergeWith(other.sortOrder);
    metadata.mergeWith(other.metadata);

    // Update version and timestamp
    version = version.update(other.version);
    if (other.updatedAt.happensAfter(updatedAt)) {
      updatedAt = other.updatedAt;
    }

    // Handle deletion
    isDeleted = isDeleted || other.isDeleted;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId.value,
      'product_id': productId.value,
      'description': description.value,
      'item_type': itemType.value.value,
      'quantity': quantity.value,
      'unit_price': unitPrice.value,
      'discount': discount.value,
      'tax_rate': taxRate.value,
      'tax_method': taxMethod.value.value,
      'line_total': lineTotal.value,
      'sort_order': sortOrder.value,
      'metadata': metadata.value,
      'is_deleted': isDeleted,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toString(),
      'updated_at': updatedAt.toString(),
      'version': version.toString(),
      'is_deleted': isDeleted,
      'invoice_id': invoiceId.toJson(),
      'product_id': productId.toJson(),
      'description': description.toJson(),
      'item_type': itemType.toJson(),
      'quantity': quantity.toJson(),
      'unit_price': unitPrice.toJson(),
      'discount': discount.toJson(),
      'tax_rate': taxRate.toJson(),
      'tax_method': taxMethod.toJson(),
      'line_total': lineTotal.toJson(),
      'sort_order': sortOrder.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}

/// CRDT-enabled Invoice Workflow Entry
class CRDTInvoiceWorkflow implements CRDTModel {
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

  // Workflow fields
  late LWWRegister<String> invoiceId;
  late LWWRegister<InvoiceStatus> fromStatus;
  late LWWRegister<InvoiceStatus> toStatus;
  late LWWRegister<String?> triggeredBy;
  late LWWRegister<String?> reason;
  late LWWRegister<DateTime> timestamp;
  late LWWRegister<Map<String, dynamic>?> context;

  CRDTInvoiceWorkflow({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String workflowInvoiceId,
    required InvoiceStatus workflowFromStatus,
    required InvoiceStatus workflowToStatus,
    String? workflowTriggeredBy,
    String? workflowReason,
    required DateTime workflowTimestamp,
    Map<String, dynamic>? workflowContext,
    this.isDeleted = false,
  }) {
    invoiceId = LWWRegister(workflowInvoiceId, createdAt);
    fromStatus = LWWRegister(workflowFromStatus, createdAt);
    toStatus = LWWRegister(workflowToStatus, createdAt);
    triggeredBy = LWWRegister(workflowTriggeredBy, createdAt);
    reason = LWWRegister(workflowReason, createdAt);
    timestamp = LWWRegister(workflowTimestamp, createdAt);
    context = LWWRegister(workflowContext, createdAt);
  }

  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTInvoiceWorkflow || other.id != id) {
      throw ArgumentError('Cannot merge with different workflow entry');
    }

    // Merge all CRDT fields
    invoiceId.mergeWith(other.invoiceId);
    fromStatus.mergeWith(other.fromStatus);
    toStatus.mergeWith(other.toStatus);
    triggeredBy.mergeWith(other.triggeredBy);
    reason.mergeWith(other.reason);
    timestamp.mergeWith(other.timestamp);
    context.mergeWith(other.context);

    // Update version and timestamp
    version = version.update(other.version);
    if (other.updatedAt.happensAfter(updatedAt)) {
      updatedAt = other.updatedAt;
    }

    // Handle deletion
    isDeleted = isDeleted || other.isDeleted;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId.value,
      'from_status': fromStatus.value.value,
      'to_status': toStatus.value.value,
      'triggered_by': triggeredBy.value,
      'reason': reason.value,
      'timestamp': timestamp.value.millisecondsSinceEpoch,
      'context': context.value,
      'is_deleted': isDeleted,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toString(),
      'updated_at': updatedAt.toString(),
      'version': version.toString(),
      'is_deleted': isDeleted,
      'invoice_id': invoiceId.toJson(),
      'from_status': fromStatus.toJson(),
      'to_status': toStatus.toJson(),
      'triggered_by': triggeredBy.toJson(),
      'reason': reason.toJson(),
      'timestamp': timestamp.toJson(),
      'context': context.toJson(),
    };
  }
}

/// CRDT-enabled Invoice Payment
class CRDTInvoicePayment implements CRDTModel {
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

  // Payment fields
  late LWWRegister<String> invoiceId;
  late LWWRegister<String> paymentReference;
  late LWWRegister<double> amount;
  late LWWRegister<DateTime> paymentDate;
  late LWWRegister<String>
      paymentMethod; // cash, bank_transfer, credit_card, paynow, etc.
  late LWWRegister<String> status; // pending, completed, failed, reversed
  late LWWRegister<String?> transactionId;
  late LWWRegister<String?> notes;
  late LWWRegister<Map<String, dynamic>?> paymentDetails;

  CRDTInvoicePayment({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String paymentInvoiceId,
    required String paymentPaymentReference,
    required double paymentAmount,
    required DateTime paymentPaymentDate,
    required String paymentPaymentMethod,
    String paymentStatus = 'pending',
    String? paymentTransactionId,
    String? paymentNotes,
    Map<String, dynamic>? paymentPaymentDetails,
    this.isDeleted = false,
  }) {
    invoiceId = LWWRegister(paymentInvoiceId, createdAt);
    paymentReference = LWWRegister(paymentPaymentReference, createdAt);
    amount = LWWRegister(paymentAmount, createdAt);
    paymentDate = LWWRegister(paymentPaymentDate, createdAt);
    paymentMethod = LWWRegister(paymentPaymentMethod, createdAt);
    status = LWWRegister(paymentStatus, createdAt);
    transactionId = LWWRegister(paymentTransactionId, createdAt);
    notes = LWWRegister(paymentNotes, createdAt);
    paymentDetails = LWWRegister(paymentPaymentDetails, createdAt);
  }

  /// Update payment status
  void updateStatus(String newStatus, HLCTimestamp timestamp) {
    status.setValue(newStatus, timestamp);
    _updateTimestamp(timestamp);
  }

  void _updateTimestamp(HLCTimestamp timestamp) {
    if (timestamp.happensAfter(updatedAt)) {
      updatedAt = timestamp;
      version = version.tick();
    }
  }

  @override
  void mergeWith(CRDTModel other) {
    if (other is! CRDTInvoicePayment || other.id != id) {
      throw ArgumentError('Cannot merge with different payment');
    }

    // Merge all CRDT fields
    invoiceId.mergeWith(other.invoiceId);
    paymentReference.mergeWith(other.paymentReference);
    amount.mergeWith(other.amount);
    paymentDate.mergeWith(other.paymentDate);
    paymentMethod.mergeWith(other.paymentMethod);
    status.mergeWith(other.status);
    transactionId.mergeWith(other.transactionId);
    notes.mergeWith(other.notes);
    paymentDetails.mergeWith(other.paymentDetails);

    // Update version and timestamp
    version = version.update(other.version);
    if (other.updatedAt.happensAfter(updatedAt)) {
      updatedAt = other.updatedAt;
    }

    // Handle deletion
    isDeleted = isDeleted || other.isDeleted;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId.value,
      'payment_reference': paymentReference.value,
      'amount': amount.value,
      'payment_date': paymentDate.value.millisecondsSinceEpoch,
      'payment_method': paymentMethod.value,
      'status': status.value,
      'transaction_id': transactionId.value,
      'notes': notes.value,
      'payment_details': paymentDetails.value,
      'is_deleted': isDeleted,
      'created_at': createdAt.physicalTime,
      'updated_at': updatedAt.physicalTime,
    };
  }

  @override
  Map<String, dynamic> toCRDTJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'created_at': createdAt.toString(),
      'updated_at': updatedAt.toString(),
      'version': version.toString(),
      'is_deleted': isDeleted,
      'invoice_id': invoiceId.toJson(),
      'payment_reference': paymentReference.toJson(),
      'amount': amount.toJson(),
      'payment_date': paymentDate.toJson(),
      'payment_method': paymentMethod.toJson(),
      'status': status.toJson(),
      'transaction_id': transactionId.toJson(),
      'notes': notes.toJson(),
      'payment_details': paymentDetails.toJson(),
    };
  }
}
