import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';
import '../services/invoice_service.dart';
import '../repositories/invoice_repository.dart';
import '../widgets/invoice_timeline.dart';
import '../widgets/invoice_payments_list.dart';
import '../widgets/invoice_actions_sheet.dart';

/// Comprehensive invoice detail screen with timeline and workflow tracking
class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  final InvoiceService invoiceService;
  final InvoiceRepository repository;

  const InvoiceDetailScreen({
    Key? key,
    required this.invoiceId,
    required this.invoiceService,
    required this.repository,
  }) : super(key: key);

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  CRDTInvoiceEnhanced? _invoice;
  List<CRDTInvoiceItem> _lineItems = [];
  List<CRDTInvoicePayment> _payments = [];
  List<CRDTInvoiceWorkflow> _workflow = [];
  
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInvoiceData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoiceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load invoice details with all related data
      final invoiceResult = await widget.invoiceService.getInvoiceById(widget.invoiceId);
      if (invoiceResult.success && invoiceResult.data != null) {
        _invoice = invoiceResult.data!;
      }

      // Load line items
      final itemsResult = await widget.invoiceService.getInvoiceItems(widget.invoiceId);
      if (itemsResult.success && itemsResult.data != null) {
        _lineItems = itemsResult.data!;
      }

      // Load payments
      final paymentsResult = await widget.invoiceService.getInvoicePayments(widget.invoiceId);
      if (paymentsResult.success && paymentsResult.data != null) {
        _payments = paymentsResult.data!;
      }

      // Load workflow history
      final workflowResult = await widget.invoiceService.getInvoiceWorkflow(widget.invoiceId);
      if (workflowResult.success && workflowResult.data != null) {
        _workflow = workflowResult.data!;
      }
    } catch (e) {
      _showError('Failed to load invoice: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });
    await _loadInvoiceData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invoice Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invoice Not Found'),
        ),
        body: const Center(
          child: Text('Invoice not found or failed to load'),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            _buildStatusBanner(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildLineItemsTab(),
                  _buildPaymentsTab(),
                  _buildTimelineTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_invoice!.invoiceNumber.value),
          Text(
            _invoice!.customerName.value ?? 'Unknown Customer',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareInvoice,
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: _editInvoice,
        ),
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'duplicate',
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('Duplicate'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('Download PDF'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'print',
              child: ListTile(
                leading: Icon(Icons.print),
                title: Text('Print'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (_invoice!.status.value != InvoiceStatus.paid &&
                _invoice!.status.value != InvoiceStatus.cancelled)
              const PopupMenuItem(
                value: 'cancel',
                child: ListTile(
                  leading: Icon(Icons.cancel, color: Colors.red),
                  title: Text('Cancel Invoice', style: TextStyle(color: Colors.red)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final status = _invoice!.status.value;
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String message;

    switch (status) {
      case InvoiceStatus.draft:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
        icon = Icons.edit;
        message = 'This invoice is still in draft mode';
        break;
      case InvoiceStatus.sent:
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[800]!;
        icon = Icons.send;
        message = 'Invoice has been sent to customer';
        break;
      case InvoiceStatus.viewed:
        backgroundColor = Colors.purple[50]!;
        textColor = Colors.purple[800]!;
        icon = Icons.visibility;
        message = 'Customer has viewed this invoice';
        break;
      case InvoiceStatus.partiallyPaid:
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[800]!;
        icon = Icons.hourglass_bottom;
        message = 'Partially paid - ${_invoice!.currency.value} ${_formatAmount(_invoice!.remainingBalance)} remaining';
        break;
      case InvoiceStatus.paid:
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[800]!;
        icon = Icons.check_circle;
        message = 'Invoice has been fully paid';
        break;
      case InvoiceStatus.overdue:
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[800]!;
        icon = Icons.warning;
        message = 'Invoice is overdue - immediate action required';
        break;
      case InvoiceStatus.disputed:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        icon = Icons.report_problem;
        message = 'Invoice is under dispute';
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
        icon = Icons.info;
        message = 'Invoice status: ${status.value}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: backgroundColor,
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_invoice!.isOverdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'OVERDUE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
        Tab(icon: Icon(Icons.list), text: 'Items'),
        Tab(icon: Icon(Icons.payment), text: 'Payments'),
        Tab(icon: Icon(Icons.timeline), text: 'Timeline'),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAmountCard(),
          const SizedBox(height: 16),
          _buildInvoiceDetailsCard(),
          const SizedBox(height: 16),
          _buildCustomerCard(),
          const SizedBox(height: 16),
          _buildDatesCard(),
          if (_invoice!.notes.value != null && _invoice!.notes.value!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_invoice!.currency.value} ${_formatAmount(_invoice!.totalAmount.value)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAmountRow('Subtotal', _invoice!.subtotal.value),
            _buildAmountRow('Tax', _invoice!.taxAmount.value),
            if (_invoice!.discountAmount.value > 0)
              _buildAmountRow('Discount', -_invoice!.discountAmount.value, color: Colors.red),
            if (_invoice!.shippingAmount.value > 0)
              _buildAmountRow('Shipping', _invoice!.shippingAmount.value),
            const Divider(),
            if (_invoice!.paymentsReceived.value > 0) ...[
              _buildAmountRow('Paid', _invoice!.paymentsReceived.value / 100, color: Colors.green),
              _buildAmountRow('Remaining', _invoice!.remainingBalance, 
                  color: _invoice!.remainingBalance > 0 ? Colors.orange : Colors.green),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${_invoice!.currency.value} ${_formatAmount(amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Invoice Number', _invoice!.invoiceNumber.value),
            _buildDetailRow('Status', _getStatusDisplayName(_invoice!.status.value)),
            _buildDetailRow('Payment Terms', _getPaymentTermsDisplayName(_invoice!.paymentTerms.value)),
            if (_invoice!.poNumber.value != null)
              _buildDetailRow('PO Number', _invoice!.poNumber.value!),
            if (_invoice!.reference.value != null)
              _buildDetailRow('Reference', _invoice!.reference.value!),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Name', _invoice!.customerName.value ?? 'Unknown'),
            if (_invoice!.customerEmail.value != null)
              _buildDetailRow('Email', _invoice!.customerEmail.value!),
            if (_invoice!.billingAddress.value != null)
              _buildDetailRow('Billing Address', _invoice!.billingAddress.value!),
            if (_invoice!.shippingAddress.value != null &&
                _invoice!.shippingAddress.value != _invoice!.billingAddress.value)
              _buildDetailRow('Shipping Address', _invoice!.shippingAddress.value!),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Important Dates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Issue Date', _formatDate(_invoice!.issueDate.value)),
            if (_invoice!.calculateDueDate() != null)
              _buildDetailRow('Due Date', _formatDate(_invoice!.calculateDueDate()!)),
            if (_invoice!.sentDate.value != null)
              _buildDetailRow('Sent Date', _formatDate(_invoice!.sentDate.value!)),
            if (_invoice!.viewedDate.value != null)
              _buildDetailRow('Viewed Date', _formatDate(_invoice!.viewedDate.value!)),
            if (_invoice!.lastPaymentDate.value != null)
              _buildDetailRow('Last Payment', _formatDate(_invoice!.lastPaymentDate.value!)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            Text(_invoice!.notes.value!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsTab() {
    if (_lineItems.isEmpty) {
      return const Center(
        child: Text('No line items found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lineItems.length,
      itemBuilder: (context, index) {
        final item = _lineItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.description.value,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getItemTypeDisplayName(item.itemType.value),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildItemDetailRow('Quantity', item.quantity.value.toString()),
                    ),
                    Expanded(
                      child: _buildItemDetailRow('Unit Price', 
                          '${_invoice!.currency.value} ${_formatAmount(item.unitPrice.value)}'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildItemDetailRow('Tax Rate', '${item.taxRate.value}%'),
                    ),
                    Expanded(
                      child: _buildItemDetailRow('Line Total', 
                          '${_invoice!.currency.value} ${_formatAmount(item.lineTotal.value)}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    return InvoicePaymentsList(
      payments: _payments,
      currency: _invoice!.currency.value,
      onPaymentTap: _showPaymentDetails,
    );
  }

  Widget _buildTimelineTab() {
    return InvoiceTimeline(
      workflow: _workflow,
      invoice: _invoice!,
    );
  }

  Widget? _buildFloatingActionButton() {
    final status = _invoice!.status.value;
    
    if (status == InvoiceStatus.draft) {
      return FloatingActionButton.extended(
        onPressed: _sendInvoice,
        icon: const Icon(Icons.send),
        label: const Text('Send Invoice'),
      );
    } else if (status == InvoiceStatus.sent || 
               status == InvoiceStatus.viewed || 
               status == InvoiceStatus.partiallyPaid ||
               status == InvoiceStatus.overdue) {
      return FloatingActionButton.extended(
        onPressed: _recordPayment,
        icon: const Icon(Icons.payment),
        label: const Text('Record Payment'),
      );
    }
    
    return null;
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'duplicate':
        _duplicateInvoice();
        break;
      case 'pdf':
        _downloadPdf();
        break;
      case 'print':
        _printInvoice();
        break;
      case 'cancel':
        _cancelInvoice();
        break;
    }
  }

  void _shareInvoice() {
    showModalBottomSheet(
      context: context,
      builder: (context) => InvoiceActionsSheet(
        invoice: _invoice!,
        onActionSelected: (action) {
          Navigator.pop(context);
          // Handle share action
        },
      ),
    );
  }

  void _editInvoice() {
    context.go('/invoices/edit/${widget.invoiceId}');
    // Note: Consider using refresh callback when returning from edit screen
  }

  void _sendInvoice() async {
    try {
      final result = await widget.invoiceService.changeStatus(
        widget.invoiceId,
        InvoiceStatus.sent,
        reason: 'Invoice sent manually',
        triggeredBy: 'user',
      );

      if (result.success) {
        _showSuccess('Invoice sent successfully');
        _refreshData();
      } else {
        _showError(result.errorMessage ?? 'Failed to send invoice');
      }
    } catch (e) {
      _showError('Failed to send invoice: $e');
    }
  }

  void _recordPayment() {
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _buildPaymentDialog(),
    ).then((paymentData) {
      if (paymentData != null) {
        _processPayment(paymentData);
      }
    });
  }

  Widget _buildPaymentDialog() {
    final amountController = TextEditingController(
      text: _invoice!.remainingBalance.toStringAsFixed(2),
    );
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    String paymentMethod = 'bank_transfer';
    DateTime paymentDate = DateTime.now();

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Record Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invoice: ${_invoice!.invoiceNumber.value}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Outstanding: ${_invoice!.currency.value} ${_formatAmount(_invoice!.remainingBalance)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Payment Amount',
                    prefixText: '${_invoice!.currency.value} ',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'credit_card', child: Text('Credit Card')),
                    DropdownMenuItem(value: 'paynow', child: Text('PayNow')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      paymentMethod = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.of(context).pop({
                    'amount': amount,
                    'payment_method': paymentMethod,
                    'payment_date': paymentDate,
                    'reference': referenceController.text,
                    'notes': notesController.text,
                  });
                }
              },
              child: const Text('Record Payment'),
            ),
          ],
        );
      },
    );
  }

  void _processPayment(Map<String, dynamic> paymentData) async {
    try {
      final result = await widget.invoiceService.recordPayment(
        invoiceId: widget.invoiceId,
        amount: paymentData['amount'],
        paymentMethod: paymentData['payment_method'],
        paymentDate: paymentData['payment_date'],
        paymentReference: paymentData['reference'],
        notes: paymentData['notes'],
      );

      if (result.success) {
        _showSuccess('Payment recorded successfully');
        _refreshData();
      } else {
        _showError(result.errorMessage ?? 'Failed to record payment');
      }
    } catch (e) {
      _showError('Failed to record payment: $e');
    }
  }

  void _duplicateInvoice() {
    // Implementation for duplicating invoice
    _showInfo('Duplicate feature not implemented yet');
  }

  void _downloadPdf() {
    // Implementation for PDF download
    _showInfo('PDF download feature not implemented yet');
  }

  void _printInvoice() {
    // Implementation for printing
    _showInfo('Print feature not implemented yet');
  }

  void _cancelInvoice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Invoice'),
        content: Text(
          'Are you sure you want to cancel invoice ${_invoice!.invoiceNumber.value}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Invoice'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                final result = await widget.invoiceService.changeStatus(
                  widget.invoiceId,
                  InvoiceStatus.cancelled,
                  reason: 'Invoice cancelled by user',
                  triggeredBy: 'user',
                );

                if (result.success) {
                  _showSuccess('Invoice cancelled successfully');
                  _refreshData();
                } else {
                  _showError(result.errorMessage ?? 'Failed to cancel invoice');
                }
              } catch (e) {
                _showError('Failed to cancel invoice: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cancel Invoice'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDetails(CRDTInvoicePayment payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payment Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Amount', '${_invoice!.currency.value} ${_formatAmount(payment.amount.value)}'),
            _buildDetailRow('Method', payment.paymentMethod.value),
            _buildDetailRow('Date', _formatDate(payment.paymentDate.value)),
            _buildDetailRow('Status', payment.status.value),
            if (payment.paymentReference.value.isNotEmpty)
              _buildDetailRow('Reference', payment.paymentReference.value),
            if (payment.transactionId.value != null)
              _buildDetailRow('Transaction ID', payment.transactionId.value!),
            if (payment.notes.value != null)
              _buildDetailRow('Notes', payment.notes.value!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  String _getStatusDisplayName(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.pending:
        return 'Pending Approval';
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
      case InvoiceStatus.disputed:
        return 'Disputed';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.voided:
        return 'Voided';
      case InvoiceStatus.refunded:
        return 'Refunded';
    }
  }

  String _getPaymentTermsDisplayName(PaymentTerm term) {
    switch (term) {
      case PaymentTerm.net15:
        return 'Net 15 days';
      case PaymentTerm.net30:
        return 'Net 30 days';
      case PaymentTerm.net45:
        return 'Net 45 days';
      case PaymentTerm.net60:
        return 'Net 60 days';
      case PaymentTerm.net90:
        return 'Net 90 days';
      case PaymentTerm.dueOnReceipt:
        return 'Due on receipt';
      case PaymentTerm.custom:
        return 'Custom terms';
    }
  }

  String _getItemTypeDisplayName(LineItemType type) {
    switch (type) {
      case LineItemType.product:
        return 'Product';
      case LineItemType.service:
        return 'Service';
      case LineItemType.discount:
        return 'Discount';
      case LineItemType.shipping:
        return 'Shipping';
      case LineItemType.tax:
        return 'Tax';
      case LineItemType.custom:
        return 'Custom';
    }
  }
}