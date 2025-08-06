import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/offline/offline_service.dart';
import '../../../core/feedback/haptic_service.dart';
import '../../../core/notifications/enhanced_push_notification_service.dart';
import '../../../core/shortcuts/quick_actions_service.dart';
import '../../../core/gestures/swipe_gesture_handler.dart';
import '../../../core/performance/performance_optimizer.dart';
import '../../invoices/widgets/enhanced_invoice_list_item.dart';
import '../../settings/screens/mobile_features_settings_screen.dart';

class EnhancedMobileDashboard extends ConsumerStatefulWidget {
  const EnhancedMobileDashboard({super.key});

  @override
  ConsumerState<EnhancedMobileDashboard> createState() =>
      _EnhancedMobileDashboardState();
}

class _EnhancedMobileDashboardState
    extends ConsumerState<EnhancedMobileDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAuthentication();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAuthentication() async {
    final biometricService = ref.read(biometricAuthServiceProvider);

    if (biometricService.config.enabled &&
        biometricService.config.requireForAppLaunch) {
      setState(() {
        _isAuthenticating = true;
      });

      final result = await biometricService.authenticateForAppLaunch();

      if (!result) {
        // Authentication failed - could show error or exit app
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fingerprint,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Authenticating...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Please authenticate to access BizSync',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return QuickActionHandler(
      onQuickAction: _handleQuickAction,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BizSync Dashboard'),
          actions: [
            _buildConnectionStatusIndicator(),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                ref.read(hapticServiceProvider).buttonTap();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MobileFeaturesSettingsScreen(),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Invoices'),
              Tab(icon: Icon(Icons.people), text: 'Customers'),
              Tab(icon: Icon(Icons.analytics), text: 'Reports'),
            ],
          ),
        ),
        body: TabSwipeNavigator(
          initialIndex: _tabController.index,
          onPageChanged: (index) {
            _tabController.animateTo(index);
          },
          children: const [
            _OverviewTab(),
            _InvoicesTab(),
            _CustomersTab(),
            _ReportsTab(),
          ],
        ),
        floatingActionButton: QuickActionsFAB(
          onActionSelected: _handleQuickAction,
        ),
      ),
    );
  }

  Widget _buildConnectionStatusIndicator() {
    return Consumer(
      builder: (context, ref, child) {
        final connectionStatus = ref.watch(connectionStatusProvider);
        final syncStats = ref.watch(syncStatsProvider);

        if (connectionStatus == ConnectionStatus.online &&
            syncStats.pendingOperations == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Badge(
              label: Text('${syncStats.pendingOperations}'),
              isLabelVisible: syncStats.pendingOperations > 0,
              child: Icon(
                connectionStatus == ConnectionStatus.online
                    ? Icons.sync_problem
                    : Icons.cloud_off,
                color: connectionStatus == ConnectionStatus.online
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
            onPressed: () {
              ref.read(hapticServiceProvider).buttonTap();
              _showSyncDialog();
            },
          ),
        );
      },
    );
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final connectionStatus = ref.watch(connectionStatusProvider);
          final syncStats = ref.watch(syncStatsProvider);
          final offlineService = ref.watch(offlineServiceProvider);

          return AlertDialog(
            title: const Text('Sync Status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      connectionStatus == ConnectionStatus.online
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      color: connectionStatus == ConnectionStatus.online
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connectionStatus == ConnectionStatus.online
                          ? 'Online'
                          : 'Offline',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Pending operations: ${syncStats.pendingOperations}'),
                Text('Completed operations: ${syncStats.completedOperations}'),
                Text('Failed operations: ${syncStats.failedOperations}'),
                if (syncStats.lastSyncTime != null)
                  Text(
                      'Last sync: ${_formatDateTime(syncStats.lastSyncTime!)}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (connectionStatus == ConnectionStatus.online)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    offlineService.forcSync();
                    ref.read(hapticServiceProvider).dataSync();
                  },
                  child: const Text('Force Sync'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _handleQuickAction(QuickActionType actionType) {
    final hapticService = ref.read(hapticServiceProvider);

    switch (actionType) {
      case QuickActionType.createInvoice:
        hapticService.buttonTap();
        // Navigate to create invoice screen
        _showSnackBar('Creating new invoice...');
        break;
      case QuickActionType.addCustomer:
        hapticService.buttonTap();
        // Navigate to add customer screen
        _showSnackBar('Adding new customer...');
        break;
      case QuickActionType.addProduct:
        hapticService.buttonTap();
        // Navigate to add product screen
        _showSnackBar('Adding new product...');
        break;
      case QuickActionType.viewReports:
        hapticService.buttonTap();
        _tabController.animateTo(3); // Reports tab
        break;
      case QuickActionType.syncData:
        hapticService.dataSync();
        ref.read(offlineServiceProvider).forcSync();
        _showSnackBar('Syncing data...');
        break;
      case QuickActionType.scanReceipt:
        // This would be implemented if camera integration was included
        _showSnackBar('Scan receipt feature coming soon...');
        break;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PullToRefreshWrapper(
      onRefresh: () async {
        // Simulate refresh
        await Future.delayed(const Duration(seconds: 2));
        ref.read(hapticServiceProvider).successAction();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ConnectionStatusIndicator(),
            SmoothAnimationWrapper(
              child: _buildMetricCard(
                'Total Revenue',
                '\$25,430.50',
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            SmoothAnimationWrapper(
              duration: const Duration(milliseconds: 400),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Pending Invoices',
                      '12',
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      'Paid This Month',
                      '28',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SmoothAnimationWrapper(
              duration: const Duration(milliseconds: 600),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildQuickActionCard(
                    'Create Invoice',
                    Icons.description_outlined,
                    Colors.blue,
                    () => ref.read(hapticServiceProvider).buttonTap(),
                  ),
                  _buildQuickActionCard(
                    'Add Customer',
                    Icons.person_add_outlined,
                    Colors.green,
                    () => ref.read(hapticServiceProvider).buttonTap(),
                  ),
                  _buildQuickActionCard(
                    'View Reports',
                    Icons.analytics_outlined,
                    Colors.purple,
                    () => ref.read(hapticServiceProvider).buttonTap(),
                  ),
                  _buildQuickActionCard(
                    'Sync Data',
                    Icons.sync_outlined,
                    Colors.orange,
                    () {
                      ref.read(hapticServiceProvider).dataSync();
                      ref.read(offlineServiceProvider).forcSync();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoicesTab extends ConsumerWidget {
  const _InvoicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock invoice data
    final mockInvoices = List.generate(
        20,
        (index) => InvoiceModel(
              id: 'inv_$index',
              invoiceNumber: 'INV-${1000 + index}',
              customerName: 'Customer ${index + 1}',
              total: 100.0 + (index * 25.5),
              paidAmount: index % 3 == 0 ? 100.0 + (index * 25.5) : 0.0,
              status: index % 4 == 0
                  ? InvoiceStatus.paid
                  : index % 4 == 1
                      ? InvoiceStatus.sent
                      : index % 4 == 2
                          ? InvoiceStatus.viewed
                          : InvoiceStatus.overdue,
              issueDate: DateTime.now().subtract(Duration(days: index)),
              dueDate: DateTime.now().add(Duration(days: 30 - index)),
            ));

    return Column(
      children: [
        const ConnectionStatusIndicator(),
        Expanded(
          child: EnhancedInvoiceListView(
            invoices: mockInvoices,
            onInvoiceTap: (invoice) {
              ref.read(hapticServiceProvider).buttonTap();
              // Navigate to invoice detail
            },
            onInvoiceEdit: (invoice) {
              // Navigate to edit invoice
            },
            onInvoiceDelete: (invoice) {
              // Delete invoice
            },
            onInvoiceShare: (invoice) {
              // Share invoice
            },
            onInvoiceMarkPaid: (invoice) {
              // Mark invoice as paid
            },
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 2));
              ref.read(hapticServiceProvider).successAction();
            },
          ),
        ),
      ],
    );
  }
}

class _CustomersTab extends ConsumerWidget {
  const _CustomersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PullToRefreshWrapper(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 2));
        ref.read(hapticServiceProvider).successAction();
      },
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Customers Tab',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            Text('Enhanced customer list would go here'),
          ],
        ),
      ),
    );
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PullToRefreshWrapper(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 2));
        ref.read(hapticServiceProvider).successAction();
      },
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Reports Tab',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            Text('Business reports and analytics would go here'),
          ],
        ),
      ),
    );
  }
}

// Mock invoice model for demonstration
class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String customerName;
  final double total;
  final double paidAmount;
  final InvoiceStatus status;
  final DateTime issueDate;
  final DateTime dueDate;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.total,
    required this.paidAmount,
    required this.status,
    required this.issueDate,
    required this.dueDate,
  });
}

enum InvoiceStatus {
  draft,
  sent,
  viewed,
  partiallyPaid,
  paid,
  overdue,
  cancelled,
}
