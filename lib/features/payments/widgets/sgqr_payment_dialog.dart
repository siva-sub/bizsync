import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/paynow_sgqr_service.dart';
import '../../invoices/services/invoice_sgqr_service.dart';

/// Dialog for displaying SGQR payment QR codes
class SGQRPaymentDialog extends StatefulWidget {
  final dynamic invoice;
  final String? merchantUEN;
  final String? merchantMobile;
  final String? customMessage;

  const SGQRPaymentDialog({
    super.key,
    required this.invoice,
    this.merchantUEN,
    this.merchantMobile,
    this.customMessage,
  });

  @override
  State<SGQRPaymentDialog> createState() => _SGQRPaymentDialogState();
}

class _SGQRPaymentDialogState extends State<SGQRPaymentDialog> {
  String? _qrString;
  bool _isLoading = true;
  String? _error;
  bool _canGenerateQR = false;

  @override
  void initState() {
    super.initState();
    _generateQRCode();
  }

  Future<void> _generateQRCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check if we can generate QR for this invoice
      _canGenerateQR = InvoiceSGQRService.canGenerateSGQR(widget.invoice);

      if (!_canGenerateQR) {
        setState(() {
          _error =
              'Cannot generate PayNow QR for this invoice. Only SGD invoices with outstanding balance are supported.';
          _isLoading = false;
        });
        return;
      }

      final qrString = await InvoiceSGQRService.generateInvoiceSGQR(
        invoice: widget.invoice,
        customMessage: widget.customMessage,
        merchantUEN: widget.merchantUEN ?? '202012345A', // Default demo UEN
        merchantMobile: widget.merchantMobile,
      );

      setState(() {
        _qrString = qrString;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to generate PayNow QR: $e';
        _isLoading = false;
      });
    }
  }

  void _copyQRString() {
    if (_qrString != null) {
      Clipboard.setData(ClipboardData(text: _qrString!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code string copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _shareQRCode() {
    // TODO: Implement sharing functionality
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality not yet implemented'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// Helper methods to extract invoice data
  String _getInvoiceNumber(dynamic invoice) {
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

  double _getInvoiceAmount(dynamic invoice) {
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

  String _getInvoiceCurrency(dynamic invoice) {
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

  @override
  Widget build(BuildContext context) {
    final invoiceNumber = _getInvoiceNumber(widget.invoice);
    final amount = _getInvoiceAmount(widget.invoice);
    final currency = _getInvoiceCurrency(widget.invoice);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.qr_code, size: 28, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PayNow Payment',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Invoice: $invoiceNumber',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Amount display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '$currency ${amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // QR Code or loading/error state
            SizedBox(
              height: 280,
              child: _buildQRContent(),
            ),
            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Payment Instructions',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Open your banking app or any PayNow-enabled app\n'
                    '2. Scan the QR code above\n'
                    '3. Verify the payment amount and details\n'
                    '4. Complete the payment',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            if (_qrString != null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyQRString,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy QR String'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareQRCode,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share QR'),
                    ),
                  ),
                ],
              ),
            ] else if (_error != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generateQRCode,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQRContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating PayNow QR code...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_qrString != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: QrImageView(
            data: _qrString!,
            version: QrVersions.auto,
            size: 240,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
      );
    }

    return const Center(
      child: Text('No QR code generated'),
    );
  }
}

/// Utility function to show the SGQR payment dialog
Future<void> showSGQRPaymentDialog({
  required BuildContext context,
  required dynamic invoice,
  String? merchantUEN,
  String? merchantMobile,
  String? customMessage,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return SGQRPaymentDialog(
        invoice: invoice,
        merchantUEN: merchantUEN,
        merchantMobile: merchantMobile,
        customMessage: customMessage,
      );
    },
  );
}
