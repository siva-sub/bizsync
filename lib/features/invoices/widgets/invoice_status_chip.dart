import 'package:flutter/material.dart';
import '../../../core/types/invoice_types.dart';

class InvoiceStatusChip extends StatelessWidget {
  final InvoiceStatus status;
  final bool isCompact;
  final bool useShortLabels;

  const InvoiceStatusChip({
    super.key,
    required this.status,
    this.isCompact = false,
    this.useShortLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(status);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: statusInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusInfo.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusInfo.icon,
            size: isCompact ? 12 : 14,
            color: statusInfo.color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              useShortLabels ? statusInfo.shortLabel : statusInfo.label,
              style: TextStyle(
                color: statusInfo.color,
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return _StatusInfo(
          label: 'Draft',
          shortLabel: 'Draft',
          color: Colors.grey[600]!,
          icon: Icons.drafts_outlined,
        );
      case InvoiceStatus.pending:
        return _StatusInfo(
          label: 'Pending',
          shortLabel: 'Pending',
          color: Colors.orange[600]!,
          icon: Icons.hourglass_empty_outlined,
        );
      case InvoiceStatus.approved:
        return _StatusInfo(
          label: 'Approved',
          shortLabel: 'Approved',
          color: Colors.blue[600]!,
          icon: Icons.check_outlined,
        );
      case InvoiceStatus.sent:
        return _StatusInfo(
          label: 'Sent',
          shortLabel: 'Sent',
          color: Colors.blue[600]!,
          icon: Icons.send_outlined,
        );
      case InvoiceStatus.viewed:
        return _StatusInfo(
          label: 'Viewed',
          shortLabel: 'Viewed',
          color: Colors.cyan[600]!,
          icon: Icons.visibility_outlined,
        );
      case InvoiceStatus.partiallyPaid:
        return _StatusInfo(
          label: 'Partially Paid',
          shortLabel: 'Part. Paid',
          color: Colors.amber[600]!,
          icon: Icons.payments_outlined,
        );
      case InvoiceStatus.paid:
        return _StatusInfo(
          label: 'Paid',
          shortLabel: 'Paid',
          color: Colors.green[600]!,
          icon: Icons.check_circle_outline,
        );
      case InvoiceStatus.overdue:
        return _StatusInfo(
          label: 'Overdue',
          shortLabel: 'Overdue',
          color: Colors.red[600]!,
          icon: Icons.warning_outlined,
        );
      case InvoiceStatus.cancelled:
        return _StatusInfo(
          label: 'Cancelled',
          shortLabel: 'Cancelled',
          color: Colors.orange[600]!,
          icon: Icons.cancel_outlined,
        );
      case InvoiceStatus.disputed:
        return _StatusInfo(
          label: 'Disputed',
          shortLabel: 'Disputed',
          color: Colors.purple[600]!,
          icon: Icons.report_problem_outlined,
        );
      case InvoiceStatus.voided:
        return _StatusInfo(
          label: 'Voided',
          shortLabel: 'Voided',
          color: Colors.grey[800]!,
          icon: Icons.block_outlined,
        );
      case InvoiceStatus.refunded:
        return _StatusInfo(
          label: 'Refunded',
          shortLabel: 'Refunded',
          color: Colors.teal[600]!,
          icon: Icons.undo_outlined,
        );
    }
  }
}

class _StatusInfo {
  final String label;
  final String shortLabel;
  final Color color;
  final IconData icon;

  _StatusInfo({
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.icon,
  });
}