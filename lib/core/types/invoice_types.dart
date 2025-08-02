/// Core invoice types used throughout the application
/// This file provides type aliases and unified enums to fix import issues

// Import the actual classes first
import '../../features/invoices/models/enhanced_invoice_model.dart' as enhanced;
import '../../features/invoices/models/invoice_models.dart' as crdt;

// Re-export enhanced invoice types and CRDT types FIRST
export '../../features/invoices/models/enhanced_invoice_model.dart';
export '../../features/invoices/models/invoice_models.dart' 
    show PaymentTerm, LineItemType, TaxCalculationMethod, CRDTInvoiceItem, CRDTInvoiceWorkflow, CRDTInvoicePayment;

// Type aliases for backward compatibility
typedef CRDTInvoice = enhanced.CRDTInvoiceEnhanced;

// Use the same InvoiceStatus enum from invoice_models.dart
typedef InvoiceStatus = crdt.InvoiceStatus;

/// Helper functions for status display
class InvoiceStatusHelper {
  static String getStatusDisplay(crdt.InvoiceStatus status) {
    switch (status) {
      case crdt.InvoiceStatus.draft:
        return 'Draft';
      case crdt.InvoiceStatus.pending:
        return 'Pending';
      case crdt.InvoiceStatus.approved:
        return 'Approved';
      case crdt.InvoiceStatus.sent:
        return 'Sent';
      case crdt.InvoiceStatus.viewed:
        return 'Viewed';
      case crdt.InvoiceStatus.partiallyPaid:
        return 'Partially Paid';
      case crdt.InvoiceStatus.paid:
        return 'Paid';
      case crdt.InvoiceStatus.overdue:
        return 'Overdue';
      case crdt.InvoiceStatus.cancelled:
        return 'Cancelled';
      case crdt.InvoiceStatus.disputed:
        return 'Disputed';
      case crdt.InvoiceStatus.voided:
        return 'Voided';
      case crdt.InvoiceStatus.refunded:
        return 'Refunded';
    }
  }

  static String getStatusColor(crdt.InvoiceStatus status) {
    switch (status) {
      case crdt.InvoiceStatus.draft:
        return '#9E9E9E'; // Gray
      case crdt.InvoiceStatus.pending:
        return '#FF9800'; // Orange
      case crdt.InvoiceStatus.approved:
        return '#2196F3'; // Blue
      case crdt.InvoiceStatus.sent:
        return '#03A9F4'; // Light Blue
      case crdt.InvoiceStatus.viewed:
        return '#00BCD4'; // Cyan
      case crdt.InvoiceStatus.partiallyPaid:
        return '#FFC107'; // Amber
      case crdt.InvoiceStatus.paid:
        return '#4CAF50'; // Green
      case crdt.InvoiceStatus.overdue:
        return '#F44336'; // Red
      case crdt.InvoiceStatus.cancelled:
        return '#607D8B'; // Blue Gray
      case crdt.InvoiceStatus.disputed:
        return '#9C27B0'; // Purple
      case crdt.InvoiceStatus.voided:
        return '#424242'; // Dark Gray
      case crdt.InvoiceStatus.refunded:
        return '#009688'; // Teal
    }
  }
}