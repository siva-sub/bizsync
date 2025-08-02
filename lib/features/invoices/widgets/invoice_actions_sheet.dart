import 'package:flutter/material.dart';
import '../models/enhanced_invoice_model.dart';
import '../models/invoice_models.dart';

/// Bottom sheet with invoice actions
class InvoiceActionsSheet extends StatelessWidget {
  final CRDTInvoiceEnhanced invoice;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onGeneratePayment;
  final Function(InvoiceStatus)? onChangeStatus;
  final Function(String)? onActionSelected;

  const InvoiceActionsSheet({
    Key? key,
    required this.invoice,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onGeneratePayment,
    this.onChangeStatus,
    this.onActionSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Invoice Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                invoice.invoiceNumber.value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Edit and Delete
          _buildActionTile(
            context,
            icon: Icons.edit,
            title: 'Edit Invoice',
            subtitle: 'Modify invoice details',
            onTap: () {
              onEdit?.call();
              onActionSelected?.call('edit');
            },
          ),
          _buildActionTile(
            context,
            icon: Icons.content_copy,
            title: 'Duplicate',
            subtitle: 'Create copy of this invoice',
            onTap: () {
              onDuplicate?.call();
              onActionSelected?.call('duplicate');
            },
          ),
          
          const Divider(),
          
          // Status Changes
          if (invoice.status.value == InvoiceStatus.draft)
            _buildActionTile(
              context,
              icon: Icons.send,
              title: 'Send Invoice',
              subtitle: 'Mark as sent and notify customer',
              onTap: () {
                onChangeStatus?.call(InvoiceStatus.sent);
                onActionSelected?.call('send');
              },
            ),
          
          if (invoice.status.value == InvoiceStatus.sent || 
              invoice.status.value == InvoiceStatus.viewed ||
              invoice.status.value == InvoiceStatus.partiallyPaid)
            _buildActionTile(
              context,
              icon: Icons.payment,
              title: 'Mark as Paid',
              subtitle: 'Record full payment',
              onTap: () {
                onChangeStatus?.call(InvoiceStatus.paid);
                onActionSelected?.call('mark_paid');
              },
            ),
          
          if (invoice.status.value != InvoiceStatus.cancelled &&
              invoice.status.value != InvoiceStatus.voided)
            _buildActionTile(
              context,
              icon: Icons.cancel,
              title: 'Cancel Invoice',
              subtitle: 'Cancel this invoice',
              onTap: () {
                onChangeStatus?.call(InvoiceStatus.cancelled);
                onActionSelected?.call('cancel');
              },
            ),
          
          const Divider(),
          
          // Payment and Sharing
          _buildActionTile(
            context,
            icon: Icons.qr_code,
            title: 'Generate Payment QR',
            subtitle: 'Create SGQR for PayNow payment',
            onTap: () {
              onGeneratePayment?.call();
              onActionSelected?.call('generate_payment');
            },
          ),
          _buildActionTile(
            context,
            icon: Icons.email,
            title: 'Email Invoice',
            subtitle: 'Send PDF via email',
            onTap: () => _showComingSoon(context, 'Email functionality'),
          ),
          _buildActionTile(
            context,
            icon: Icons.picture_as_pdf,
            title: 'Download PDF',
            subtitle: 'Save as PDF file',
            onTap: () => _showComingSoon(context, 'PDF generation'),
          ),
          
          const Divider(),
          
          // Danger Zone
          _buildActionTile(
            context,
            icon: Icons.delete,
            title: 'Delete Invoice',
            subtitle: 'Permanently remove invoice',
            onTap: () {
              onDelete?.call();
              onActionSelected?.call('delete');
            },
            isDestructive: true,
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : Theme.of(context).primaryColor;
    
    return ListTile(
      enabled: onTap != null,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}