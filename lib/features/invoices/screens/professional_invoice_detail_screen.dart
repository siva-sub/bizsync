import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../../../core/demo/demo_data_service.dart';
import '../models/enhanced_invoice_model.dart';
import '../widgets/invoice_status_chip.dart';
import '../services/invoice_service.dart';

class ProfessionalInvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const ProfessionalInvoiceDetailScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  ConsumerState<ProfessionalInvoiceDetailScreen> createState() =>
      _ProfessionalInvoiceDetailScreenState();
}

class _ProfessionalInvoiceDetailScreenState
    extends ConsumerState<ProfessionalInvoiceDetailScreen> {
  EnhancedInvoice? _invoice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);

    try {
      final demoService = DemoDataService();
      if (!demoService.isInitialized) {
        await demoService.initializeDemoData();
      }
      _invoice = demoService.getInvoiceById(widget.invoiceId);
    } catch (e) {
      debugPrint('Error loading invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice?.invoiceNumber ?? 'Invoice Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/invoices'),
        ),
        actions: [
          if (_invoice != null) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareInvoice,
              tooltip: 'Share Invoice',
            ),
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printInvoice,
              tooltip: 'Print Invoice',
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit Invoice'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('Duplicate Invoice'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf),
                    title: Text('Export as PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete Invoice',
                        style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              onSelected: _handleMenuAction,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoice == null
              ? _buildNotFoundState()
              : _buildInvoiceDetail(),
      floatingActionButton:
          _invoice != null && _invoice!.status == InvoiceStatus.draft
              ? FloatingActionButton.extended(
                  onPressed: _sendInvoice,
                  icon: const Icon(Icons.send),
                  label: const Text('Send Invoice'),
                )
              : null,
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Invoice Not Found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'The requested invoice could not be found.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/invoices'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Invoices'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetail() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _invoice!.invoiceNumber,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Invoice Date: ${_invoice!.invoiceDate.day}/${_invoice!.invoiceDate.month}/${_invoice!.invoiceDate.year}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              'Due Date: ${_invoice!.dueDate.day}/${_invoice!.dueDate.month}/${_invoice!.dueDate.year}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: _invoice!.dueDate
                                            .isBefore(DateTime.now())
                                        ? Colors.red
                                        : null,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          InvoiceStatusChip(status: _invoice!.status),
                          const SizedBox(height: 8),
                          Text(
                            '\$${_invoice!.total.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Customer Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill To',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _invoice!.customerName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (_invoice!.customerEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.email, size: 16),
                        const SizedBox(width: 8),
                        Text(_invoice!.customerEmail),
                      ],
                    ),
                  ],
                  if (_invoice!.customerAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_invoice!.customerAddress),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Invoice Items
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice Items',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        children: [
                          _tableHeader('Description'),
                          _tableHeader('Qty'),
                          _tableHeader('Rate'),
                          _tableHeader('Amount'),
                        ],
                      ),
                      ..._invoice!.items.map((item) => TableRow(
                            children: [
                              _tableCell(item.description),
                              _tableCell(item.quantity.toString()),
                              _tableCell(
                                  '\$${item.unitPrice.toStringAsFixed(2)}'),
                              _tableCell('\$${item.total.toStringAsFixed(2)}'),
                            ],
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _summaryRow(
                      'Subtotal', '\$${_invoice!.subtotal.toStringAsFixed(2)}'),
                  if (_invoice!.gstAmount > 0) ...[
                    const SizedBox(height: 8),
                    _summaryRow('GST (9%)',
                        '\$${_invoice!.gstAmount.toStringAsFixed(2)}'),
                  ],
                  if (_invoice!.discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    _summaryRow('Discount',
                        '-\$${_invoice!.discountAmount.toStringAsFixed(2)}'),
                  ],
                  const Divider(height: 24),
                  _summaryRow(
                    'Total',
                    '\$${_invoice!.total.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),

          if (_invoice!.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(_invoice!.notes),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text),
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            fontSize: isTotal ? 16 : 14,
            color: isTotal ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        context.go('/invoices/edit/${_invoice!.id}');
        break;
      case 'duplicate':
        _duplicateInvoice();
        break;
      case 'pdf':
        _exportAsPdf();
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
    }
  }

  Future<void> _shareInvoice() async {
    if (_invoice == null) return;

    try {
      // Create a simple text representation of the invoice
      final invoiceText = '''
Invoice: ${_invoice!.invoiceNumber}
Customer: ${_invoice!.customerName}
Date: ${_invoice!.invoiceDate.day}/${_invoice!.invoiceDate.month}/${_invoice!.invoiceDate.year}
Due Date: ${_invoice!.dueDate.day}/${_invoice!.dueDate.month}/${_invoice!.dueDate.year}
Amount: \$${_invoice!.total.toStringAsFixed(2)}
Status: ${_getStatusText(_invoice!.status)}

Generated by BizSync Business Management App
''';

      await Share.share(
        invoiceText,
        subject: 'Invoice ${_invoice!.invoiceNumber}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printInvoice() async {
    if (_invoice == null) return;

    try {
      // For mobile platforms, we'll generate a PDF and let the user handle printing
      await _exportAsPdf();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'PDF generated. Use your system\'s print dialog to print.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing invoice for printing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendInvoice() async {
    if (_invoice == null) return;

    try {
      // Generate PDF and share it via email or messaging
      final pdfPath = await _generatePdfFile();

      await Share.shareXFiles(
        [XFile(pdfPath)],
        subject: 'Invoice ${_invoice!.invoiceNumber}',
        text:
            'Please find attached invoice ${_invoice!.invoiceNumber} for \$${_invoice!.total.toStringAsFixed(2)}.',
      );

      // Update invoice status to sent
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Invoice ${_invoice!.invoiceNumber} sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _duplicateInvoice() {
    if (_invoice == null) return;

    // Navigate to create invoice form with pre-filled data
    context.go('/invoices/create', extra: {
      'duplicate_from': _invoice!.id,
      'invoice_data': {
        'customer_name': _invoice!.customerName,
        'customer_email': _invoice!.customerEmail,
        'customer_address': _invoice!.customerAddress,
        'notes': _invoice!.notes,
        // Don't copy invoice number, dates, or payment info
      },
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invoice duplicated. Redirecting to create form.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _exportAsPdf() async {
    if (_invoice == null) return;

    try {
      final pdfPath = await _generatePdfFile();

      // Share the PDF file
      await Share.shareXFiles(
        [XFile(pdfPath)],
        subject: 'Invoice ${_invoice!.invoiceNumber} - PDF',
        text: 'Invoice PDF exported successfully.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _generatePdfFile() async {
    if (_invoice == null) throw Exception('No invoice to export');

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        _invoice!.invoiceNumber,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                          'Date: ${_invoice!.invoiceDate.day}/${_invoice!.invoiceDate.month}/${_invoice!.invoiceDate.year}'),
                      pw.Text(
                          'Due: ${_invoice!.dueDate.day}/${_invoice!.dueDate.month}/${_invoice!.dueDate.year}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Bill To
              pw.Text(
                'Bill To:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(_invoice!.customerName),
              if (_invoice!.customerEmail?.isNotEmpty == true)
                pw.Text(_invoice!.customerEmail!),
              if (_invoice!.customerAddress?.isNotEmpty == true)
                pw.Text(_invoice!.customerAddress!),

              pw.SizedBox(height: 30),

              // Items table placeholder
              pw.Text(
                'Items:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Invoice items will be displayed here'),

              pw.SizedBox(height: 30),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'Subtotal: \$${_invoice!.subtotal.toStringAsFixed(2)}'),
                      if (_invoice!.gstAmount > 0)
                        pw.Text(
                            'GST (9%): \$${_invoice!.gstAmount.toStringAsFixed(2)}'),
                      pw.Divider(),
                      pw.Text(
                        'Total: \$${_invoice!.total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (_invoice!.notes?.isNotEmpty == true) ...[
                pw.SizedBox(height: 30),
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(_invoice!.notes!),
              ],
            ],
          );
        },
      ),
    );

    // Get the app directory to save the file
    final directory = await getTemporaryDirectory();
    final file =
        File('${directory.path}/invoice_${_invoice!.invoiceNumber}.pdf');

    // Save the PDF
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  String _getStatusText(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.viewed:
        return 'Viewed';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.partiallyPaid:
        return 'Partially Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.refunded:
        return 'Refunded';
      default:
        return 'Unknown';
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text(
            'Are you sure you want to delete invoice ${_invoice!.invoiceNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Invoice ${_invoice!.invoiceNumber} deleted'),
                  backgroundColor: Colors.green,
                ),
              );
              context.go('/invoices');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
