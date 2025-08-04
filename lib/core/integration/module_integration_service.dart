import 'package:flutter/material.dart';
import '../../navigation/app_navigation_service.dart';

/// Service that provides integration points between different modules
/// This demonstrates how modules can work together in the BizSync app
class ModuleIntegrationService {
  static final ModuleIntegrationService _instance =
      ModuleIntegrationService._internal();

  factory ModuleIntegrationService() => _instance;

  ModuleIntegrationService._internal();

  final AppNavigationService _navigationService = AppNavigationService();

  // Invoice -> Payment Integration
  /// When an invoice is created, offer to generate a payment QR code
  Future<void> onInvoiceCreated({
    required String invoiceId,
    required String invoiceNumber,
    required double totalAmount,
    required String customerName,
    required BuildContext context,
  }) async {
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invoice $invoiceNumber created successfully!'),
        action: SnackBarAction(
          label: 'Generate QR',
          onPressed: () {
            _navigationService.createInvoiceAndGeneratePayment(
              invoiceNumber: invoiceNumber,
              amount: totalAmount,
              customerName: customerName,
            );
          },
        ),
      ),
    );

    // Trigger backup reminder after important data creation
    _scheduleBackupReminder(context, 'invoice created');
  }

  /// When payment is received, update invoice status and send notification
  Future<void> onPaymentReceived({
    required String invoiceId,
    required double amount,
    required String paymentMethod,
    required BuildContext context,
  }) async {
    // Update invoice status (this would integrate with invoice service)
    // Send notification (this would integrate with notification service)

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment of \$${amount.toStringAsFixed(2)} received!'),
        backgroundColor: Colors.green,
      ),
    );

    // Update dashboard metrics
    _triggerDashboardRefresh();
  }

  // Employee -> Tax Integration
  /// When payroll is calculated, integrate with tax calculator
  Future<void> onPayrollCalculated({
    required String employeeId,
    required String employeeName,
    required double grossSalary,
    required double cpf,
    required BuildContext context,
  }) async {
    // Calculate tax implications
    final taxAmount = _calculateIncomeTax(grossSalary);

    // Show payroll summary with tax information
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payroll Summary - $employeeName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPayrollLine('Gross Salary', grossSalary),
            _buildPayrollLine('CPF Contribution', cpf),
            _buildPayrollLine('Estimated Income Tax', taxAmount),
            const Divider(),
            _buildPayrollLine('Net Pay', grossSalary - cpf - taxAmount,
                isBold: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _navigationService.calculatePayrollTaxes(
                grossSalary: grossSalary,
                employeeId: employeeId,
              );
            },
            child: const Text('View Tax Details'),
          ),
        ],
      ),
    );

    // Trigger backup reminder for payroll data
    _scheduleBackupReminder(context, 'payroll processed');
  }

  // Customer -> Invoice Integration
  /// When a new customer is added, offer to create their first invoice
  Future<void> onCustomerAdded({
    required String customerId,
    required String customerName,
    required String customerEmail,
    required BuildContext context,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Customer $customerName added successfully!'),
        action: SnackBarAction(
          label: 'Create Invoice',
          onPressed: () {
            _navigationService.goToCreateInvoice(
              prefilledData: {
                'customerId': customerId,
                'customerName': customerName,
                'customerEmail': customerEmail,
              },
            );
          },
        ),
      ),
    );
  }

  // Tax -> Notification Integration
  /// When tax calculations are completed, provide reminders and insights
  Future<void> onTaxCalculationCompleted({
    required double totalTax,
    required String taxYear,
    required BuildContext context,
  }) async {
    // Check if tax payment deadline is approaching
    final deadline = _getTaxDeadline(taxYear);
    final daysUntilDeadline = deadline.difference(DateTime.now()).inDays;

    if (daysUntilDeadline <= 30 && daysUntilDeadline > 0) {
      _navigationService.showNotificationAlert(
        title: 'Tax Payment Reminder',
        message:
            'Your tax payment of \$${totalTax.toStringAsFixed(2)} is due in $daysUntilDeadline days.',
        actionRoute: '/tax',
      );
    }

    // Suggest backup before tax filing
    _scheduleBackupReminder(context, 'tax calculation completed');
  }

  // Sync -> Backup Integration
  /// When P2P sync is completed, trigger backup
  Future<void> onSyncCompleted({
    required int syncedRecords,
    required String deviceName,
    required BuildContext context,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Synced $syncedRecords records with $deviceName'),
        backgroundColor: Colors.green,
      ),
    );

    // Auto-trigger backup after successful sync
    _scheduleBackupReminder(context, 'sync completed', autoTrigger: true);
  }

  // Backup -> Notification Integration
  /// When backup is completed, update system status
  Future<void> onBackupCompleted({
    required String backupSize,
    required DateTime backupTime,
    required BuildContext context,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Backup completed - $backupSize'),
        backgroundColor: Colors.green,
      ),
    );

    // Update dashboard with latest backup status
    _triggerDashboardRefresh();
  }

  // Dashboard Integration Methods
  /// Refresh dashboard when important data changes
  void _triggerDashboardRefresh() {
    // This would trigger dashboard providers to refresh their data
    // In a real implementation, this would use Riverpod providers or similar
    debugPrint('Dashboard refresh triggered');
  }

  /// Get integration insights for dashboard
  Map<String, dynamic> getDashboardIntegrationData() {
    return {
      'recentIntegrations': [
        {
          'type': 'invoice_payment',
          'description': 'Invoice INV-001 payment QR generated',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'type': 'payroll_tax',
          'description': 'Employee tax calculation completed',
          'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
        },
        {
          'type': 'customer_invoice',
          'description': 'New customer invoice workflow started',
          'timestamp': DateTime.now().subtract(const Duration(days: 1)),
        },
      ],
      'integrationStats': {
        'invoicePaymentConversion': 0.85, // 85% of invoices get payment QRs
        'payrollTaxChecks': 0.92, // 92% of payroll includes tax calculations
        'customerInvoiceRate': 0.73, // 73% of new customers get invoices
      },
    };
  }

  // Workflow Orchestration
  /// Complete end-to-end business workflow
  Future<void> executeBusinessWorkflow({
    required String workflowType,
    required Map<String, dynamic> data,
    required BuildContext context,
  }) async {
    switch (workflowType) {
      case 'new_customer_onboarding':
        await _executeCustomerOnboardingWorkflow(data, context);
        break;
      case 'monthly_business_review':
        await _executeMonthlyReviewWorkflow(data, context);
        break;
      case 'tax_preparation':
        await _executeTaxPreparationWorkflow(data, context);
        break;
      default:
        debugPrint('Unknown workflow type: $workflowType');
    }
  }

  // Private Helper Methods
  double _calculateIncomeTax(double grossSalary) {
    // Simplified Singapore income tax calculation
    final annualIncome = grossSalary * 12;

    if (annualIncome <= 20000) return 0;
    if (annualIncome <= 30000) return (annualIncome - 20000) * 0.02 / 12;
    if (annualIncome <= 40000)
      return (200 + (annualIncome - 30000) * 0.035) / 12;
    if (annualIncome <= 80000)
      return (550 + (annualIncome - 40000) * 0.07) / 12;

    // Simplified calculation for higher incomes
    return (annualIncome * 0.15) / 12;
  }

  DateTime _getTaxDeadline(String taxYear) {
    // Singapore tax deadline is typically April 15th
    final year = int.parse(taxYear) + 1;
    return DateTime(year, 4, 15);
  }

  Widget _buildPayrollLine(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleBackupReminder(BuildContext context, String reason,
      {bool autoTrigger = false}) {
    if (autoTrigger) {
      // Auto-trigger backup
      _navigationService.goToBackup();
    } else {
      // Show reminder after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (context.mounted) {
          _navigationService.promptBackupAfterDataChange();
        }
      });
    }
  }

  // Workflow Implementation Methods
  Future<void> _executeCustomerOnboardingWorkflow(
    Map<String, dynamic> data,
    BuildContext context,
  ) async {
    // Step 1: Add customer
    _navigationService.goToAddCustomer(prefilledData: data);

    // Steps 2-3 would be triggered by callbacks from the customer creation process
    // Step 2: Create first invoice
    // Step 3: Generate payment QR
  }

  Future<void> _executeMonthlyReviewWorkflow(
    Map<String, dynamic> data,
    BuildContext context,
  ) async {
    // Navigate to dashboard for review
    _navigationService.goToDashboard();

    // Show monthly review checklist
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly Business Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Complete your monthly review:'),
            const SizedBox(height: 12),
            _ChecklistItem('Review revenue analytics', true),
            _ChecklistItem('Check outstanding invoices', false),
            _ChecklistItem('Process employee payroll', false),
            _ChecklistItem('Calculate tax obligations', false),
            _ChecklistItem('Backup business data', false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Start guided review process
            },
            child: const Text('Start Review'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeTaxPreparationWorkflow(
    Map<String, dynamic> data,
    BuildContext context,
  ) async {
    _navigationService.goToTaxCenter();

    // Show tax preparation checklist
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tax Preparation Workflow'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Prepare your taxes:'),
            const SizedBox(height: 12),
            _ChecklistItem('Gather income statements', false),
            _ChecklistItem('Calculate business expenses', false),
            _ChecklistItem('Review employee records', false),
            _ChecklistItem('Use tax calculator', false),
            _ChecklistItem('Backup tax documents', false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _navigationService.goToTaxCalculator();
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String text;
  final bool isCompleted;

  const _ChecklistItem(this.text, this.isCompleted);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.circle_outlined,
            color: isCompleted ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
