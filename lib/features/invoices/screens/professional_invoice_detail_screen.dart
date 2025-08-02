import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/demo/demo_data_service.dart';
import '../models/enhanced_invoice_model.dart';
import '../widgets/invoice_status_chip.dart';

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
                    title: Text('Delete Invoice', style: TextStyle(color: Colors.red)),
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
      floatingActionButton: _invoice != null && _invoice!.status == InvoiceStatus.draft
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
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _invoice!.dueDate.isBefore(DateTime.now())
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
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                              _tableCell('\$${item.unitPrice.toStringAsFixed(2)}'),
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
                  _summaryRow('Subtotal', '\$${_invoice!.subtotal.toStringAsFixed(2)}'),
                  if (_invoice!.gstAmount > 0) ...[
                    const SizedBox(height: 8),
                    _summaryRow('GST (9%)', '\$${_invoice!.gstAmount.toStringAsFixed(2)}'),
                  ],
                  if (_invoice!.discountAmount > 0) ...[
                    const SizedBox(height: 8),
                    _summaryRow('Discount', '-\$${_invoice!.discountAmount.toStringAsFixed(2)}'),
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

  void _shareInvoice() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _printInvoice() {
    // TODO: Implement print functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Print functionality coming soon')),
    );
  }

  void _sendInvoice() {
    // TODO: Implement send invoice functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invoice sent successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _duplicateInvoice() {
    // TODO: Implement duplicate functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicate functionality coming soon')),
    );
  }

  void _exportAsPdf() {
    // TODO: Implement PDF export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF export functionality coming soon')),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text('Are you sure you want to delete invoice ${_invoice!.invoiceNumber}?'),
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