import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';

/// Individual invoice card widget for list display
class InvoiceCard extends StatelessWidget {
  final CRDTInvoiceEnhanced invoice;
  final VoidCallback? onTap;
  final Function(String invoiceId, InvoiceStatus newStatus)? onStatusChanged;
  final Function(String invoiceId, double amount)? onPaymentRecorded;

  const InvoiceCard({
    Key? key,
    required this.invoice,
    this.onTap,
    this.onStatusChanged,
    this.onPaymentRecorded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildCustomerInfo(context),
              const SizedBox(height: 12),
              _buildAmountInfo(context),
              const SizedBox(height: 12),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invoice.invoiceNumber.value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Issued: ${_formatDate(invoice.issueDate.value)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        _buildStatusChip(context),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final status = invoice.status.value;
    Color chipColor;
    Color textColor;

    switch (status) {
      case InvoiceStatus.draft:
        chipColor = Colors.grey[300]!;
        textColor = Colors.grey[800]!;
        break;
      case InvoiceStatus.pending:
        chipColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      case InvoiceStatus.approved:
        chipColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        break;
      case InvoiceStatus.sent:
        chipColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        break;
      case InvoiceStatus.viewed:
        chipColor = Colors.purple[100]!;
        textColor = Colors.purple[800]!;
        break;
      case InvoiceStatus.partiallyPaid:
        chipColor = Colors.yellow[100]!;
        textColor = Colors.yellow[800]!;
        break;
      case InvoiceStatus.paid:
        chipColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case InvoiceStatus.overdue:
        chipColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      case InvoiceStatus.disputed:
        chipColor = Colors.red[200]!;
        textColor = Colors.red[900]!;
        break;
      case InvoiceStatus.cancelled:
        chipColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        break;
      case InvoiceStatus.voided:
        chipColor = Colors.grey[300]!;
        textColor = Colors.grey[800]!;
        break;
      case InvoiceStatus.refunded:
        chipColor = Colors.purple[100]!;
        textColor = Colors.purple[800]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _getStatusDisplayName(status),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCustomerInfo(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.person_outline,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            invoice.customerName.value ?? 'Unknown Customer',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (invoice.isOverdue)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.red[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'OVERDUE',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAmountInfo(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${invoice.currency.value} ${_formatAmount(invoice.totalAmount.value)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              if (invoice.isPartiallyPaid) ...[
                const SizedBox(height: 4),
                Text(
                  'Remaining: ${invoice.currency.value} ${_formatAmount(invoice.remainingBalance)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (invoice.calculateDueDate() != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Due Date',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                _formatDate(invoice.calculateDueDate()!),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: invoice.isOverdue ? Colors.red[600] : null,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (invoice.tags.elements.isNotEmpty) ...[
                Icon(
                  Icons.local_offer_outlined,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  invoice.tags.elements.take(2).join(', '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (invoice.tags.elements.length > 2)
                  Text(
                    ' +${invoice.tags.elements.length - 2}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ],
          ),
        ),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final actions = <Widget>[];

    // Quick status change buttons
    if (invoice.status.value == InvoiceStatus.draft) {
      actions.add(
        IconButton(
          onPressed: () => onStatusChanged?.call(invoice.id, InvoiceStatus.sent),
          icon: const Icon(Icons.send, size: 20),
          tooltip: 'Send Invoice',
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (invoice.status.value == InvoiceStatus.sent ||
        invoice.status.value == InvoiceStatus.viewed ||
        invoice.status.value == InvoiceStatus.partiallyPaid) {
      actions.add(
        IconButton(
          onPressed: () => _showPaymentDialog(context),
          icon: const Icon(Icons.payment, size: 20),
          tooltip: 'Record Payment',
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    // Share/Print button
    actions.add(
      IconButton(
        onPressed: () => _showShareOptions(context),
        icon: const Icon(Icons.share, size: 20),
        tooltip: 'Share',
        visualDensity: VisualDensity.compact,
      ),
    );

    // More options
    actions.add(
      PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(context, value),
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
          if (invoice.status.value != InvoiceStatus.paid &&
              invoice.status.value != InvoiceStatus.cancelled)
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
        child: const Icon(Icons.more_vert, size: 20),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
  }

  void _showPaymentDialog(BuildContext context) {
    final amountController = TextEditingController(
      text: invoice.remainingBalance.toStringAsFixed(2),
    );

    showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Invoice: ${invoice.invoiceNumber.value}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Outstanding: ${invoice.currency.value} ${_formatAmount(invoice.remainingBalance)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '${invoice.currency.value} ',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
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
                Navigator.of(context).pop(amount);
              }
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    ).then((amount) {
      if (amount != null) {
        onPaymentRecorded?.call(invoice.id, amount);
      }
    });
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Email'),
            onTap: () {
              Navigator.pop(context);
              // Handle email sharing
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Copy Link'),
            onTap: () {
              Navigator.pop(context);
              // Handle link copying
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('QR Code'),
            onTap: () {
              Navigator.pop(context);
              // Handle QR code generation
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'duplicate':
        // Handle duplication
        break;
      case 'pdf':
        // Handle PDF generation
        break;
      case 'cancel':
        _showCancelDialog(context);
        break;
    }
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Invoice'),
        content: Text(
          'Are you sure you want to cancel invoice ${invoice.invoiceNumber.value}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Invoice'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onStatusChanged?.call(invoice.id, InvoiceStatus.cancelled);
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
        return 'Pending';
      case InvoiceStatus.approved:
        return 'Approved';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.viewed:
        return 'Viewed';
      case InvoiceStatus.partiallyPaid:
        return 'Partial';
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
}