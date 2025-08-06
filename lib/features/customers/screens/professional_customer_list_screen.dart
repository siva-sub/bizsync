import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../data/models/customer.dart';
import '../repositories/customer_repository.dart';

class ProfessionalCustomerListScreen extends ConsumerStatefulWidget {
  const ProfessionalCustomerListScreen({super.key});

  @override
  ConsumerState<ProfessionalCustomerListScreen> createState() =>
      _ProfessionalCustomerListScreenState();
}

class _ProfessionalCustomerListScreenState
    extends ConsumerState<ProfessionalCustomerListScreen> {
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(customerRepositoryProvider);
      _customers = await repository.getCustomers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customers: $e')),
        );
      }
    }

    _applyFilters();
    setState(() => _isLoading = false);
  }

  void _applyFilters() {
    _filteredCustomers = _customers.where((customer) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return customer.name.toLowerCase().contains(query) ||
            (customer.email?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadCustomers,
        child: Column(
          children: [
            // Header with search
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: SearchBar(
                        hintText: 'Search customers...',
                        leading: const Icon(Icons.search),
                        onChanged: _onSearchChanged,
                        trailing: [
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _onSearchChanged(''),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => context.go('/customers/create'),
                      icon: const Icon(Icons.add),
                      label: const Text('New Customer'),
                    ),
                  ],
                ),
              ),
            ),

            // Results summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_filteredCustomers.length} of ${_customers.length} customers',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const Spacer(),
                  if (_isLoading) const CircularProgressIndicator.adaptive(),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Data table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCustomers.isEmpty
                      ? _buildEmptyState()
                      : Card(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            minWidth: 800,
                            columns: const [
                              DataColumn2(
                                label: Text('Customer'),
                                size: ColumnSize.L,
                              ),
                              DataColumn2(
                                label: Text('Contact'),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text('UEN'),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text('Status'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('Created'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('Actions'),
                                size: ColumnSize.S,
                              ),
                            ],
                            rows: _filteredCustomers.map((customer) {
                              return DataRow2(
                                onTap: () => _showCustomerDetails(customer),
                                cells: [
                                  DataCell(
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          customer.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          customer.email ?? 'No email',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(customer.phone ?? 'No phone'),
                                        Text(
                                          customer.gstStatusDisplay,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(customer.uen ?? 'No UEN')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: customer.isActive
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        customer.isActive
                                            ? 'Active'
                                            : 'Inactive',
                                        style: TextStyle(
                                          color: customer.isActive
                                              ? Colors.green
                                              : Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${customer.createdAt.day}/${customer.createdAt.month}/${customer.createdAt.year}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon:
                                              const Icon(Icons.edit, size: 20),
                                          onPressed: () => context.go(
                                              '/customers/edit/${customer.id}'),
                                          tooltip: 'Edit Customer',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.more_vert,
                                              size: 20),
                                          onPressed: () =>
                                              _showCustomerActions(customer),
                                          tooltip: 'More Actions',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No customers found' : 'No customers yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search'
                : 'Add your first customer to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty)
            FilledButton.icon(
              onPressed: () => context.go('/customers/create'),
              icon: const Icon(Icons.add),
              label: const Text('Add Customer'),
            ),
        ],
      ),
    );
  }

  void _showCustomerDetails(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Email', customer.email ?? 'Not provided'),
              _DetailRow('Phone', customer.phone ?? 'Not provided'),
              _DetailRow('Address', customer.address ?? 'Not provided'),
              _DetailRow(
                  'Billing Address', customer.billingAddress ?? 'Not provided'),
              _DetailRow('Shipping Address',
                  customer.shippingAddress ?? 'Not provided'),
              _DetailRow('UEN', customer.uen ?? 'Not provided'),
              _DetailRow('Country', customer.countryCode ?? 'Not specified'),
              _DetailRow('GST Status', customer.gstStatusDisplay),
              _DetailRow('Status', customer.isActive ? 'Active' : 'Inactive'),
              _DetailRow('Created',
                  '${customer.createdAt.day}/${customer.createdAt.month}/${customer.createdAt.year}'),
              _DetailRow('Last Updated',
                  '${customer.updatedAt.day}/${customer.updatedAt.month}/${customer.updatedAt.year}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/customers/edit/${customer.id}');
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showCustomerActions(Customer customer) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Create Invoice'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to create invoice with pre-selected customer
                context.go('/invoices/create');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Customer'),
              onTap: () {
                Navigator.pop(context);
                context.go('/customers/edit/${customer.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('View Invoice History'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to customer invoice history
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice history coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Customer',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(customer);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final repository = ref.read(customerRepositoryProvider);
                await repository.deleteCustomer(customer.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${customer.name} deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadCustomers();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting customer: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
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
