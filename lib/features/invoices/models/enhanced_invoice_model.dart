import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/crdt_types.dart';
import '../../../core/crdt/lww_register.dart';
import '../../../core/crdt/pn_counter.dart';
import '../../../core/crdt/or_set.dart';
import '../../../core/database/crdt_models.dart';
import 'invoice_models.dart';

/// Enhanced CRDT-enabled Invoice with comprehensive workflow tracking
class CRDTInvoiceEnhanced implements CRDTModel {
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

  // Core invoice fields as LWW-Registers
  late LWWRegister<String> invoiceNumber;
  late LWWRegister<String?> customerId;
  late LWWRegister<String?> customerName;
  late LWWRegister<String?> customerEmail;
  late LWWRegister<String?> billingAddress;
  late LWWRegister<String?> shippingAddress;

  // Dates and terms
  late LWWRegister<DateTime> issueDate;
  late LWWRegister<DateTime?> dueDate;
  late LWWRegister<PaymentTerm> paymentTerms;
  late LWWRegister<String?> poNumber;
  late LWWRegister<String?> reference;

  // Status and workflow
  late LWWRegister<InvoiceStatus> status;
  late LWWRegister<DateTime?> sentDate;
  late LWWRegister<DateTime?> viewedDate;
  late LWWRegister<DateTime?> paidAt;
  late LWWRegister<DateTime?> lastPaymentDate;

  // Financial fields
  late LWWRegister<double> subtotal;
  late LWWRegister<double> taxAmount;
  late LWWRegister<double> discountAmount;
  late LWWRegister<double> shippingAmount;
  late LWWRegister<double> totalAmount;
  late LWWRegister<String> currency;
  late LWWRegister<double> exchangeRate;

  // Payment tracking
  late PNCounter paymentsReceived; // in minor currency units (cents)
  late LWWRegister<DateTime?> lastReminderSent;
  late LWWRegister<int> reminderCount;

  // Content and customization
  late LWWRegister<String?> notes;
  late LWWRegister<String?> termsAndConditions;
  late LWWRegister<String?> footerText;
  late LWWRegister<Map<String, dynamic>?> customFields;

  // Document management
  late LWWRegister<String?> pdfUrl;
  late LWWRegister<String?> pdfHash;
  late LWWRegister<DateTime?> lastPdfGenerated;

  // Related entities as OR-Sets
  late ORSet<String> itemIds;
  late ORSet<String> paymentIds;
  late ORSet<String> workflowEntryIds;
  late ORSet<String> attachmentIds;
  late ORSet<String> tags;

  // Dispute and adjustment tracking
  late LWWRegister<bool> isDisputed;
  late LWWRegister<String?> disputeReason;
  late LWWRegister<DateTime?> disputeDate;
  late LWWRegister<double> adjustmentAmount;
  late LWWRegister<String?> adjustmentReason;

  // Automation and settings
  late LWWRegister<bool> autoReminders;
  late LWWRegister<int?> reminderDaysBefore;
  late LWWRegister<bool> autoFollowUp;
  late LWWRegister<bool> isRecurring;
  late LWWRegister<Map<String, dynamic>?> automationSettings;

  CRDTInvoiceEnhanced({
    required this.id,
    required this.nodeId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required String invoiceNum,
    String? customer,
    String? customerNameValue,
    String? customerEmailValue,
    String? billingAddr,
    String? shippingAddr,
    required DateTime issue,
    DateTime? due,
    PaymentTerm payment = PaymentTerm.net30,
    String? po,
    String? ref,
    InvoiceStatus invoiceStatus = InvoiceStatus.draft,
    DateTime? sent,
    DateTime? viewed,
    DateTime? paid,
    DateTime? lastPayment,
    double sub = 0.0,
    double tax = 0.0,
    double discount = 0.0,
    double shipping = 0.0,
    double total = 0.0,
    String curr = 'SGD',
    double exchange = 1.0,
    DateTime? lastReminder,
    int reminders = 0,
    String? invoiceNotes,
    String? terms,
    String? footer,
    Map<String, dynamic>? custom,
    String? pdf,
    String? pdfHashValue,
    DateTime? lastPdf,
    bool disputed = false,
    String? disputeReasonValue,
    DateTime? disputeDateValue,
    double adjustment = 0.0,
    String? adjustmentReasonValue,
    bool autoRem = true,
    int? reminderDays,
    bool autoFollow = true,
    bool recurring = false,
    Map<String, dynamic>? automation,
    this.isDeleted = false,
  }) {
    // Validate required non-null parameters
    if (invoiceNum.isEmpty) {
      throw ArgumentError('Invoice number cannot be empty');
    }
    if (curr.isEmpty) {
      throw ArgumentError('Currency cannot be empty');
    }
    // Initialize all LWW-Registers with null-safe values
    invoiceNumber = LWWRegister(invoiceNum, createdAt);
    customerId = LWWRegister(customer, createdAt);
    customerName = LWWRegister(customerNameValue, createdAt);
    customerEmail = LWWRegister(customerEmailValue, createdAt);
    billingAddress = LWWRegister(billingAddr, createdAt);
    shippingAddress = LWWRegister(shippingAddr, createdAt);

    issueDate = LWWRegister(issue, createdAt);
    dueDate = LWWRegister(due, createdAt);
    paymentTerms = LWWRegister(payment, createdAt);
    poNumber = LWWRegister(po, createdAt);
    reference = LWWRegister(ref, createdAt);

    status = LWWRegister(invoiceStatus, createdAt);
    sentDate = LWWRegister(sent, createdAt);
    viewedDate = LWWRegister(viewed, createdAt);
    paidAt = LWWRegister(paid, createdAt);
    lastPaymentDate = LWWRegister(lastPayment, createdAt);

    subtotal = LWWRegister(sub, createdAt);
    taxAmount = LWWRegister(tax, createdAt);
    discountAmount = LWWRegister(discount, createdAt);
    shippingAmount = LWWRegister(shipping, createdAt);
    totalAmount = LWWRegister(total, createdAt);
    currency = LWWRegister(curr, createdAt);
    exchangeRate = LWWRegister(exchange, createdAt);

    paymentsReceived = PNCounter(nodeId);
    lastReminderSent = LWWRegister(lastReminder, createdAt);
    reminderCount = LWWRegister(reminders, createdAt);

    notes = LWWRegister(invoiceNotes, createdAt);
    termsAndConditions = LWWRegister(terms, createdAt);
    footerText = LWWRegister(footer, createdAt);
    customFields = LWWRegister(custom, createdAt);

    pdfUrl = LWWRegister(pdf, createdAt);
    pdfHash = LWWRegister(pdfHashValue, createdAt);
    lastPdfGenerated = LWWRegister(lastPdf, createdAt);

    // Initialize OR-Sets
    itemIds = ORSet(nodeId);
    paymentIds = ORSet(nodeId);
    workflowEntryIds = ORSet(nodeId);
    attachmentIds = ORSet(nodeId);
    tags = ORSet(nodeId);

    isDisputed = LWWRegister(disputed, createdAt);
    disputeReason = LWWRegister(disputeReasonValue, createdAt);
    disputeDate = LWWRegister(disputeDateValue, createdAt);
    adjustmentAmount = LWWRegister(adjustment, createdAt);
    adjustmentReason = LWWRegister(adjustmentReasonValue, createdAt);

    autoReminders = LWWRegister(autoRem, createdAt);
    reminderDaysBefore = LWWRegister(reminderDays, createdAt);
    autoFollowUp = LWWRegister(autoFollow, createdAt);
    isRecurring = LWWRegister(recurring, createdAt);
    automationSettings = LWWRegister(automation, createdAt);
  }

  /// Update invoice status with workflow tracking
  void updateStatus(
    InvoiceStatus newStatus,
    HLCTimestamp timestamp, {
    String? reason,
    String? triggeredBy,
    Map<String, dynamic>? context,
  }) {
    final oldStatus = status.value;
    status.setValue(newStatus, timestamp);

    // Update related timestamps based on status
    switch (newStatus) {
      case InvoiceStatus.sent:
        if (sentDate.value == null) {
          sentDate.setValue(
              DateTime.fromMillisecondsSinceEpoch(timestamp.physicalTime),
              timestamp);
        }
        break;
      case InvoiceStatus.viewed:
        if (viewedDate.value == null) {
          viewedDate.setValue(
              DateTime.fromMillisecondsSinceEpoch(timestamp.physicalTime),
              timestamp);
        }
        break;
      case InvoiceStatus.paid:
        if (paidAt.value == null) {
          paidAt.setValue(
              DateTime.fromMillisecondsSinceEpoch(timestamp.physicalTime),
              timestamp);
        }
        break;
      case InvoiceStatus.disputed:
        if (!isDisputed.value) {
          isDisputed.setValue(true, timestamp);
          disputeDate.setValue(
              DateTime.fromMillisecondsSinceEpoch(timestamp.physicalTime),
              timestamp);
          if (reason != null) {
            disputeReason.setValue(reason, timestamp);
          }
        }
        break;
      default:
        break;
    }

    _updateTimestamp(timestamp);
  }

  /// Calculate due date based on payment terms
  DateTime? calculateDueDate() {
    final issue = issueDate.value;
    final terms = paymentTerms.value;

    if (terms == PaymentTerm.dueOnReceipt) {
      return issue;
    } else if (terms == PaymentTerm.custom) {
      return dueDate.value;
    } else {
      return issue.add(Duration(days: terms.days));
    }
  }

  /// Check if invoice is overdue
  bool get isOverdue {
    final due = calculateDueDate();
    if (due == null) return false;

    final now = DateTime.now();
    final currentStatus = status.value;

    return now.isAfter(due) &&
        currentStatus != InvoiceStatus.paid &&
        currentStatus != InvoiceStatus.cancelled &&
        currentStatus != InvoiceStatus.voided;
  }

  /// Get remaining balance in minor currency units (cents)
  int get remainingBalanceCents {
    final totalCents = (totalAmount.value * 100).round();
    return totalCents - paymentsReceived.value;
  }

  /// Get remaining balance as decimal amount
  double get remainingBalance {
    return remainingBalanceCents / 100.0;
  }

  /// Check if invoice is fully paid
  bool get isFullyPaid => remainingBalanceCents <= 0;

  /// Check if invoice is partially paid
  bool get isPartiallyPaid =>
      paymentsReceived.value > 0 && remainingBalanceCents > 0;

  /// Record payment
  void recordPayment(double amount, HLCTimestamp timestamp) {
    final amountCents = (amount * 100).round();
    paymentsReceived.increment(amountCents);
    lastPaymentDate.setValue(
        DateTime.fromMillisecondsSinceEpoch(timestamp.physicalTime), timestamp);

    // Update status based on payment
    if (isFullyPaid) {
      updateStatus(InvoiceStatus.paid, timestamp,
          reason: 'Full payment received');
    } else if (isPartiallyPaid && status.value != InvoiceStatus.partiallyPaid) {
      updateStatus(InvoiceStatus.partiallyPaid, timestamp,
          reason: 'Partial payment received');
    }

    _updateTimestamp(timestamp);
  }

  /// Reverse payment
  void reversePayment(double amount, HLCTimestamp timestamp) {
    final amountCents = (amount * 100).round();
    paymentsReceived.decrement(amountCents);

    // Update status if necessary
    if (status.value == InvoiceStatus.paid && !isFullyPaid) {
      if (isPartiallyPaid) {
        updateStatus(InvoiceStatus.partiallyPaid, timestamp,
            reason: 'Payment reversed');
      } else {
        updateStatus(InvoiceStatus.sent, timestamp,
            reason: 'Payment fully reversed');
      }
    }

    _updateTimestamp(timestamp);
  }

  /// Update financial totals
  void updateTotals({
    double? newSubtotal,
    double? newTaxAmount,
    double? newDiscountAmount,
    double? newShippingAmount,
    double? newTotalAmount,
    required HLCTimestamp timestamp,
  }) {
    if (newSubtotal != null) subtotal.setValue(newSubtotal, timestamp);
    if (newTaxAmount != null) taxAmount.setValue(newTaxAmount, timestamp);
    if (newDiscountAmount != null)
      discountAmount.setValue(newDiscountAmount, timestamp);
    if (newShippingAmount != null)
      shippingAmount.setValue(newShippingAmount, timestamp);
    if (newTotalAmount != null) totalAmount.setValue(newTotalAmount, timestamp);

    _updateTimestamp(timestamp);
  }

  /// Add line item
  void addItem(String itemId) {
    itemIds.add(itemId);
  }

  /// Remove line item
  void removeItem(String itemId) {
    itemIds.remove(itemId);
  }

  /// Add payment reference
  void addPayment(String paymentId) {
    paymentIds.add(paymentId);
  }

  /// Add workflow entry
  void addWorkflowEntry(String entryId) {
    workflowEntryIds.add(entryId);
  }

  /// Add tag
  void addTag(String tag) {
    tags.add(tag);
  }

  /// Remove tag
  void removeTag(String tag) {
    tags.remove(tag);
  }

  /// Send reminder
  void sendReminder(HLCTimestamp timestamp) {
    lastReminderSent.setValue(
        DateTime.fromMillisecondsSinceEpoch(timestamp.physicalTime), timestamp);
    reminderCount.setValue(reminderCount.value + 1, timestamp);
    _updateTimestamp(timestamp);
  }

  /// Mark as disputed
  void markDisputed(String reason, HLCTimestamp timestamp) {
    isDisputed.setValue(true, timestamp);
    disputeReason.setValue(reason, timestamp);
    disputeDate.setValue(
        DateTime.fromMillisecondsSinceEpoch(timestamp.physicalTime), timestamp);
    updateStatus(InvoiceStatus.disputed, timestamp, reason: reason);
  }

  /// Apply adjustment
  void applyAdjustment(double amount, String reason, HLCTimestamp timestamp) {
    adjustmentAmount.setValue(amount, timestamp);
    adjustmentReason.setValue(reason, timestamp);

    // Update total amount
    final newTotal = totalAmount.value + amount;
    totalAmount.setValue(newTotal, timestamp);

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
    if (other is! CRDTInvoiceEnhanced || other.id != id) {
      throw ArgumentError('Cannot merge with different invoice');
    }

    // Merge all LWW-Registers
    invoiceNumber.mergeWith(other.invoiceNumber);
    customerId.mergeWith(other.customerId);
    customerName.mergeWith(other.customerName);
    customerEmail.mergeWith(other.customerEmail);
    billingAddress.mergeWith(other.billingAddress);
    shippingAddress.mergeWith(other.shippingAddress);

    issueDate.mergeWith(other.issueDate);
    dueDate.mergeWith(other.dueDate);
    paymentTerms.mergeWith(other.paymentTerms);
    poNumber.mergeWith(other.poNumber);
    reference.mergeWith(other.reference);

    status.mergeWith(other.status);
    sentDate.mergeWith(other.sentDate);
    viewedDate.mergeWith(other.viewedDate);
    lastPaymentDate.mergeWith(other.lastPaymentDate);

    subtotal.mergeWith(other.subtotal);
    taxAmount.mergeWith(other.taxAmount);
    discountAmount.mergeWith(other.discountAmount);
    shippingAmount.mergeWith(other.shippingAmount);
    totalAmount.mergeWith(other.totalAmount);
    currency.mergeWith(other.currency);
    exchangeRate.mergeWith(other.exchangeRate);

    paymentsReceived.mergeWith(other.paymentsReceived);
    lastReminderSent.mergeWith(other.lastReminderSent);
    reminderCount.mergeWith(other.reminderCount);

    notes.mergeWith(other.notes);
    termsAndConditions.mergeWith(other.termsAndConditions);
    footerText.mergeWith(other.footerText);
    customFields.mergeWith(other.customFields);

    pdfUrl.mergeWith(other.pdfUrl);
    pdfHash.mergeWith(other.pdfHash);
    lastPdfGenerated.mergeWith(other.lastPdfGenerated);

    // Merge OR-Sets
    itemIds.mergeWith(other.itemIds);
    paymentIds.mergeWith(other.paymentIds);
    workflowEntryIds.mergeWith(other.workflowEntryIds);
    attachmentIds.mergeWith(other.attachmentIds);
    tags.mergeWith(other.tags);

    isDisputed.mergeWith(other.isDisputed);
    disputeReason.mergeWith(other.disputeReason);
    disputeDate.mergeWith(other.disputeDate);
    adjustmentAmount.mergeWith(other.adjustmentAmount);
    adjustmentReason.mergeWith(other.adjustmentReason);

    autoReminders.mergeWith(other.autoReminders);
    reminderDaysBefore.mergeWith(other.reminderDaysBefore);
    autoFollowUp.mergeWith(other.autoFollowUp);
    automationSettings.mergeWith(other.automationSettings);

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
      'invoice_number': invoiceNumber.value,
      'customer_id': customerId.value,
      'customer_name': customerName.value ?? '',
      'customer_email': customerEmail.value ?? '',
      'billing_address': billingAddress.value ?? '',
      'shipping_address': shippingAddress.value ?? '',
      'issue_date': issueDate.value.millisecondsSinceEpoch,
      'due_date': dueDate.value?.millisecondsSinceEpoch,
      'calculated_due_date': calculateDueDate()?.millisecondsSinceEpoch,
      'payment_terms': paymentTerms.value.value,
      'po_number': poNumber.value ?? '',
      'reference': reference.value ?? '',
      'status': status.value.value,
      'sent_date': sentDate.value?.millisecondsSinceEpoch,
      'viewed_date': viewedDate.value?.millisecondsSinceEpoch,
      'last_payment_date': lastPaymentDate.value?.millisecondsSinceEpoch,
      'subtotal': subtotal.value,
      'tax_amount': taxAmount.value,
      'discount_amount': discountAmount.value,
      'shipping_amount': shippingAmount.value,
      'total_amount': totalAmount.value,
      'currency': currency.value,
      'exchange_rate': exchangeRate.value,
      'payments_received_cents': paymentsReceived.value,
      'remaining_balance_cents': remainingBalanceCents,
      'remaining_balance': remainingBalance,
      'is_fully_paid': isFullyPaid,
      'is_partially_paid': isPartiallyPaid,
      'is_overdue': isOverdue,
      'last_reminder_sent': lastReminderSent.value?.millisecondsSinceEpoch,
      'reminder_count': reminderCount.value,
      'notes': notes.value ?? '',
      'terms_and_conditions': termsAndConditions.value ?? '',
      'footer_text': footerText.value ?? '',
      'custom_fields': customFields.value,
      'pdf_url': pdfUrl.value ?? '',
      'pdf_hash': pdfHash.value ?? '',
      'last_pdf_generated': lastPdfGenerated.value?.millisecondsSinceEpoch,
      'item_ids': itemIds.elements.toList(),
      'payment_ids': paymentIds.elements.toList(),
      'workflow_entry_ids': workflowEntryIds.elements.toList(),
      'attachment_ids': attachmentIds.elements.toList(),
      'tags': tags.elements.toList(),
      'is_disputed': isDisputed.value,
      'dispute_reason': disputeReason.value ?? '',
      'dispute_date': disputeDate.value?.millisecondsSinceEpoch,
      'adjustment_amount': adjustmentAmount.value,
      'adjustment_reason': adjustmentReason.value ?? '',
      'auto_reminders': autoReminders.value,
      'reminder_days_before': reminderDaysBefore.value,
      'auto_follow_up': autoFollowUp.value,
      'automation_settings': automationSettings.value,
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
      'invoice_number': invoiceNumber.toJson(),
      'customer_id': customerId.toJson(),
      'customer_name': customerName.toJson(),
      'customer_email': customerEmail.toJson(),
      'billing_address': billingAddress.toJson(),
      'shipping_address': shippingAddress.toJson(),
      'issue_date': issueDate.toJson(),
      'due_date': dueDate.toJson(),
      'payment_terms': paymentTerms.toJson(),
      'po_number': poNumber.toJson(),
      'reference': reference.toJson(),
      'status': status.toJson(),
      'sent_date': sentDate.toJson(),
      'viewed_date': viewedDate.toJson(),
      'last_payment_date': lastPaymentDate.toJson(),
      'subtotal': subtotal.toJson(),
      'tax_amount': taxAmount.toJson(),
      'discount_amount': discountAmount.toJson(),
      'shipping_amount': shippingAmount.toJson(),
      'total_amount': totalAmount.toJson(),
      'currency': currency.toJson(),
      'exchange_rate': exchangeRate.toJson(),
      'payments_received': paymentsReceived.toJson(),
      'last_reminder_sent': lastReminderSent.toJson(),
      'reminder_count': reminderCount.toJson(),
      'notes': notes.toJson(),
      'terms_and_conditions': termsAndConditions.toJson(),
      'footer_text': footerText.toJson(),
      'custom_fields': customFields.toJson(),
      'pdf_url': pdfUrl.toJson(),
      'pdf_hash': pdfHash.toJson(),
      'last_pdf_generated': lastPdfGenerated.toJson(),
      'item_ids': itemIds.toJson(),
      'payment_ids': paymentIds.toJson(),
      'workflow_entry_ids': workflowEntryIds.toJson(),
      'attachment_ids': attachmentIds.toJson(),
      'tags': tags.toJson(),
      'is_disputed': isDisputed.toJson(),
      'dispute_reason': disputeReason.toJson(),
      'dispute_date': disputeDate.toJson(),
      'adjustment_amount': adjustmentAmount.toJson(),
      'adjustment_reason': adjustmentReason.toJson(),
      'auto_reminders': autoReminders.toJson(),
      'reminder_days_before': reminderDaysBefore.toJson(),
      'auto_follow_up': autoFollowUp.toJson(),
      'automation_settings': automationSettings.toJson(),
    };
  }
}
