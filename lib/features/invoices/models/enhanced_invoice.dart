import 'package:json_annotation/json_annotation.dart';

part 'enhanced_invoice.g.dart';

/// Enhanced invoice status enumeration with all required states
enum InvoiceStatus {
  draft,
  pending,
  approved,
  sent,
  viewed,
  partiallyPaid,
  paid,
  overdue,
  cancelled,
  disputed,
  voided,
  refunded,
}

/// Enhanced invoice with comprehensive business features
@JsonSerializable()
class EnhancedInvoice {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final String customerName;
  final String? customerEmail;
  final String? customerAddress;
  final DateTime issueDate;
  final DateTime dueDate;
  final InvoiceStatus status;
  final String currency;
  final double exchangeRate;
  final List<InvoiceLineItem> lineItems;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String? notes;
  final String? terms;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRecurring;
  final String? recurringPattern;
  final Map<String, dynamic> metadata;

  // Additional properties for compatibility with analytics
  final DateTime? paidAt;

  const EnhancedInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    this.customerEmail,
    this.customerAddress,
    required this.issueDate,
    required this.dueDate,
    required this.status,
    this.currency = 'SGD',
    this.exchangeRate = 1.0,
    required this.lineItems,
    required this.subtotal,
    required this.taxAmount,
    this.discountAmount = 0.0,
    required this.totalAmount,
    this.notes,
    this.terms,
    required this.createdAt,
    required this.updatedAt,
    this.isRecurring = false,
    this.recurringPattern,
    this.metadata = const {},
    this.paidAt,
  });

  factory EnhancedInvoice.fromJson(Map<String, dynamic> json) =>
      _$EnhancedInvoiceFromJson(json);

  Map<String, dynamic> toJson() => _$EnhancedInvoiceToJson(this);

  EnhancedInvoice copyWith({
    String? id,
    String? invoiceNumber,
    String? customerId,
    String? customerName,
    String? customerEmail,
    String? customerAddress,
    DateTime? issueDate,
    DateTime? dueDate,
    InvoiceStatus? status,
    String? currency,
    double? exchangeRate,
    List<InvoiceLineItem>? lineItems,
    double? subtotal,
    double? taxAmount,
    double? discountAmount,
    double? totalAmount,
    String? notes,
    String? terms,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRecurring,
    String? recurringPattern,
    Map<String, dynamic>? metadata,
    DateTime? paidAt,
  }) {
    return EnhancedInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      lineItems: lineItems ?? this.lineItems,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringPattern: recurringPattern ?? this.recurringPattern,
      metadata: metadata ?? this.metadata,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  /// Check if the invoice is overdue
  bool get isOverdue {
    return status != InvoiceStatus.paid &&
        status != InvoiceStatus.cancelled &&
        DateTime.now().isAfter(dueDate);
  }

  /// Get days until due (negative if overdue)
  int get daysUntilDue {
    return dueDate.difference(DateTime.now()).inDays;
  }

  // Convenience getters for backward compatibility
  DateTime get invoiceDate => issueDate;
  double get total => totalAmount;
  double get gstAmount => taxAmount;

  /// Get formatted status display text
  String get statusDisplay {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.approved:
        return 'Approved';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.viewed:
        return 'Viewed';
      case InvoiceStatus.partiallyPaid:
        return 'Partially Paid';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.disputed:
        return 'Disputed';
      case InvoiceStatus.voided:
        return 'Voided';
      case InvoiceStatus.refunded:
        return 'Refunded';
    }
  }
}

/// Invoice line item
@JsonSerializable()
class InvoiceLineItem {
  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final double taxRate;
  final double lineTotal;
  final String? productId;
  final String? unit;

  const InvoiceLineItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.taxRate = 0.0,
    required this.lineTotal,
    this.productId,
    this.unit,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) =>
      _$InvoiceLineItemFromJson(json);

  Map<String, dynamic> toJson() => _$InvoiceLineItemToJson(this);

  InvoiceLineItem copyWith({
    String? id,
    String? description,
    double? quantity,
    double? unitPrice,
    double? taxRate,
    double? lineTotal,
    String? productId,
    String? unit,
  }) {
    return InvoiceLineItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
      lineTotal: lineTotal ?? this.lineTotal,
      productId: productId ?? this.productId,
      unit: unit ?? this.unit,
    );
  }

  /// Calculate tax amount for this line
  double get taxAmount => lineTotal * (taxRate / 100);

  /// Calculate subtotal (before tax)
  double get subtotal => lineTotal - taxAmount;

  /// Compatibility getter for analytics service
  double get total => lineTotal;
}
