import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';

/// Widget displaying list of invoice payments
class InvoicePaymentsList extends StatelessWidget {
  final List<CRDTInvoicePayment> payments;
  final String currency;
  final Function(CRDTInvoicePayment)? onPaymentTap;

  const InvoicePaymentsList({
    Key? key,
    required this.payments,
    required this.currency,
    this.onPaymentTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return _buildEmptyState(context);
    }

    // Sort payments by date (newest first)
    final sortedPayments = List<CRDTInvoicePayment>.from(payments)
      ..sort((a, b) => b.paymentDate.value.compareTo(a.paymentDate.value));

    return Column(
      children: [
        _buildPaymentsSummary(context),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedPayments.length,
            itemBuilder: (context, index) {
              final payment = sortedPayments[index];
              return _buildPaymentCard(context, payment);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No payments recorded',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payments will appear here once recorded',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsSummary(BuildContext context) {
    final totalPaid = payments.fold<double>(
      0.0,
      (sum, payment) => sum + payment.amount.value,
    );

    final completedPayments = payments
        .where(
          (payment) => payment.status.value == 'completed',
        )
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Paid',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currency ${_formatAmount(totalPaid)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Payments',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '$completedPayments of ${payments.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, CRDTInvoicePayment payment) {
    final statusColor = _getPaymentStatusColor(payment.status.value);
    final statusIcon = _getPaymentStatusIcon(payment.status.value);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onPaymentTap != null ? () => onPaymentTap!(payment) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$currency ${_formatAmount(payment.amount.value)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getPaymentStatusDisplayName(
                                    payment.status.value),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(payment.paymentDate.value),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (onPaymentTap != null)
                    const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              _buildPaymentDetails(context, payment),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetails(
      BuildContext context, CRDTInvoicePayment payment) {
    return Column(
      children: [
        _buildDetailRow(
          context,
          'Payment Method',
          _getPaymentMethodDisplayName(payment.paymentMethod.value),
          Icons.payment,
        ),
        if (payment.paymentReference.value.isNotEmpty)
          _buildDetailRow(
            context,
            'Reference',
            payment.paymentReference.value,
            Icons.confirmation_number,
          ),
        if (payment.transactionId.value != null &&
            payment.transactionId.value!.isNotEmpty)
          _buildDetailRow(
            context,
            'Transaction ID',
            payment.transactionId.value!,
            Icons.receipt,
          ),
        if (payment.notes.value != null && payment.notes.value!.isNotEmpty)
          _buildDetailRow(
            context,
            'Notes',
            payment.notes.value!,
            Icons.note,
          ),
      ],
    );
  }

  Widget _buildDetailRow(
      BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'reversed':
        return Colors.grey;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'failed':
        return Icons.error;
      case 'reversed':
        return Icons.undo;
      case 'processing':
        return Icons.sync;
      default:
        return Icons.help_outline;
    }
  }

  String _getPaymentStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      case 'reversed':
        return 'Reversed';
      case 'processing':
        return 'Processing';
      default:
        return status.toUpperCase();
    }
  }

  String _getPaymentMethodDisplayName(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'credit_card':
        return 'Credit Card';
      case 'paynow':
        return 'PayNow';
      case 'cheque':
        return 'Cheque';
      case 'giro':
        return 'GIRO';
      case 'nets':
        return 'NETS';
      default:
        return method
            .split('_')
            .map((word) =>
                word.substring(0, 1).toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
}
