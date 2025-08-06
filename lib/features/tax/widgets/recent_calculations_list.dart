import 'package:flutter/material.dart';

class RecentCalculationsList extends StatelessWidget {
  final List<TaxCalculationItem>? calculations;
  final int maxItems;
  final VoidCallback? onViewAll;

  const RecentCalculationsList({
    super.key,
    this.calculations,
    this.maxItems = 5,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final items = calculations ?? _getDefaultCalculations();
    final displayItems = items.take(maxItems).toList();

    if (displayItems.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        ...displayItems.map((item) => _buildCalculationItem(context, item)),
        if (items.length > maxItems && onViewAll != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onViewAll,
            child: Text('View ${items.length - maxItems} more calculations'),
          ),
        ],
      ],
    );
  }

  Widget _buildCalculationItem(BuildContext context, TaxCalculationItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getTaxTypeColor(item.taxType).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getTaxTypeIcon(item.taxType),
            color: _getTaxTypeColor(item.taxType),
            size: 20,
          ),
        ),
        title: Text(
          _getTaxTypeName(item.taxType),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount: ${item.formattedAmount}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _formatDate(item.calculationDate),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.formattedTaxAmount,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _getTaxTypeColor(item.taxType),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '${(item.taxRate * 100).toStringAsFixed(2)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        onTap: () => _viewCalculationDetails(context, item),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.calculate_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Recent Calculations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent tax calculations will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to calculator
            },
            icon: const Icon(Icons.add),
            label: const Text('New Calculation'),
          ),
        ],
      ),
    );
  }

  Color _getTaxTypeColor(TaxCalculationType type) {
    switch (type) {
      case TaxCalculationType.gst:
        return Colors.blue;
      case TaxCalculationType.corporateTax:
        return Colors.green;
      case TaxCalculationType.withholdingTax:
        return Colors.orange;
      case TaxCalculationType.stampDuty:
        return Colors.purple;
      case TaxCalculationType.importDuty:
        return Colors.teal;
    }
  }

  IconData _getTaxTypeIcon(TaxCalculationType type) {
    switch (type) {
      case TaxCalculationType.gst:
        return Icons.receipt_long;
      case TaxCalculationType.corporateTax:
        return Icons.business_center;
      case TaxCalculationType.withholdingTax:
        return Icons.account_balance;
      case TaxCalculationType.stampDuty:
        return Icons.description;
      case TaxCalculationType.importDuty:
        return Icons.local_shipping;
    }
  }

  String _getTaxTypeName(TaxCalculationType type) {
    switch (type) {
      case TaxCalculationType.gst:
        return 'GST Calculation';
      case TaxCalculationType.corporateTax:
        return 'Corporate Tax';
      case TaxCalculationType.withholdingTax:
        return 'Withholding Tax';
      case TaxCalculationType.stampDuty:
        return 'Stamp Duty';
      case TaxCalculationType.importDuty:
        return 'Import Duty';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _viewCalculationDetails(BuildContext context, TaxCalculationItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getTaxTypeName(item.taxType)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Amount', item.formattedAmount),
            _buildDetailRow(
                'Tax Rate', '${(item.taxRate * 100).toStringAsFixed(2)}%'),
            _buildDetailRow('Tax Amount', item.formattedTaxAmount),
            _buildDetailRow('Net Amount', item.formattedNetAmount),
            _buildDetailRow('Date', _formatDate(item.calculationDate)),
            if (item.description != null)
              _buildDetailRow('Description', item.description!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to detailed view or recalculate
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  List<TaxCalculationItem> _getDefaultCalculations() {
    return [
      TaxCalculationItem(
        id: '1',
        taxType: TaxCalculationType.gst,
        amount: 10000,
        taxRate: 0.09,
        taxAmount: 900,
        netAmount: 10900,
        calculationDate: DateTime.now().subtract(const Duration(hours: 2)),
        description: 'Invoice #INV-001',
      ),
      TaxCalculationItem(
        id: '2',
        taxType: TaxCalculationType.corporateTax,
        amount: 500000,
        taxRate: 0.17,
        taxAmount: 85000,
        netAmount: 415000,
        calculationDate: DateTime.now().subtract(const Duration(days: 1)),
        description: 'Annual corporate tax projection',
      ),
      TaxCalculationItem(
        id: '3',
        taxType: TaxCalculationType.withholdingTax,
        amount: 25000,
        taxRate: 0.10,
        taxAmount: 2500,
        netAmount: 22500,
        calculationDate: DateTime.now().subtract(const Duration(days: 2)),
        description: 'Royalty payment to UK',
      ),
      TaxCalculationItem(
        id: '4',
        taxType: TaxCalculationType.stampDuty,
        amount: 1000000,
        taxRate: 0.002,
        taxAmount: 2000,
        netAmount: 1000000,
        calculationDate: DateTime.now().subtract(const Duration(days: 5)),
        description: 'Share transfer agreement',
      ),
      TaxCalculationItem(
        id: '5',
        taxType: TaxCalculationType.importDuty,
        amount: 50000,
        taxRate: 0.07,
        taxAmount: 3500,
        netAmount: 50000,
        calculationDate: DateTime.now().subtract(const Duration(days: 7)),
        description: 'Electronic goods from China',
      ),
    ];
  }
}

enum TaxCalculationType {
  gst,
  corporateTax,
  withholdingTax,
  stampDuty,
  importDuty,
}

class TaxCalculationItem {
  final String id;
  final TaxCalculationType taxType;
  final double amount;
  final double taxRate;
  final double taxAmount;
  final double netAmount;
  final DateTime calculationDate;
  final String? description;

  TaxCalculationItem({
    required this.id,
    required this.taxType,
    required this.amount,
    required this.taxRate,
    required this.taxAmount,
    required this.netAmount,
    required this.calculationDate,
    this.description,
  });

  String get formattedAmount => 'S\$${amount.toStringAsFixed(2)}';
  String get formattedTaxAmount => 'S\$${taxAmount.toStringAsFixed(2)}';
  String get formattedNetAmount => 'S\$${netAmount.toStringAsFixed(2)}';
}
