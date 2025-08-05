import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/customer.dart';
import '../repositories/customer_repository.dart';
import '../../../core/utils/date_utils.dart' as app_date_utils;

class CustomerDetailsScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
  });

  @override
  ConsumerState<CustomerDetailsScreen> createState() =>
      _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends ConsumerState<CustomerDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Customer? _customer;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCustomer();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final repository = ref.read(customerRepositoryProvider);
      final customer = await repository.getCustomer(widget.customerId);

      setState(() {
        _customer = customer;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete ${_customer?.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repository = ref.read(customerRepositoryProvider);
        await repository.deleteCustomer(widget.customerId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer deleted successfully')),
          );
          context.go('/customers');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting customer: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.name ?? 'Customer Details'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          if (_customer != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/customers/${widget.customerId}/edit'),
              tooltip: 'Edit Customer',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    _showDeleteConfirmation();
                    break;
                  case 'create_invoice':
                    context.go('/invoices/create?customerId=${widget.customerId}');
                    break;
                  case 'view_invoices':
                    context.go('/invoices?customerId=${widget.customerId}');
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'create_invoice',
                  child: ListTile(
                    leading: Icon(Icons.receipt_long),
                    title: Text('Create Invoice'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'view_invoices',
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('View Invoices'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete Customer', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
        bottom: _customer != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.info), text: 'Details'),
                  Tab(icon: Icon(Icons.receipt_long), text: 'Invoices'),
                  Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading customer details...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Customer',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadCustomer,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_customer == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: Colors.grey.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Customer Not Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'The requested customer could not be found.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/customers'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Customers'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildDetailsTab(),
        _buildInvoicesTab(),
        _buildAnalyticsTab(),
      ],
    );
  }

  Widget _buildDetailsTab() {
    final customer = _customer!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: customer.isActive 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    child: Icon(
                      customer.isActive ? Icons.check : Icons.close,
                      color: customer.isActive ? Colors.green : Colors.red,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          customer.isActive ? 'Active Customer' : 'Inactive Customer',
                          style: TextStyle(
                            color: customer.isActive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Customer ID: ${customer.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyToClipboard(customer.id, 'Customer ID'),
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy Customer ID',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Contact Information
          _buildSectionCard(
            'Contact Information',
            Icons.contact_phone,
            [
              if (customer.email != null)
                _buildInfoTile(
                  'Email',
                  customer.email!,
                  Icons.email,
                  onTap: () => _copyToClipboard(customer.email!, 'Email'),
                ),
              if (customer.phone != null)
                _buildInfoTile(
                  'Phone',
                  customer.phone!,
                  Icons.phone,
                  onTap: () => _copyToClipboard(customer.phone!, 'Phone'),
                ),
              if (customer.address != null)
                _buildInfoTile(
                  'Address',
                  customer.address!,
                  Icons.location_on,
                  onTap: () => _copyToClipboard(customer.address!, 'Address'),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Business Information
          _buildSectionCard(
            'Business Information',
            Icons.business,
            [
              _buildInfoTile(
                'Country',
                customer.countryCode ?? 'SG',
                Icons.flag,
              ),
              if (customer.uen != null)
                _buildInfoTile(
                  'UEN',
                  customer.uen!,
                  Icons.business_center,
                  onTap: () => _copyToClipboard(customer.uen!, 'UEN'),
                ),
              _buildInfoTile(
                'GST Status',
                customer.gstStatusDisplay,
                Icons.account_balance_wallet,
                subtitle: customer.isExportCustomer ? 'Export Customer' : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Billing & Shipping
          if (customer.billingAddress != null || customer.shippingAddress != null)
            _buildSectionCard(
              'Addresses',
              Icons.location_city,
              [
                if (customer.billingAddress != null)
                  _buildInfoTile(
                    'Billing Address',
                    customer.billingAddress!,
                    Icons.receipt_long,
                    onTap: () => _copyToClipboard(customer.billingAddress!, 'Billing Address'),
                  ),
                if (customer.shippingAddress != null)
                  _buildInfoTile(
                    'Shipping Address',
                    customer.shippingAddress!,
                    Icons.local_shipping,
                    onTap: () => _copyToClipboard(customer.shippingAddress!, 'Shipping Address'),
                  ),
              ],
            ),

          const SizedBox(height: 16),

          // Metadata
          _buildSectionCard(
            'Record Information',
            Icons.info,
            [
              _buildInfoTile(
                'Created',
                app_date_utils.formatDateTime(customer.createdAt),
                Icons.calendar_today,
              ),
              _buildInfoTile(
                'Last Updated',
                app_date_utils.formatDateTime(customer.updatedAt),
                Icons.update,
              ),
              _buildInfoTile(
                'Sync Status',
                _getSyncStatusText(customer.syncStatus),
                Icons.sync,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Customer Invoices',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Invoice history and management will be displayed here',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Text(
            'Feature coming in next update',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Customer Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Revenue trends, payment patterns, and insights will be displayed here',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Text(
            'Feature coming in next update',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value,
    IconData icon, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy $label',
            ),
        ],
      ),
    );
  }

  String _getSyncStatusText(int syncStatus) {
    switch (syncStatus) {
      case 0:
        return 'Synced';
      case 1:
        return 'Pending Sync';
      case 2:
        return 'Sync Failed';
      default:
        return 'Unknown';
    }
  }
}