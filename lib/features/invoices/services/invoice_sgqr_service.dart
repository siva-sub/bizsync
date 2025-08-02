import '../models/enhanced_invoice_model.dart';
import '../../payments/services/paynow_sgqr_service.dart';

/// Service for generating SGQR codes for invoice payments
class InvoiceSGQRService {
  /// Generate SGQR code for invoice payment
  static Future<String> generateInvoiceSGQR({
    required dynamic invoice, // Using dynamic to support different invoice types
    String? customMessage,
    String? merchantUEN,
    String? merchantMobile,
  }) async {
    try {
      // Extract invoice data (supporting both enhanced and simple invoice models)
      final double amount = _getInvoiceAmount(invoice);
      final String invoiceNumber = _getInvoiceNumber(invoice);
      final String currency = _getInvoiceCurrency(invoice);
      
      final result = await PayNowService.generateSGQR(
        amount: amount,
        currency: currency,
        merchantName: 'BizSync Invoice Payment',
        merchantUEN: merchantUEN,
        merchantMobile: merchantMobile,
        reference: invoiceNumber,
        description: customMessage ?? 'Payment for Invoice $invoiceNumber',
        expiryMinutes: 60, // 1 hour expiry
      );
      
      if (result.isSuccess && result.qrString != null) {
        return result.qrString!;
      } else {
        throw Exception(result.errorMessage ?? 'Failed to generate SGQR');
      }
    } catch (e) {
      throw Exception('SGQR generation failed: $e');
    }
  }
  
  /// Generate SGQR with custom amount (for partial payments)
  static Future<String> generatePartialPaymentSGQR({
    required dynamic invoice,
    required double amount,
    String? customMessage,
    String? merchantUEN,
    String? merchantMobile,
  }) async {
    try {
      if (amount <= 0) {
        throw Exception('Payment amount must be greater than 0');
      }
      
      final String invoiceNumber = _getInvoiceNumber(invoice);
      final String currency = _getInvoiceCurrency(invoice);
      
      final result = await PayNowService.generateSGQR(
        amount: amount,
        currency: currency,
        merchantName: 'BizSync Invoice Payment',
        merchantUEN: merchantUEN,
        merchantMobile: merchantMobile,
        reference: '$invoiceNumber-PARTIAL',
        description: customMessage ?? 'Partial payment for Invoice $invoiceNumber',
        expiryMinutes: 60,
      );
      
      if (result.isSuccess && result.qrString != null) {
        return result.qrString!;
      } else {
        throw Exception(result.errorMessage ?? 'Failed to generate SGQR');
      }
    } catch (e) {
      throw Exception('SGQR generation failed: $e');
    }
  }
  
  /// Check if invoice is eligible for SGQR generation
  static bool canGenerateSGQR(dynamic invoice) {
    if (invoice == null) return false;
    
    // Check if invoice has remaining balance
    final amount = _getInvoiceAmount(invoice);
    if (amount <= 0) {
      return false;
    }
    
    // Check if currency is supported (SGD for PayNow)
    final currency = _getInvoiceCurrency(invoice);
    if (currency != 'SGD') {
      return false;
    }
    
    return true;
  }
  
  /// Get payment instructions for the invoice
  static Map<String, dynamic> getPaymentInstructions(dynamic invoice) {
    final String invoiceNumber = _getInvoiceNumber(invoice);
    final double amount = _getInvoiceAmount(invoice);
    final String currency = _getInvoiceCurrency(invoice);
    
    return {
      'invoice_number': invoiceNumber,
      'total_amount': amount,
      'remaining_balance': amount,
      'currency': currency,
      'payment_methods': [
        {
          'method': 'paynow',
          'name': 'PayNow QR',
          'description': 'Scan QR code with your banking app',
          'supported': currency == 'SGD',
        },
        {
          'method': 'bank_transfer',
          'name': 'Bank Transfer',
          'description': 'Transfer to our bank account',
          'supported': true,
        },
        {
          'method': 'cheque',
          'name': 'Cheque',
          'description': 'Send cheque to our office address',
          'supported': true,
        },
      ],
      'instructions': [
        'Please include invoice number $invoiceNumber in payment reference',
        'Payment must be made in $currency',
        'Contact us if you have any questions about this invoice',
      ],
    };
  }
  
  /// Extract amount from invoice
  static double _getInvoiceAmount(dynamic invoice) {
    if (invoice == null) return 0.0;
    
    try {
      // Try different property names for amount
      if (invoice['remaining_balance_cents'] != null) {
        return (invoice['remaining_balance_cents'] as int) / 100.0;
      } else if (invoice['total_amount'] != null) {
        return invoice['total_amount'] as double;
      } else if (invoice.remainingBalance != null) {
        return invoice.remainingBalance as double;
      } else if (invoice.totalAmount != null) {
        if (invoice.totalAmount.value != null) {
          return invoice.totalAmount.value as double;
        } else {
          return invoice.totalAmount as double;
        }
      } else if (invoice.total != null) {
        return invoice.total as double;
      }
    } catch (e) {
      // Ignore errors and try next approach
    }
    
    return 0.0;
  }
  
  /// Extract invoice number from invoice
  static String _getInvoiceNumber(dynamic invoice) {
    if (invoice == null) return 'INV-0000';
    
    try {
      // Try different property names for invoice number
      if (invoice['invoice_number'] != null) {
        return invoice['invoice_number'] as String;
      } else if (invoice.invoiceNumber != null) {
        if (invoice.invoiceNumber.value != null) {
          return invoice.invoiceNumber.value as String;
        } else {
          return invoice.invoiceNumber as String;
        }
      } else if (invoice.number != null) {
        return invoice.number as String;
      } else if (invoice.id != null) {
        return 'INV-${invoice.id}';
      } else if (invoice['id'] != null) {
        return 'INV-${invoice['id']}';
      }
    } catch (e) {
      // Ignore errors and try next approach
    }
    
    return 'INV-0000';
  }
  
  /// Extract currency from invoice
  static String _getInvoiceCurrency(dynamic invoice) {
    if (invoice == null) return 'SGD';
    
    try {
      // Try different property names for currency
      if (invoice.currency != null) {
        if (invoice.currency.value != null) {
          return invoice.currency.value as String;
        } else {
          return invoice.currency as String;
        }
      } else if (invoice['currency'] != null) {
        return invoice['currency'] as String;
      }
    } catch (e) {
      // Ignore errors and use default
    }
    
    return 'SGD'; // Default to SGD
  }
}