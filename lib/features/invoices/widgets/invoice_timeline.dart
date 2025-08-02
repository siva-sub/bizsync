import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';

/// Timeline widget showing invoice workflow history
class InvoiceTimeline extends StatelessWidget {
  final List<CRDTInvoiceWorkflow> workflow;
  final CRDTInvoiceEnhanced invoice;

  const InvoiceTimeline({
    Key? key,
    required this.workflow,
    required this.invoice,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (workflow.isEmpty) {
      return _buildEmptyState(context);
    }

    // Sort workflow entries by timestamp (newest first)
    final sortedWorkflow = List<CRDTInvoiceWorkflow>.from(workflow)
      ..sort((a, b) => b.timestamp.value.compareTo(a.timestamp.value));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedWorkflow.length,
      itemBuilder: (context, index) {
        final entry = sortedWorkflow[index];
        final isLast = index == sortedWorkflow.length - 1;
        
        return _buildTimelineItem(context, entry, isLast);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timeline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No timeline data available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Timeline will appear as actions are taken on this invoice',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, CRDTInvoiceWorkflow entry, bool isLast) {
    final statusIcon = _getStatusIcon(entry.toStatus.value);
    final statusColor = _getStatusColor(entry.toStatus.value);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 2),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Timeline content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getTimelineTitle(entry),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusDisplayName(entry.toStatus.value),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDateTime(entry.timestamp.value),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    if (entry.reason.value != null && entry.reason.value!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        entry.reason.value!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (entry.triggeredBy.value != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'by ${_getTriggeredByDisplayName(entry.triggeredBy.value!)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (entry.context.value != null && entry.context.value!.isNotEmpty)
                      _buildContextDetails(context, entry.context.value!),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContextDetails(BuildContext context, Map<String, dynamic> contextData) {
    return ExpansionTile(
      title: const Text(
        'Additional Details',
        style: TextStyle(fontSize: 14),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contextData.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodySmall,
                    children: [
                      TextSpan(
                        text: '${_formatContextKey(entry.key)}: ',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(text: entry.value.toString()),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getTimelineTitle(CRDTInvoiceWorkflow entry) {
    final fromStatus = entry.fromStatus.value;
    final toStatus = entry.toStatus.value;
    
    if (fromStatus == toStatus) {
      return _getActionTitle(toStatus);
    } else {
      return 'Changed from ${_getStatusDisplayName(fromStatus)} to ${_getStatusDisplayName(toStatus)}';
    }
  }

  String _getActionTitle(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Invoice created';
      case InvoiceStatus.pending:
        return 'Submitted for approval';
      case InvoiceStatus.approved:
        return 'Invoice approved';
      case InvoiceStatus.sent:
        return 'Invoice sent to customer';
      case InvoiceStatus.viewed:
        return 'Customer viewed invoice';
      case InvoiceStatus.partiallyPaid:
        return 'Partial payment received';
      case InvoiceStatus.paid:
        return 'Payment received in full';
      case InvoiceStatus.overdue:
        return 'Invoice became overdue';
      case InvoiceStatus.disputed:
        return 'Dispute raised';
      case InvoiceStatus.cancelled:
        return 'Invoice cancelled';
      case InvoiceStatus.voided:
        return 'Invoice voided';
      case InvoiceStatus.refunded:
        return 'Invoice refunded';
    }
  }

  IconData _getStatusIcon(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return Icons.edit;
      case InvoiceStatus.pending:
        return Icons.hourglass_empty;
      case InvoiceStatus.approved:
        return Icons.check_circle_outline;
      case InvoiceStatus.sent:
        return Icons.send;
      case InvoiceStatus.viewed:
        return Icons.visibility;
      case InvoiceStatus.partiallyPaid:
        return Icons.hourglass_bottom;
      case InvoiceStatus.paid:
        return Icons.check_circle;
      case InvoiceStatus.overdue:
        return Icons.warning;
      case InvoiceStatus.disputed:
        return Icons.report_problem;
      case InvoiceStatus.cancelled:
        return Icons.cancel;
      case InvoiceStatus.voided:
        return Icons.block;
      case InvoiceStatus.refunded:
        return Icons.undo;
    }
  }

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return Colors.grey;
      case InvoiceStatus.pending:
        return Colors.orange;
      case InvoiceStatus.approved:
        return Colors.blue;
      case InvoiceStatus.sent:
        return Colors.blue;
      case InvoiceStatus.viewed:
        return Colors.purple;
      case InvoiceStatus.partiallyPaid:
        return Colors.yellow[700]!;
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.overdue:
        return Colors.red;
      case InvoiceStatus.disputed:
        return Colors.red[700]!;
      case InvoiceStatus.cancelled:
        return Colors.grey[600]!;
      case InvoiceStatus.voided:
        return Colors.grey[800]!;
      case InvoiceStatus.refunded:
        return Colors.purple;
    }
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

  String _getTriggeredByDisplayName(String triggeredBy) {
    switch (triggeredBy.toLowerCase()) {
      case 'system':
        return 'System';
      case 'user':
        return 'User';
      case 'customer':
        return 'Customer';
      case 'automation':
        return 'Automation';
      case 'batch_operation':
        return 'Batch Operation';
      default:
        return triggeredBy;
    }
  }

  String _formatContextKey(String key) {
    // Convert snake_case to Title Case
    return key.split('_').map((word) {
      return word.substring(0, 1).toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        } else {
          return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
        }
      } else {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      }
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('MMM dd, yyyy \'at\' h:mm a').format(dateTime);
    }
  }
}