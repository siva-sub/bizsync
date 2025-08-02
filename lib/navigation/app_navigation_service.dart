import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/widgets/breadcrumb_widget.dart';

/// Centralized navigation service for the entire application
/// Provides convenient methods to navigate between modules and features
class AppNavigationService {
  static final AppNavigationService _instance = AppNavigationService._internal();
  
  factory AppNavigationService() => _instance;
  
  AppNavigationService._internal();

  // Global navigation key for context-free navigation
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  BuildContext? get context => navigatorKey.currentContext;

  // Home and Dashboard Navigation
  void goHome() {
    if (context != null) {
      context!.go('/');
    }
  }

  void goToDashboard() {
    if (context != null) {
      context!.go('/dashboard');
    }
  }

  // Invoice Module Navigation
  void goToInvoices() {
    if (context != null) {
      context!.go('/invoices');
    }
  }

  void goToCreateInvoice({Map<String, dynamic>? prefilledData}) {
    if (context != null) {
      if (prefilledData != null) {
        context!.go('/invoices/create', extra: prefilledData);
      } else {
        context!.go('/invoices/create');
      }
    }
  }

  void goToInvoiceDetail(String invoiceId) {
    if (context != null) {
      context!.go('/invoices/detail/$invoiceId');
    }
  }

  // Payment Module Navigation
  void goToPayments() {
    if (context != null) {
      context!.go('/payments');
    }
  }

  void goToPaymentQR({
    double? amount,
    String? reference,
    String? description,
  }) {
    if (context != null) {
      final params = <String, dynamic>{};
      if (amount != null) params['amount'] = amount;
      if (reference != null) params['reference'] = reference;
      if (description != null) params['description'] = description;
      
      if (params.isNotEmpty) {
        context!.go('/payments/sgqr', extra: params);
      } else {
        context!.go('/payments/sgqr');
      }
    }
  }

  // Customer Module Navigation
  void goToCustomers() {
    if (context != null) {
      context!.go('/customers');
    }
  }

  void goToAddCustomer({Map<String, dynamic>? prefilledData}) {
    if (context != null) {
      if (prefilledData != null) {
        context!.go('/customers/add', extra: prefilledData);
      } else {
        context!.go('/customers/add');
      }
    }
  }

  void goToEditCustomer(String customerId) {
    if (context != null) {
      context!.go('/customers/edit/$customerId');
    }
  }

  // Employee Module Navigation
  void goToEmployees() {
    if (context != null) {
      context!.go('/employees');
    }
  }

  void goToPayroll() {
    if (context != null) {
      context!.go('/employees/payroll');
    }
  }

  void goToLeaveManagement() {
    if (context != null) {
      context!.go('/employees/leave');
    }
  }

  // Tax Module Navigation
  void goToTaxCenter() {
    if (context != null) {
      context!.go('/tax');
    }
  }

  void goToTaxCalculator({
    double? income,
    String? taxYear,
  }) {
    if (context != null) {
      final params = <String, dynamic>{};
      if (income != null) params['income'] = income;
      if (taxYear != null) params['taxYear'] = taxYear;
      
      if (params.isNotEmpty) {
        context!.go('/tax/calculator', extra: params);
      } else {
        context!.go('/tax/calculator');
      }
    }
  }

  void goToTaxSettings() {
    if (context != null) {
      context!.go('/tax/settings');
    }
  }

  // System Module Navigation
  void goToSync() {
    if (context != null) {
      context!.go('/sync');
    }
  }

  void goToBackup() {
    if (context != null) {
      context!.go('/backup');
    }
  }

  void goToNotifications() {
    if (context != null) {
      context!.go('/notifications');
    }
  }

  void goToSettings() {
    if (context != null) {
      context!.go('/settings');
    }
  }

  // Integration Helper Methods
  /// Navigate from invoice creation to payment QR generation
  void createInvoiceAndGeneratePayment({
    required String invoiceNumber,
    required double amount,
    required String customerName,
  }) {
    goToPaymentQR(
      amount: amount,
      reference: invoiceNumber,
      description: 'Payment for $customerName',
    );
  }

  /// Navigate from payroll calculation to tax center
  void calculatePayrollTaxes({
    required double grossSalary,
    required String employeeId,
  }) {
    goToTaxCalculator(
      income: grossSalary,
      taxYear: DateTime.now().year.toString(),
    );
  }

  /// Navigate to backup after important data operations
  void promptBackupAfterDataChange() {
    if (context != null) {
      _showBackupPromptDialog(context!);
    }
  }

  /// Navigate to notifications after system events
  void showNotificationAlert({
    required String title,
    required String message,
    String? actionRoute,
  }) {
    if (context != null) {
      _showNotificationDialog(context!, title, message, actionRoute);
    }
  }

  // Quick Action Methods
  void showQuickActionMenu() {
    if (context != null) {
      _showQuickActionsBottomSheet(context!);
    }
  }

  // Private Helper Methods
  void _showBackupPromptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Recommended'),
        content: const Text(
          'You\'ve made important changes to your data. Would you like to create a backup now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              goToBackup();
            },
            child: const Text('Backup Now'),
          ),
        ],
      ),
    );
  }

  void _showNotificationDialog(
    BuildContext context,
    String title,
    String message,
    String? actionRoute,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          if (actionRoute != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(actionRoute);
              },
              child: const Text('View'),
            ),
        ],
      ),
    );
  }

  void _showQuickActionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _QuickActionTile(
                  icon: Icons.receipt_long,
                  label: 'New Invoice',
                  onTap: () {
                    Navigator.pop(context);
                    goToCreateInvoice();
                  },
                ),
                _QuickActionTile(
                  icon: Icons.qr_code,
                  label: 'Payment QR',
                  onTap: () {
                    Navigator.pop(context);
                    goToPaymentQR();
                  },
                ),
                _QuickActionTile(
                  icon: Icons.person_add,
                  label: 'Add Customer',
                  onTap: () {
                    Navigator.pop(context);
                    goToAddCustomer();
                  },
                ),
                _QuickActionTile(
                  icon: Icons.calculate,
                  label: 'Tax Calculator',
                  onTap: () {
                    Navigator.pop(context);
                    goToTaxCalculator();
                  },
                ),
                _QuickActionTile(
                  icon: Icons.backup,
                  label: 'Backup Data',
                  onTap: () {
                    Navigator.pop(context);
                    goToBackup();
                  },
                ),
                _QuickActionTile(
                  icon: Icons.sync,
                  label: 'Sync Devices',
                  onTap: () {
                    Navigator.pop(context);
                    goToSync();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Workflow Integration Methods
  /// Complete invoice workflow: Create -> Send -> Generate Payment QR
  Future<void> completeInvoiceWorkflow({
    required Map<String, dynamic> invoiceData,
  }) async {
    // Navigate to create invoice with pre-filled data
    goToCreateInvoice(prefilledData: invoiceData);
    
    // After invoice creation, offer to generate payment QR
    // This would be called from the invoice creation success callback
  }

  /// Employee onboarding workflow: Add Employee -> Setup Payroll -> Calculate Taxes
  Future<void> completeEmployeeOnboardingWorkflow({
    required Map<String, dynamic> employeeData,
  }) async {
    // Navigate through employee setup process
    goToEmployees();
    // Additional workflow steps would be implemented as needed
  }

  /// Monthly business review workflow: Generate Reports -> Backup Data -> Plan Taxes
  Future<void> completeMonthlyReviewWorkflow() async {
    goToDashboard();
    // Show monthly review checklist or wizard
  }

  // External Integration Points
  /// Integration with external apps
  void shareInvoice(String invoiceId, {String? method}) async {
    if (context != null) {
      try {
        // Navigate to invoice detail for sharing options
        context!.go('/invoices/detail/$invoiceId');
        
        // Show sharing options dialog
        await showDialog(
          context: context!,
          builder: (context) => AlertDialog(
            title: const Text('Share Invoice'),
            content: const Text('Select sharing method:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Implement email sharing
                  _shareViaEmail(invoiceId);
                },
                child: const Text('Email'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Implement PDF sharing
                  _shareViaPDF(invoiceId);
                },
                child: const Text('PDF'),
              ),
            ],
          ),
        );
      } catch (e) {
        debugPrint('Error sharing invoice: $e');
      }
    }
  }

  void exportData({String? format}) async {
    if (context != null) {
      try {
        // Show export options dialog
        await showDialog(
          context: context!,
          builder: (context) => AlertDialog(
            title: const Text('Export Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select export format:'),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: const Text('Excel (.xlsx)'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportToExcel();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('CSV (.csv)'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportToCSV();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF Report'),
                  onTap: () {
                    Navigator.pop(context);
                    _exportToPDF();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      } catch (e) {
        debugPrint('Error exporting data: $e');
      }
    }
  }

  void importData({String? source}) async {
    if (context != null) {
      try {
        // Show import options dialog
        await showDialog(
          context: context!,
          builder: (context) => AlertDialog(
            title: const Text('Import Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select import source:'),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.file_upload),
                  title: const Text('From File'),
                  onTap: () {
                    Navigator.pop(context);
                    _importFromFile();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download),
                  title: const Text('From Cloud'),
                  onTap: () {
                    Navigator.pop(context);
                    _importFromCloud();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('From Another Device'),
                  onTap: () {
                    Navigator.pop(context);
                    goToSync();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      } catch (e) {
        debugPrint('Error importing data: $e');
      }
    }
  }

  // Private helper methods for sharing and export
  void _shareViaEmail(String invoiceId) {
    // Implementation would integrate with email service
    debugPrint('Sharing invoice $invoiceId via email');
  }

  void _shareViaPDF(String invoiceId) {
    // Implementation would generate and share PDF
    debugPrint('Sharing invoice $invoiceId as PDF');
  }

  void _exportToExcel() {
    debugPrint('Exporting data to Excel');
  }

  void _exportToCSV() {
    debugPrint('Exporting data to CSV');
  }

  void _exportToPDF() {
    debugPrint('Exporting data to PDF');
  }

  void _importFromFile() {
    debugPrint('Importing data from file');
  }

  void _importFromCloud() {
    debugPrint('Importing data from cloud');
  }

  /// Generate breadcrumbs for current route
  List<BreadcrumbItem> getBreadcrumbs(String currentRoute) {
    final breadcrumbs = <BreadcrumbItem>[];
    
    // Always start with home
    breadcrumbs.add(const BreadcrumbItem(
      label: 'Home',
      path: '/',
      icon: Icons.home,
    ));
    
    // Parse route segments and create breadcrumbs
    final segments = currentRoute.split('/').where((s) => s.isNotEmpty).toList();
    String path = '';
    
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      path += '/$segment';
      
      switch (segment.toLowerCase()) {
        case 'dashboard':
          breadcrumbs.add(const BreadcrumbItem(
            label: 'Dashboard',
            path: '/dashboard',
            icon: Icons.dashboard,
          ));
          break;
        case 'invoices':
          breadcrumbs.add(const BreadcrumbItem(
            label: 'Invoices',
            path: '/invoices',
            icon: Icons.receipt,
          ));
          break;
        case 'customers':
          breadcrumbs.add(const BreadcrumbItem(
            label: 'Customers',
            path: '/customers',
            icon: Icons.people,
          ));
          break;
        case 'employees':
          breadcrumbs.add(const BreadcrumbItem(
            label: 'Employees',
            path: '/employees',
            icon: Icons.badge,
          ));
          break;
        case 'tax':
          breadcrumbs.add(const BreadcrumbItem(
            label: 'Tax Center',
            path: '/tax',
            icon: Icons.calculate,
          ));
          break;
        case 'sync':
          breadcrumbs.add(const BreadcrumbItem(
            label: 'Sync',
            path: '/sync',
            icon: Icons.sync,
          ));
          break;
        case 'backup':
          breadcrumbs.add(const BreadcrumbItem(
            label: 'Backup',
            path: '/backup',
            icon: Icons.backup,
          ));
          break;
        case 'notifications':
          breadcrumbs.add(const BreadcrumbItem(
            label: 'Notifications',
            path: '/notifications',
            icon: Icons.notifications,
          ));
          break;
        case 'settings':
          breadcrumbs.add(const BreadcrumbItem(
            label: 'Settings',
            path: '/settings',
            icon: Icons.settings,
          ));
          break;
        case 'create':
          breadcrumbs.add(BreadcrumbItem(
            label: 'Create',
            path: path,
            icon: Icons.add,
          ));
          break;
        case 'edit':
          breadcrumbs.add(BreadcrumbItem(
            label: 'Edit',
            path: path,
            icon: Icons.edit,
          ));
          break;
        case 'detail':
          breadcrumbs.add(BreadcrumbItem(
            label: 'Details',
            path: path,
            icon: Icons.info,
          ));
          break;
        case 'payroll':
          breadcrumbs.add(BreadcrumbItem(
            label: 'Payroll',
            path: path,
            icon: Icons.payments,
          ));
          break;
        case 'leave':
          breadcrumbs.add(BreadcrumbItem(
            label: 'Leave Management',
            path: path,
            icon: Icons.event,
          ));
          break;
        case 'calculator':
          breadcrumbs.add(BreadcrumbItem(
            label: 'Calculator',
            path: path,
            icon: Icons.calculate,
          ));
          break;
        default:
          // For IDs or other segments, add a generic breadcrumb
          if (segment.length > 10) {
            // Likely an ID, truncate for display
            breadcrumbs.add(BreadcrumbItem(
              label: '${segment.substring(0, 8)}...',
              path: path,
              icon: Icons.description,
            ));
          } else {
            breadcrumbs.add(BreadcrumbItem(
              label: segment.replaceAll('_', ' ').toUpperCase(),
              path: path,
              icon: Icons.folder,
            ));
          }
          break;
      }
    }
    
    return breadcrumbs;
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}