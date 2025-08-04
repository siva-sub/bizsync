import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/main_shell_screen.dart';
import '../presentation/screens/home_dashboard_screen.dart';
import '../features/dashboard/screens/main_dashboard_screen.dart';
import '../features/payments/demo/payment_demo_screen.dart';
import '../features/employees/screens/index.dart';
import '../features/employees/screens/employee_form_screen.dart';
import '../features/employees/screens/employee_reports_screen.dart';
import '../features/employees/models/employee_models.dart';
import '../features/employees/services/employee_service.dart';
import '../core/services/notification_service.dart';
import '../features/tax/screens/tax_calculator_screen.dart';
import '../features/tax/screens/tax_dashboard_screen.dart';
import '../features/sync/ui/device_discovery_screen.dart';
import '../features/backup/ui/backup_screen.dart';
import '../features/notifications/ui/notification_center_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../features/invoices/models/enhanced_invoice.dart';
import '../core/demo/models/demo_employee.dart';
import '../core/demo/demo_data_service.dart';
import '../features/onboarding/screens/welcome_screen.dart';
import '../features/onboarding/screens/company_setup_screen.dart';
import '../features/onboarding/screens/user_profile_screen.dart';
import '../features/onboarding/screens/permissions_screen.dart';
import '../features/onboarding/screens/tutorial_screen.dart';
import '../features/customers/screens/professional_customer_list_screen.dart';
import '../features/customers/screens/professional_customer_form_screen.dart';
import '../features/invoices/screens/professional_invoice_form_screen.dart';
import '../features/reports/screens/reports_dashboard_screen.dart';
import '../features/reports/screens/sales_report_screen.dart';
import '../features/reports/screens/tax_report_screen.dart';
import '../features/reports/screens/financial_report_screen.dart';
import '../features/inventory/screens/inventory_list_screen.dart';
import '../features/inventory/screens/product_form_screen.dart';
import '../features/vendors/screens/vendor_list_screen.dart';
import '../features/vendors/screens/vendor_form_screen.dart';
import '../features/forecasting/screens/forecasting_dashboard_screen.dart';
import '../features/forecasting/screens/revenue_forecasting_screen.dart';
import '../features/forecasting/screens/financial_reports_screen.dart';
import '../features/invoices/screens/recurring_invoices_screen.dart';
import '../features/invoices/screens/email_settings_screen.dart';
import '../features/customers/screens/customer_statements_screen.dart';
import '../features/settings/screens/developer_settings_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Onboarding routes
      GoRoute(
        path: '/onboarding/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/company-setup',
        builder: (context, state) => const CompanySetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/user-profile',
        builder: (context, state) => const UserProfileScreen(),
      ),
      GoRoute(
        path: '/onboarding/permissions',
        builder: (context, state) => const PermissionsScreen(),
      ),
      GoRoute(
        path: '/onboarding/tutorial',
        builder: (context, state) => const TutorialScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeDashboardScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const MainDashboardScreen(),
          ),
          
          // Invoice routes
          GoRoute(
            path: '/invoices',
            builder: (context, state) => const InvoiceListScreenWrapper(),
            routes: [
              GoRoute(
                path: '/create',
                builder: (context, state) => const InvoiceFormScreenWrapper(),
              ),
              GoRoute(
                path: '/detail/:id',
                builder: (context, state) => InvoiceDetailScreenWrapper(
                  invoiceId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: '/edit/:id',
                builder: (context, state) => InvoiceFormScreenWrapper(
                  invoiceId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: '/recurring',
                builder: (context, state) => const RecurringInvoicesScreen(),
              ),
              GoRoute(
                path: '/email-settings',
                builder: (context, state) => const EmailSettingsScreen(),
              ),
            ],
          ),
          
          // Payment routes
          GoRoute(
            path: '/payments',
            builder: (context, state) => const PaymentDemoScreen(),
            routes: [
              GoRoute(
                path: '/sgqr',
                builder: (context, state) => const PaymentDemoScreen(),
              ),
            ],
          ),
          
          // Customer routes
          GoRoute(
            path: '/customers',
            builder: (context, state) => const ProfessionalCustomerListScreen(),
            routes: [
              GoRoute(
                path: '/create',
                builder: (context, state) => const ProfessionalCustomerFormScreen(),
              ),
              GoRoute(
                path: '/edit/:id',
                builder: (context, state) => ProfessionalCustomerFormScreen(
                  customerId: state.pathParameters['id'],
                ),
              ),
              GoRoute(
                path: '/detail/:id',
                builder: (context, state) => CustomerDetailScreenWrapper(
                  customerId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: '/statements',
                builder: (context, state) => const CustomerStatementsScreen(),
              ),
            ],
          ),
          
          // Employee routes
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeeListScreenWrapper(),
            routes: [
              GoRoute(
                path: '/create',
                builder: (context, state) => const EmployeeFormScreenWrapper(),
              ),
              GoRoute(
                path: '/:id/edit',
                builder: (context, state) => EmployeeFormScreenWrapper(
                  employeeId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: '/payroll',
                builder: (context, state) => const PayrollScreenWrapper(),
              ),
              GoRoute(
                path: '/reports',
                builder: (context, state) => const EmployeeReportsScreen(),
              ),
              GoRoute(
                path: '/cpf-calculator',
                builder: (context, state) => const CpfCalculatorScreenWrapper(),
              ),
            ],
          ),
          
          // Payroll routes  
          GoRoute(
            path: '/payroll',
            builder: (context, state) => const PayrollScreenWrapper(),
          ),
          
          // Tax routes
          GoRoute(
            path: '/tax',
            builder: (context, state) => const TaxDashboardScreen(),
            routes: [
              GoRoute(
                path: '/calculator',
                builder: (context, state) => const TaxCalculatorScreenWrapper(),
              ),
              GoRoute(
                path: '/settings',
                builder: (context, state) => const TaxSettingsScreen(),
              ),
            ],
          ),
          
          // Reports routes
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsDashboardScreen(),
            routes: [
              GoRoute(
                path: '/sales',
                builder: (context, state) => const SalesReportScreen(),
              ),
              GoRoute(
                path: '/tax',
                builder: (context, state) => const TaxReportScreen(),
              ),
              GoRoute(
                path: '/financial',
                builder: (context, state) => const FinancialReportScreen(),
              ),
              GoRoute(
                path: '/forecasting',
                builder: (context, state) => const ForecastingReportScreenWrapper(),
              ),
            ],
          ),
          
          // Inventory routes
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryListScreen(),
            routes: [
              GoRoute(
                path: '/create',
                builder: (context, state) => const ProductFormScreen(),
              ),
              GoRoute(
                path: '/edit/:id',
                builder: (context, state) => ProductFormScreen(
                  productId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          
          // Vendor routes
          GoRoute(
            path: '/vendors',
            builder: (context, state) => const VendorListScreen(),
            routes: [
              GoRoute(
                path: '/create',
                builder: (context, state) => const VendorFormScreen(),
              ),
              GoRoute(
                path: '/edit/:id',
                builder: (context, state) => VendorFormScreen(
                  vendorId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
          
          // Sync routes
          GoRoute(
            path: '/sync',
            builder: (context, state) => const DeviceDiscoveryScreen(),
          ),
          
          // Backup routes
          GoRoute(
            path: '/backup',
            builder: (context, state) => const BackupScreen(),
          ),
          
          // Notification routes
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationCenterScreen(),
          ),
          
          // Forecasting routes
          GoRoute(
            path: '/forecasting',
            builder: (context, state) => const ForecastingDashboardScreen(),
            routes: [
              GoRoute(
                path: '/revenue',
                builder: (context, state) => const RevenueForecastingScreen(),
              ),
              GoRoute(
                path: '/expenses',
                builder: (context, state) => const RevenueForecastingScreen(), // Reuse for now
              ),
              GoRoute(
                path: '/cashflow',
                builder: (context, state) => const RevenueForecastingScreen(), // Reuse for now
              ),
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const RevenueForecastingScreen(), // Reuse for now
              ),
              GoRoute(
                path: '/reports',
                builder: (context, state) => const FinancialReportsScreen(),
              ),
            ],
          ),
          
          // Settings routes
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: '/developer',
                builder: (context, state) => const DeveloperSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

// Wrapper widgets to handle dependency injection
class InvoiceListScreenWrapper extends StatelessWidget {
  const InvoiceListScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const FunctionalInvoiceListScreen();
  }
}

class FunctionalInvoiceListScreen extends StatefulWidget {
  const FunctionalInvoiceListScreen({super.key});

  @override
  State<FunctionalInvoiceListScreen> createState() => _FunctionalInvoiceListScreenState();
}

class _FunctionalInvoiceListScreenState extends State<FunctionalInvoiceListScreen> {
  List<EnhancedInvoice> _invoices = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load real invoices from demo service (replace with actual database service when available)
      final demoService = DemoDataService();
      if (!demoService.isInitialized) {
        await demoService.initializeDemoData();
      }
      _invoices = demoService.invoices;
    } catch (e) {
      print('Error loading invoices: $e');
      _invoices = []; // Fallback to empty list
    }

    setState(() {
      _isLoading = false;
    });
  }

  List<EnhancedInvoice> get _filteredInvoices {
    if (_filter == 'all') return _invoices;
    return _invoices.where((inv) => inv.status.toString().contains(_filter)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Invoices')),
              const PopupMenuItem(value: 'draft', child: Text('Draft')),
              const PopupMenuItem(value: 'sent', child: Text('Sent')),
              const PopupMenuItem(value: 'paid', child: Text('Paid')),
              const PopupMenuItem(value: 'overdue', child: Text('Overdue')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInvoices,
              child: _invoices.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No invoices found', style: TextStyle(fontSize: 18)),
                          Text('Create your first invoice to get started'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredInvoices.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final invoice = _filteredInvoices[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(invoice.status).withOpacity(0.1),
                              child: Icon(_getStatusIcon(invoice.status), color: _getStatusColor(invoice.status)),
                            ),
                            title: Text(invoice.invoiceNumber),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(invoice.customerName),
                                Text('Due: ${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year}'),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${invoice.total.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(invoice.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(invoice.status),
                                    style: TextStyle(
                                      color: _getStatusColor(invoice.status),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => context.go('/invoices/detail/${invoice.id}'),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/invoices/create'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return Colors.grey;
      case InvoiceStatus.pending: return Colors.orange;
      case InvoiceStatus.approved: return Colors.blue;
      case InvoiceStatus.sent: return Colors.blue;
      case InvoiceStatus.viewed: return Colors.cyan;
      case InvoiceStatus.partiallyPaid: return Colors.amber;
      case InvoiceStatus.paid: return Colors.green;
      case InvoiceStatus.overdue: return Colors.red;
      case InvoiceStatus.cancelled: return Colors.orange;
      case InvoiceStatus.disputed: return Colors.purple;
      case InvoiceStatus.voided: return Colors.grey[800]!;
      case InvoiceStatus.refunded: return Colors.teal;
    }
  }

  IconData _getStatusIcon(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return Icons.drafts;
      case InvoiceStatus.pending: return Icons.hourglass_empty;
      case InvoiceStatus.approved: return Icons.check;
      case InvoiceStatus.sent: return Icons.send;
      case InvoiceStatus.viewed: return Icons.visibility;
      case InvoiceStatus.partiallyPaid: return Icons.payments;
      case InvoiceStatus.paid: return Icons.check_circle;
      case InvoiceStatus.overdue: return Icons.warning;
      case InvoiceStatus.cancelled: return Icons.cancel;
      case InvoiceStatus.disputed: return Icons.report_problem;
      case InvoiceStatus.voided: return Icons.block;
      case InvoiceStatus.refunded: return Icons.undo;
    }
  }

  String _getStatusText(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return 'Draft';
      case InvoiceStatus.pending: return 'Pending';
      case InvoiceStatus.approved: return 'Approved';
      case InvoiceStatus.sent: return 'Sent';
      case InvoiceStatus.viewed: return 'Viewed';
      case InvoiceStatus.partiallyPaid: return 'Partially Paid';
      case InvoiceStatus.paid: return 'Paid';
      case InvoiceStatus.overdue: return 'Overdue';
      case InvoiceStatus.cancelled: return 'Cancelled';
      case InvoiceStatus.disputed: return 'Disputed';
      case InvoiceStatus.voided: return 'Voided';
      case InvoiceStatus.refunded: return 'Refunded';
    }
  }
}

class InvoiceFormScreenWrapper extends StatelessWidget {
  final String? invoiceId;
  
  const InvoiceFormScreenWrapper({super.key, this.invoiceId});

  @override
  Widget build(BuildContext context) {
    // Get prefilled data from navigation extra if available
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    
    return ProfessionalInvoiceFormScreen(
      // Pass any prefilled data to the form or the provided invoiceId
      invoiceId: invoiceId ?? extra?['invoice_id'],
    );
  }
}

class InvoiceDetailScreenWrapper extends StatelessWidget {
  final String invoiceId;
  
  const InvoiceDetailScreenWrapper({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    return FunctionalInvoiceDetailScreen(invoiceId: invoiceId);
  }
}

class FunctionalInvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  
  const FunctionalInvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<FunctionalInvoiceDetailScreen> createState() => _FunctionalInvoiceDetailScreenState();
}

class _FunctionalInvoiceDetailScreenState extends State<FunctionalInvoiceDetailScreen> {
  EnhancedInvoice? _invoice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load real invoice from demo service (replace with actual database service when available)
      final demoService = DemoDataService();
      if (!demoService.isInitialized) {
        await demoService.initializeDemoData();
      }
      _invoice = demoService.getInvoiceById(widget.invoiceId);
    } catch (e) {
      print('Error loading invoice: $e');
      _invoice = null; // Fallback to null
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice?.invoiceNumber ?? 'Invoice Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_invoice != null)
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'sgqr',
                  child: Row(
                    children: [
                      Icon(Icons.qr_code),
                      SizedBox(width: 8),
                      Text('Generate SGQR'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share),
                      SizedBox(width: 8),
                      Text('Share Invoice'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'sgqr') {
                  context.go('/payments/sgqr');
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoice == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Invoice not found', style: TextStyle(fontSize: 18)),
                      Text('The requested invoice could not be loaded'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _invoice!.invoiceNumber,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_invoice!.status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      _getStatusText(_invoice!.status),
                                      style: TextStyle(
                                        color: _getStatusColor(_invoice!.status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Invoice Date', style: Theme.of(context).textTheme.bodySmall),
                                        Text('${_invoice!.invoiceDate.day}/${_invoice!.invoiceDate.month}/${_invoice!.invoiceDate.year}'),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Due Date', style: Theme.of(context).textTheme.bodySmall),
                                        Text('${_invoice!.dueDate.day}/${_invoice!.dueDate.month}/${_invoice!.dueDate.year}'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Customer Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bill To',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(_invoice!.customerName, style: const TextStyle(fontWeight: FontWeight.w500)),
                              if (_invoice!.customerEmail?.isNotEmpty == true) Text(_invoice!.customerEmail!),
                              if (_invoice!.customerAddress?.isNotEmpty == true) 
                                Text(_invoice!.customerAddress!, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Items Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Items',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // TODO: Implement line items display for CRDTInvoiceEnhanced
                              // Items section temporarily commented out until proper implementation
                              /*...(_invoice!.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.description, style: const TextStyle(fontWeight: FontWeight.w500)),
                                          Text('${item.quantity} × \$${item.unitPrice.toStringAsFixed(2)}', 
                                               style: Theme.of(context).textTheme.bodySmall),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '\$${item.total.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ))),*/
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Total Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal'),
                                  Text('\$${_invoice!.subtotal.toStringAsFixed(2)}'),
                                ],
                              ),
                              if (_invoice!.gstAmount > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('GST (9%)'),
                                    Text('\$${_invoice!.gstAmount.toStringAsFixed(2)}'),
                                  ],
                                ),
                              ],
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\$${_invoice!.total.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_invoice!.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        Card(
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
                                const SizedBox(height: 8),
                                Text(_invoice!.notes!),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return Colors.grey;
      case InvoiceStatus.pending: return Colors.orange;
      case InvoiceStatus.approved: return Colors.blue;
      case InvoiceStatus.sent: return Colors.blue;
      case InvoiceStatus.viewed: return Colors.cyan;
      case InvoiceStatus.partiallyPaid: return Colors.amber;
      case InvoiceStatus.paid: return Colors.green;
      case InvoiceStatus.overdue: return Colors.red;
      case InvoiceStatus.cancelled: return Colors.orange;
      case InvoiceStatus.disputed: return Colors.purple;
      case InvoiceStatus.voided: return Colors.grey[800]!;
      case InvoiceStatus.refunded: return Colors.teal;
    }
  }

  String _getStatusText(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return 'Draft';
      case InvoiceStatus.pending: return 'Pending';
      case InvoiceStatus.approved: return 'Approved';
      case InvoiceStatus.sent: return 'Sent';
      case InvoiceStatus.viewed: return 'Viewed';
      case InvoiceStatus.partiallyPaid: return 'Partially Paid';
      case InvoiceStatus.paid: return 'Paid';
      case InvoiceStatus.overdue: return 'Overdue';
      case InvoiceStatus.cancelled: return 'Cancelled';
      case InvoiceStatus.disputed: return 'Disputed';
      case InvoiceStatus.voided: return 'Voided';
      case InvoiceStatus.refunded: return 'Refunded';
    }
  }
}

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people, size: 64, color: Colors.purple),
          const SizedBox(height: 16),
          const Text('Customers', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Manage your customers'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/customers/create'),
            child: const Text('Add Customer'),
          ),
        ],
      ),
    );
  }
}

class CustomerFormScreen extends StatelessWidget {
  final String? customerId;
  
  const CustomerFormScreen({super.key, this.customerId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add, size: 64, color: Colors.teal),
          const SizedBox(height: 16),
          Text(
            customerId == null ? 'Add Customer' : 'Edit Customer',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (customerId != null) Text('Customer ID: $customerId'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              // Navigate to actual customer form
              context.go('/customers/create');
            },
            child: const Text('Create Customer Form'),
          ),
        ],
      ),
    );
  }
}

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Employee> _employees = [];
  bool _isLoading = true;
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load demo employees for now - replace with real service when fully implemented
      _employees = [
        Employee(
          id: '1',
          name: 'John Doe',
          position: 'Software Engineer',
          email: 'john@example.com',
          phone: '+65 9123 4567',
          workPassType: 'Employment Pass',
          nric: 'G1234567X',
          basicSalary: 8000.0,
          cpfContribution: 1600.0,
          joinDate: DateTime(2023, 1, 15),
        ),
        Employee(
          id: '2',
          name: 'Jane Smith',
          position: 'Product Manager',
          email: 'jane@example.com',
          phone: '+65 9234 5678',
          workPassType: 'Citizen',
          nric: 'S9876543A',
          basicSalary: 9500.0,
          cpfContribution: 1900.0,
          joinDate: DateTime(2022, 8, 10),
        ),
        Employee(
          id: '3',
          name: 'Bob Wilson',
          position: 'Designer',
          email: 'bob@example.com',
          phone: '+65 9345 6789',
          workPassType: 'Permanent Resident',
          nric: 'T8765432B',
          basicSalary: 7200.0,
          cpfContribution: 1440.0,
          joinDate: DateTime(2023, 6, 20),
        ),
      ];
      _sortEmployees();
    } catch (e) {
      print('Error loading employees: $e');
      _employees = []; // Fallback to empty list
      _sortEmployees();
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _sortEmployees() {
    switch (_sortBy) {
      case 'name':
        _employees.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'position':
        _employees.sort((a, b) => a.position.compareTo(b.position));
        break;
      case 'salary':
        _employees.sort((a, b) => b.basicSalary.compareTo(a.basicSalary));
        break;
      case 'joinDate':
        _employees.sort((a, b) => b.joinDate.compareTo(a.joinDate));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _sortEmployees();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(value: 'position', child: Text('Sort by Position')),
              const PopupMenuItem(value: 'salary', child: Text('Sort by Salary')),
              const PopupMenuItem(value: 'joinDate', child: Text('Sort by Join Date')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEmployees,
              child: _employees.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No employees found', style: TextStyle(fontSize: 18)),
                          Text('Add employees to get started'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _employees.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final employee = _employees[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getWorkPassColor(employee.workPassType).withOpacity(0.1),
                              child: Text(
                                employee.name.split(' ').map((n) => n[0]).take(2).join(),
                                style: TextStyle(
                                  color: _getWorkPassColor(employee.workPassType),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(employee.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(employee.position),
                                Text(employee.workPassDisplayName, style: Theme.of(context).textTheme.bodySmall),
                                Text('Joined: ${employee.joinDate.day}/${employee.joinDate.month}/${employee.joinDate.year}',
                                     style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  employee.formattedSalary,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'CPF: ${employee.formattedCpf}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: employee.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    employee.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: employee.isActive ? Colors.green : Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showEmployeeDetails(context, employee),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add Employee feature coming soon!')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getWorkPassColor(String workPassType) {
    switch (workPassType.toLowerCase()) {
      case 'citizen':
        return Colors.green;
      case 'permanent resident':
        return Colors.blue;
      case 'employment pass':
        return Colors.purple;
      case 's pass':
        return Colors.orange;
      case 'work permit':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showEmployeeDetails(BuildContext context, Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Position', employee.position),
              _DetailRow('Email', employee.email),
              _DetailRow('Phone', employee.phone),
              _DetailRow('Work Pass', employee.workPassDisplayName),
              _DetailRow('NRIC/FIN', employee.nric),
              _DetailRow('Basic Salary', employee.formattedSalary),
              _DetailRow('CPF Contribution', employee.formattedCpf),
              _DetailRow('Years of Service', '${employee.yearsOfService} years'),
              _DetailRow('Leave Balance', '${employee.leaveBalance} days'),
              _DetailRow('Status', employee.isActive ? 'Active' : 'Inactive'),
            ],
          ),
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
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.payments, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text('Payroll', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Manage employee payroll'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/employees/payroll'),
            child: const Text('Open Payroll Management'),
          ),
        ],
      ),
    );
  }
}

class LeaveManagementScreen extends StatelessWidget {
  const LeaveManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 64, color: Colors.amber),
          const SizedBox(height: 16),
          const Text('Leave Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Manage employee leave'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/employees/leave'),
            child: const Text('Open Leave Management'),
          ),
        ],
      ),
    );
  }
}

class TaxSettingsScreen extends StatelessWidget {
  const TaxSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GST Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('GST Registered'),
                      subtitle: const Text('Enable if your business is GST registered'),
                      value: true, // This would come from settings
                      onChanged: (value) {
                        // Update GST registration status
                      },
                    ),
                    const ListTile(
                      title: Text('GST Rate'),
                      subtitle: Text('Current rate: 9%'),
                      trailing: Icon(Icons.edit),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax Compliance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const ListTile(
                      leading: Icon(Icons.schedule, color: Colors.orange),
                      title: Text('Filing Frequency'),
                      subtitle: Text('Quarterly'),
                      trailing: Icon(Icons.edit),
                    ),
                    const ListTile(
                      leading: Icon(Icons.notification_important, color: Colors.blue),
                      title: Text('Reminder Settings'),
                      subtitle: Text('Notify 7 days before due dates'),
                      trailing: Icon(Icons.edit),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaxCalculatorScreenWrapper extends StatelessWidget {
  const TaxCalculatorScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Get calculation parameters from navigation extra if available
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    // TODO: Use extra parameters when implementing advanced tax calculations
    
    return const TaxCalculatorScreen(
      calculatorType: CalculatorType.gst,
    );
  }
}

// Employee management wrapper classes
class EmployeeListScreenWrapper extends StatelessWidget {
  const EmployeeListScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Import the actual screen from the employees feature
    return const EmployeeListScreen();
  }
}

class EmployeeFormScreenWrapper extends StatefulWidget {
  final String? employeeId;
  
  const EmployeeFormScreenWrapper({super.key, this.employeeId});

  @override
  State<EmployeeFormScreenWrapper> createState() => _EmployeeFormScreenWrapperState();
}

class _EmployeeFormScreenWrapperState extends State<EmployeeFormScreenWrapper> {
  CRDTEmployee? employee;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.employeeId != null) {
      _loadEmployee();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadEmployee() async {
    try {
      final employeeService = EmployeeService(NotificationService());
      employee = employeeService.getEmployeeById(widget.employeeId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading employee: $e')),
        );
      }
    }
    
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Import the actual form screen from the employees feature
    return EmployeeFormScreen(employee: employee);
  }
}

class PayrollScreenWrapper extends StatelessWidget {
  const PayrollScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Import the actual screen from the employees feature
    return const PayrollScreen();
  }
}

// Placeholder wrapper classes for missing screens
class CustomerDetailScreenWrapper extends StatelessWidget {
  final String customerId;
  
  const CustomerDetailScreenWrapper({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 64, color: Colors.purple.withOpacity(0.7)),
            const SizedBox(height: 16),
            const Text('Customer Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Customer ID: $customerId', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Coming Soon', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/customers'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Customers'),
            ),
          ],
        ),
      ),
    );
  }
}

class CpfCalculatorScreenWrapper extends StatelessWidget {
  const CpfCalculatorScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CPF Calculator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calculate, size: 64, color: Colors.blue.withOpacity(0.7)),
            const SizedBox(height: 16),
            const Text('CPF Calculator', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Calculate CPF contributions for employees', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Coming Soon', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/employees'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Employees'),
            ),
          ],
        ),
      ),
    );
  }
}

class ForecastingReportScreenWrapper extends StatelessWidget {
  const ForecastingReportScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forecasting Reports'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: Colors.green.withOpacity(0.7)),
            const SizedBox(height: 16),
            const Text('Forecasting Reports', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Advanced forecasting and trend analysis', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Coming Soon', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/reports'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Reports'),
            ),
          ],
        ),
      ),
    );
  }
}