import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/gestures/swipe_gesture_handler.dart';
import '../../../core/feedback/haptic_service.dart';
import '../../../core/performance/performance_optimizer.dart';
import '../models/invoice_models.dart';

class EnhancedInvoiceListItem extends ConsumerWidget {
  final InvoiceModel invoice;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onMarkPaid;

  const EnhancedInvoiceListItem({
    super.key,
    required this.invoice,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwipeActionWidget(
      leftActions: [
        SwipeAction(
          icon: Icons.edit_outlined,
          label: 'Edit',
          backgroundColor: Colors.blue,
          onTap: () {
            ref.read(hapticServiceProvider).buttonTap();
            onEdit?.call();
          },
        ),
        SwipeAction(
          icon: Icons.share_outlined,
          label: 'Share',
          backgroundColor: Colors.green,
          onTap: () {
            ref.read(hapticServiceProvider).buttonTap();
            onShare?.call();
          },
        ),
      ],
      rightActions: [
        if (invoice.status != InvoiceStatus.paid)
          SwipeAction(
            icon: Icons.check_circle_outline,
            label: 'Mark Paid',
            backgroundColor: Colors.green,
            onTap: () {
              ref.read(hapticServiceProvider).successAction();
              onMarkPaid?.call();
            },
          ),
        SwipeAction(
          icon: Icons.delete_outline,
          label: 'Delete',
          backgroundColor: Colors.red,
          dismissible: true,
          onTap: () {
            ref.read(hapticServiceProvider).errorAction();
            onDelete?.call();
          },
        ),
      ],
      onSwipeComplete: (direction) {
        // Additional haptic feedback for completed swipes
        ref.read(hapticServiceProvider).swipeGesture();
      },
      child: SmoothAnimationWrapper(
        child: InkWell(
          onTap: () {
            ref.read(hapticServiceProvider).buttonTap();
            onTap?.call();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invoice #${invoice.invoiceNumber}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              invoice.customerName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${invoice.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(invoice.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(invoice.status),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(invoice.status),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(invoice.issueDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${_formatDate(invoice.dueDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: invoice.dueDate.isBefore(DateTime.now()) && 
                                invoice.status != InvoiceStatus.paid
                              ? Colors.red
                              : Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      if (invoice.dueDate.isBefore(DateTime.now()) && 
                          invoice.status != InvoiceStatus.paid)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'OVERDUE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  // Progress bar for partial payments
                  if (invoice.status == InvoiceStatus.partiallyPaid) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: invoice.paidAmount / invoice.total,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paid: \$${invoice.paidAmount.toStringAsFixed(2)} of \$${invoice.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return Colors.grey;
      case InvoiceStatus.sent:
        return Colors.blue;
      case InvoiceStatus.viewed:
        return Colors.orange;
      case InvoiceStatus.partiallyPaid:
        return Colors.amber;
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.overdue:
        return Colors.red;
      case InvoiceStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Draft';
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
      case InvoiceStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Enhanced invoice list with performance optimizations
class EnhancedInvoiceListView extends ConsumerWidget {
  final List<InvoiceModel> invoices;
  final Function(InvoiceModel)? onInvoiceTap;
  final Function(InvoiceModel)? onInvoiceEdit;
  final Function(InvoiceModel)? onInvoiceDelete;
  final Function(InvoiceModel)? onInvoiceShare;
  final Function(InvoiceModel)? onInvoiceMarkPaid;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLoadMore;
  final bool hasMore;

  const EnhancedInvoiceListView({
    super.key,
    required this.invoices,
    this.onInvoiceTap,
    this.onInvoiceEdit,
    this.onInvoiceDelete,
    this.onInvoiceShare,
    this.onInvoiceMarkPaid,
    this.onRefresh,
    this.onLoadMore,
    this.hasMore = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget listWidget = LazyLoadingListView<InvoiceModel>(
      items: invoices,
      itemBuilder: (context, invoice, index) {
        return EnhancedInvoiceListItem(
          invoice: invoice,
          onTap: () => onInvoiceTap?.call(invoice),
          onEdit: () => onInvoiceEdit?.call(invoice),
          onDelete: () => _showDeleteConfirmation(context, ref, invoice),
          onShare: () => onInvoiceShare?.call(invoice),
          onMarkPaid: () => _showMarkPaidConfirmation(context, ref, invoice),
        );
      },
      onLoadMore: onLoadMore,
      hasMore: hasMore,
      padding: const EdgeInsets.symmetric(vertical: 8),
    );

    if (onRefresh != null) {
      listWidget = PullToRefreshWrapper(
        onRefresh: onRefresh!,
        child: listWidget,
      );
    }

    return listWidget;
  }

  void _showDeleteConfirmation(
    BuildContext context, 
    WidgetRef ref, 
    InvoiceModel invoice,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text(
          'Are you sure you want to delete invoice #${invoice.invoiceNumber}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(hapticServiceProvider).errorAction();
              onInvoiceDelete?.call(invoice);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMarkPaidConfirmation(
    BuildContext context, 
    WidgetRef ref, 
    InvoiceModel invoice,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mark invoice #${invoice.invoiceNumber} as paid?'),
            const SizedBox(height: 8),
            Text(
              'Amount: \$${invoice.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Customer: ${invoice.customerName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(hapticServiceProvider).successAction();
              onInvoiceMarkPaid?.call(invoice);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );
  }
}

// Connection status indicator
class ConnectionStatusIndicator extends ConsumerWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    final syncStats = ref.watch(syncStatsProvider);

    if (connectionStatus == ConnectionStatus.online && 
        syncStats.pendingOperations == 0) {
      return const SizedBox.shrink(); // Hide when everything is good
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: connectionStatus == ConnectionStatus.online 
            ? Colors.orange.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: connectionStatus == ConnectionStatus.online 
              ? Colors.orange
              : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connectionStatus == ConnectionStatus.online 
                ? Icons.sync_problem
                : Icons.cloud_off,
            size: 16,
            color: connectionStatus == ConnectionStatus.online 
                ? Colors.orange
                : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            connectionStatus == ConnectionStatus.online
                ? '${syncStats.pendingOperations} pending sync'
                : 'Offline mode',
            style: TextStyle(
              fontSize: 12,
              color: connectionStatus == ConnectionStatus.online 
                  ? Colors.orange[700]
                  : Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}