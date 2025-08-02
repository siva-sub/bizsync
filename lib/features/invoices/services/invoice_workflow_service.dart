import '../../../core/crdt/hybrid_logical_clock.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';

/// Invoice workflow transition result
class WorkflowTransitionResult {
  final bool success;
  final String? errorMessage;
  final InvoiceStatus? fromStatus;
  final InvoiceStatus? toStatus;
  final Map<String, dynamic>? context;

  const WorkflowTransitionResult({
    required this.success,
    this.errorMessage,
    this.fromStatus,
    this.toStatus,
    this.context,
  });

  factory WorkflowTransitionResult.success({
    required InvoiceStatus fromStatus,
    required InvoiceStatus toStatus,
    Map<String, dynamic>? context,
  }) {
    return WorkflowTransitionResult(
      success: true,
      fromStatus: fromStatus,
      toStatus: toStatus,
      context: context,
    );
  }

  factory WorkflowTransitionResult.failure(String errorMessage) {
    return WorkflowTransitionResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

/// Invoice workflow validation rules
class InvoiceWorkflowValidator {
  
  /// Check if a status transition is valid
  static bool isValidTransition(InvoiceStatus from, InvoiceStatus to) {
    switch (from) {
      case InvoiceStatus.draft:
        return [
          InvoiceStatus.pending,
          InvoiceStatus.approved,
          InvoiceStatus.sent,
          InvoiceStatus.cancelled,
          InvoiceStatus.voided,
        ].contains(to);

      case InvoiceStatus.pending:
        return [
          InvoiceStatus.draft,
          InvoiceStatus.approved,
          InvoiceStatus.cancelled,
          InvoiceStatus.voided,
        ].contains(to);

      case InvoiceStatus.approved:
        return [
          InvoiceStatus.draft,
          InvoiceStatus.sent,
          InvoiceStatus.cancelled,
          InvoiceStatus.voided,
        ].contains(to);

      case InvoiceStatus.sent:
        return [
          InvoiceStatus.viewed,
          InvoiceStatus.partiallyPaid,
          InvoiceStatus.paid,
          InvoiceStatus.overdue,
          InvoiceStatus.disputed,
          InvoiceStatus.cancelled,
          InvoiceStatus.voided,
        ].contains(to);

      case InvoiceStatus.viewed:
        return [
          InvoiceStatus.partiallyPaid,
          InvoiceStatus.paid,
          InvoiceStatus.overdue,
          InvoiceStatus.disputed,
          InvoiceStatus.cancelled,
          InvoiceStatus.voided,
        ].contains(to);

      case InvoiceStatus.partiallyPaid:
        return [
          InvoiceStatus.paid,
          InvoiceStatus.overdue,
          InvoiceStatus.disputed,
          InvoiceStatus.voided,
        ].contains(to);

      case InvoiceStatus.paid:
        return [
          InvoiceStatus.partiallyPaid, // For payment reversals
          InvoiceStatus.sent, // For full payment reversal
          InvoiceStatus.disputed,
          InvoiceStatus.voided,
        ].contains(to);

      case InvoiceStatus.overdue:
        return [
          InvoiceStatus.partiallyPaid,
          InvoiceStatus.paid,
          InvoiceStatus.disputed,
          InvoiceStatus.cancelled,
          InvoiceStatus.voided,
        ].contains(to);

      case InvoiceStatus.disputed:
        return [
          InvoiceStatus.sent,
          InvoiceStatus.partiallyPaid,
          InvoiceStatus.paid,
          InvoiceStatus.overdue,
          InvoiceStatus.cancelled,
          InvoiceStatus.voided,
        ].contains(to);

      case InvoiceStatus.cancelled:
        return [
          InvoiceStatus.draft, // Allow reactivation
          InvoiceStatus.voided,
        ].contains(to);

      case InvoiceStatus.voided:
        return false; // No transitions from voided state
      
      case InvoiceStatus.refunded:
        return false; // No transitions from refunded state
    }
  }

  /// Validate invoice data for specific transitions
  static String? validateTransitionData(
    CRDTInvoiceEnhanced invoice,
    InvoiceStatus to,
  ) {
    switch (to) {
      case InvoiceStatus.sent:
        if (invoice.customerId.value == null || invoice.customerId.value!.isEmpty) {
          return 'Customer is required to send invoice';
        }
        if (invoice.itemIds.elements.isEmpty) {
          return 'At least one line item is required to send invoice';
        }
        if (invoice.totalAmount.value <= 0) {
          return 'Invoice total must be greater than zero to send';
        }
        break;

      case InvoiceStatus.approved:
        if (invoice.itemIds.elements.isEmpty) {
          return 'At least one line item is required for approval';
        }
        if (invoice.totalAmount.value <= 0) {
          return 'Invoice total must be greater than zero for approval';
        }
        break;

      case InvoiceStatus.paid:
        if (!invoice.isFullyPaid) {
          return 'Invoice must be fully paid to mark as paid';
        }
        break;

      case InvoiceStatus.partiallyPaid:
        if (!invoice.isPartiallyPaid) {
          return 'Invoice must have partial payments to mark as partially paid';
        }
        break;

      default:
        break;
    }

    return null; // No validation errors
  }

  /// Get required fields for a specific status
  static List<String> getRequiredFields(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.sent:
        return ['customer_id', 'invoice_number', 'issue_date', 'total_amount'];
      case InvoiceStatus.approved:
        return ['invoice_number', 'issue_date', 'total_amount'];
      case InvoiceStatus.paid:
        return ['customer_id', 'invoice_number', 'total_amount'];
      default:
        return ['invoice_number'];
    }
  }
}

/// Invoice workflow automation rules
class InvoiceWorkflowAutomation {
  
  /// Check if invoice should be automatically marked as overdue
  static bool shouldMarkOverdue(CRDTInvoiceEnhanced invoice) {
    final status = invoice.status.value;
    if (status == InvoiceStatus.paid || 
        status == InvoiceStatus.cancelled || 
        status == InvoiceStatus.voided) {
      return false;
    }

    return invoice.isOverdue;
  }

  /// Check if reminder should be sent
  static bool shouldSendReminder(CRDTInvoiceEnhanced invoice) {
    if (!invoice.autoReminders.value) return false;
    
    final dueDate = invoice.calculateDueDate();
    if (dueDate == null) return false;
    
    final reminderDays = invoice.reminderDaysBefore.value ?? 3;
    final reminderDate = dueDate.subtract(Duration(days: reminderDays));
    final now = DateTime.now();
    
    final lastReminder = invoice.lastReminderSent.value;
    final daysSinceLastReminder = lastReminder != null 
        ? now.difference(lastReminder).inDays 
        : 999;
    
    return now.isAfter(reminderDate) && 
           daysSinceLastReminder >= 1 && // Don't spam daily
           invoice.status.value != InvoiceStatus.paid &&
           invoice.status.value != InvoiceStatus.cancelled &&
           invoice.status.value != InvoiceStatus.voided;
  }

  /// Get automated follow-up actions for a status
  static List<String> getAutomatedActions(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.sent:
        return ['schedule_reminder', 'track_delivery'];
      case InvoiceStatus.viewed:
        return ['schedule_follow_up'];
      case InvoiceStatus.overdue:
        return ['send_overdue_notice', 'escalate_collection'];
      case InvoiceStatus.partiallyPaid:
        return ['send_balance_reminder'];
      default:
        return [];
    }
  }
}

/// Main invoice workflow service
class InvoiceWorkflowService {
  final String _nodeId = 'default-node';
  
  InvoiceWorkflowService();

  /// Attempt to transition invoice to new status
  Future<WorkflowTransitionResult> transitionStatus(
    CRDTInvoiceEnhanced invoice,
    InvoiceStatus newStatus, {
    String? reason,
    String? triggeredBy,
    Map<String, dynamic>? context,
    bool skipValidation = false,
  }) async {
    final currentStatus = invoice.status.value;
    
    // Check if transition is valid
    if (!skipValidation && !InvoiceWorkflowValidator.isValidTransition(currentStatus, newStatus)) {
      return WorkflowTransitionResult.failure(
        'Invalid transition from ${currentStatus.value} to ${newStatus.value}',
      );
    }

    // Validate invoice data for this transition
    if (!skipValidation) {
      final validationError = InvoiceWorkflowValidator.validateTransitionData(invoice, newStatus);
      if (validationError != null) {
        return WorkflowTransitionResult.failure(validationError);
      }
    }

    // Perform the transition
    final timestamp = HLCTimestamp.now(_nodeId);
    invoice.updateStatus(
      newStatus,
      timestamp,
      reason: reason,
      triggeredBy: triggeredBy,
      context: context,
    );

    // Schedule automated actions
    await _scheduleAutomatedActions(invoice, newStatus, context);

    return WorkflowTransitionResult.success(
      fromStatus: currentStatus,
      toStatus: newStatus,
      context: context,
    );
  }

  /// Check and apply automated status changes
  Future<List<WorkflowTransitionResult>> processAutomatedTransitions(
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    final results = <WorkflowTransitionResult>[];

    for (final invoice in invoices) {
      // Check for overdue transition
      if (InvoiceWorkflowAutomation.shouldMarkOverdue(invoice)) {
        final result = await transitionStatus(
          invoice,
          InvoiceStatus.overdue,
          reason: 'Automatic overdue detection',
          triggeredBy: 'system',
          context: {'automated': true, 'overdue_date': DateTime.now().toIso8601String()},
          skipValidation: true,
        );
        results.add(result);
      }

      // Check for reminder scheduling
      if (InvoiceWorkflowAutomation.shouldSendReminder(invoice)) {
        // This would trigger reminder service, not a status change
        await _scheduleReminder(invoice);
      }
    }

    return results;
  }

  /// Get available transitions for an invoice
  List<InvoiceStatus> getAvailableTransitions(CRDTInvoiceEnhanced invoice) {
    final currentStatus = invoice.status.value;
    final allStatuses = InvoiceStatus.values;
    
    return allStatuses.where((status) {
      if (status == currentStatus) return false;
      return InvoiceWorkflowValidator.isValidTransition(currentStatus, status);
    }).toList();
  }

  /// Get workflow history for an invoice
  Future<List<Map<String, dynamic>>> getWorkflowHistory(String invoiceId) async {
    // This would typically query the workflow entries from the database
    // For now, return empty list - implementation would depend on repository
    return [];
  }

  /// Validate invoice can be transitioned to status
  String? validateTransition(CRDTInvoiceEnhanced invoice, InvoiceStatus newStatus) {
    final currentStatus = invoice.status.value;
    
    if (!InvoiceWorkflowValidator.isValidTransition(currentStatus, newStatus)) {
      return 'Cannot transition from ${currentStatus.value} to ${newStatus.value}';
    }

    return InvoiceWorkflowValidator.validateTransitionData(invoice, newStatus);
  }

  /// Force status change (bypass validation)
  Future<WorkflowTransitionResult> forceStatusChange(
    CRDTInvoiceEnhanced invoice,
    InvoiceStatus newStatus, {
    String reason = 'Forced status change',
    String? triggeredBy,
    Map<String, dynamic>? context,
  }) async {
    return transitionStatus(
      invoice,
      newStatus,
      reason: reason,
      triggeredBy: triggeredBy,
      context: context,
      skipValidation: true,
    );
  }

  /// Schedule automated actions based on status
  Future<void> _scheduleAutomatedActions(
    CRDTInvoiceEnhanced invoice,
    InvoiceStatus status,
    Map<String, dynamic>? context,
  ) async {
    final actions = InvoiceWorkflowAutomation.getAutomatedActions(status);
    
    for (final action in actions) {
      switch (action) {
        case 'schedule_reminder':
          await _scheduleReminder(invoice);
          break;
        case 'track_delivery':
          await _trackDelivery(invoice);
          break;
        case 'schedule_follow_up':
          await _scheduleFollowUp(invoice);
          break;
        case 'send_overdue_notice':
          await _sendOverdueNotice(invoice);
          break;
        case 'escalate_collection':
          await _escalateCollection(invoice);
          break;
        case 'send_balance_reminder':
          await _sendBalanceReminder(invoice);
          break;
      }
    }
  }

  /// Schedule reminder for invoice
  Future<void> _scheduleReminder(CRDTInvoiceEnhanced invoice) async {
    // Implementation would schedule reminder in notification service
    print('Scheduling reminder for invoice ${invoice.invoiceNumber.value}');
  }

  /// Track invoice delivery
  Future<void> _trackDelivery(CRDTInvoiceEnhanced invoice) async {
    // Implementation would set up delivery tracking
    print('Setting up delivery tracking for invoice ${invoice.invoiceNumber.value}');
  }

  /// Schedule follow-up for viewed invoice
  Future<void> _scheduleFollowUp(CRDTInvoiceEnhanced invoice) async {
    // Implementation would schedule follow-up communication
    print('Scheduling follow-up for invoice ${invoice.invoiceNumber.value}');
  }

  /// Send overdue notice
  Future<void> _sendOverdueNotice(CRDTInvoiceEnhanced invoice) async {
    // Implementation would send overdue notification
    print('Sending overdue notice for invoice ${invoice.invoiceNumber.value}');
  }

  /// Escalate collection process
  Future<void> _escalateCollection(CRDTInvoiceEnhanced invoice) async {
    // Implementation would escalate to collection team
    print('Escalating collection for invoice ${invoice.invoiceNumber.value}');
  }

  /// Send balance reminder for partially paid invoice
  Future<void> _sendBalanceReminder(CRDTInvoiceEnhanced invoice) async {
    // Implementation would send balance reminder
    print('Sending balance reminder for invoice ${invoice.invoiceNumber.value}');
  }

  /// Get workflow statistics
  Map<String, dynamic> getWorkflowStatistics(List<CRDTInvoiceEnhanced> invoices) {
    final statusCounts = <String, int>{};
    final overdueCount = invoices.where((i) => i.isOverdue).length;
    final disputedCount = invoices.where((i) => i.isDisputed.value).length;
    final partiallyPaidCount = invoices.where((i) => i.isPartiallyPaid).length;
    final totalPaid = invoices
        .where((i) => i.status.value == InvoiceStatus.paid)
        .fold(0.0, (sum, i) => sum + i.totalAmount.value);

    for (final invoice in invoices) {
      final status = invoice.status.value.value;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return {
      'total_invoices': invoices.length,
      'status_breakdown': statusCounts,
      'overdue_count': overdueCount,
      'disputed_count': disputedCount,
      'partially_paid_count': partiallyPaidCount,
      'total_paid_amount': totalPaid,
      'average_invoice_value': invoices.isEmpty 
          ? 0.0 
          : invoices.fold(0.0, (sum, i) => sum + i.totalAmount.value) / invoices.length,
    };
  }
}