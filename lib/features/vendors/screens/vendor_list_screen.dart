import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import '../models/vendor.dart';
import '../repositories/vendor_repository.dart';

class VendorListScreen extends ConsumerStatefulWidget {
  const VendorListScreen({super.key});

  @override
  ConsumerState<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends ConsumerState<VendorListScreen> {
  List<Vendor> _vendors = [];
  List<Vendor> _filteredVendors = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadVendors();
  }

  Future<void> _loadVendors() async {
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(vendorRepositoryProvider);
      _vendors = await repository.getVendors();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vendors: $e')),
        );
      }
    }

    _applyFilters();
    setState(() => _isLoading = false);
  }

  void _applyFilters() {
    _filteredVendors = _vendors.where((vendor) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!vendor.name.toLowerCase().contains(query) &&
            !(vendor.email?.toLowerCase().contains(query) ?? false) &&
            !(vendor.contactPerson?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }

      // Apply status filter
      switch (_selectedFilter) {
        case 'active':
          return vendor.isActive;
        case 'inactive':
          return !vendor.isActive;
        case 'international':
          return vendor.isInternational;
        case 'local':
          return !vendor.isInternational;
        default:
          return true;
      }
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header with search and filters
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SearchBar(
                          hintText: 'Search vendors...',
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
                        onPressed: () => context.go('/vendors/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Vendor'),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'import',
                            child: Row(
                              children: [
                                Icon(Icons.upload_file),
                                SizedBox(width: 8),
                                Text('Import Vendors'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(Icons.download),
                                SizedBox(width: 8),
                                Text('Export Vendors'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'analytics',
                            child: Row(
                              children: [
                                Icon(Icons.analytics),
                                SizedBox(width: 8),
                                Text('Vendor Analytics'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: _handleMenuAction,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All Vendors')),
                        ButtonSegment(value: 'active', label: Text('Active')),
                        ButtonSegment(
                            value: 'inactive', label: Text('Inactive')),
                        ButtonSegment(value: 'local', label: Text('Local')),
                        ButtonSegment(
                            value: 'international',
                            label: Text('International')),
                      ],
                      selected: {_selectedFilter},
                      onSelectionChanged: (Set<String> selected) {
                        _onFilterChanged(selected.first);
                      },
                    ),
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
                  '${_filteredVendors.length} of ${_vendors.length} vendors',
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
                : _filteredVendors.isEmpty
                    ? _buildEmptyState()
                    : Card(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: DataTable2(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          minWidth: 800,
                          columns: const [
                            DataColumn2(
                              label: Text('Vendor'),
                              size: ColumnSize.L,
                            ),
                            DataColumn2(
                              label: Text('Contact'),
                              size: ColumnSize.M,
                            ),
                            DataColumn2(
                              label: Text('Location'),
                              size: ColumnSize.M,
                            ),
                            DataColumn2(
                              label: Text('Payment Terms'),
                              size: ColumnSize.S,
                            ),
                            DataColumn2(
                              label: Text('Status'),
                              size: ColumnSize.S,
                            ),
                            DataColumn2(
                              label: Text('Actions'),
                              size: ColumnSize.S,
                            ),
                          ],
                          rows: _filteredVendors.map((vendor) {
                            return DataRow2(
                              onTap: () => _showVendorDetails(vendor),
                              cells: [
                                DataCell(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        vendor.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (vendor.contactPerson?.isNotEmpty ==
                                          true)
                                        Text(
                                          'Contact: ${vendor.contactPerson}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                      if (vendor.website?.isNotEmpty == true)
                                        Text(
                                          vendor.website!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.blue,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (vendor.email?.isNotEmpty == true)
                                        Text(vendor.email!),
                                      if (vendor.phone?.isNotEmpty == true)
                                        Text(
                                          vendor.phone!,
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: vendor.isInternational
                                                  ? Colors.purple
                                                      .withOpacity(0.1)
                                                  : Colors.green
                                                      .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              vendor.countryCode ?? 'SG',
                                              style: TextStyle(
                                                color: vendor.isInternational
                                                    ? Colors.purple
                                                    : Colors.green,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          if (vendor.isInternational)
                                            const Icon(Icons.public,
                                                size: 16, color: Colors.purple),
                                        ],
                                      ),
                                      if (vendor.address?.isNotEmpty == true)
                                        Text(
                                          vendor.address!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    vendor.paymentTermsDisplay,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: vendor.isActive
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      vendor.isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        color: vendor.isActive
                                            ? Colors.green
                                            : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => context
                                            .go('/vendors/edit/${vendor.id}'),
                                        tooltip: 'Edit Vendor',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.more_vert,
                                            size: 20),
                                        onPressed: () =>
                                            _showVendorActions(vendor),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty || _selectedFilter != 'all'
                ? Icons.search_off
                : Icons.store_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'all'
                ? 'No vendors found'
                : 'No vendors yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'all'
                ? 'Try adjusting your search or filters'
                : 'Add your first vendor to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty && _selectedFilter == 'all')
            FilledButton.icon(
              onPressed: () => context.go('/vendors/create'),
              icon: const Icon(Icons.add),
              label: const Text('Add Vendor'),
            ),
        ],
      ),
    );
  }

  void _showVendorDetails(Vendor vendor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(vendor.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(
                  'Contact Person', vendor.contactPerson ?? 'Not provided'),
              _DetailRow('Email', vendor.email ?? 'Not provided'),
              _DetailRow('Phone', vendor.phone ?? 'Not provided'),
              _DetailRow('Address', vendor.address ?? 'Not provided'),
              _DetailRow('Website', vendor.website ?? 'Not provided'),
              _DetailRow('Tax ID', vendor.taxId ?? 'Not provided'),
              _DetailRow('Payment Terms', vendor.paymentTermsDisplay),
              _DetailRow('Bank Account', vendor.bankAccount ?? 'Not provided'),
              _DetailRow('Status', vendor.isActive ? 'Active' : 'Inactive'),
              _DetailRow('Location',
                  vendor.isInternational ? 'International' : 'Local'),
              _DetailRow('Created',
                  '${vendor.createdAt.day}/${vendor.createdAt.month}/${vendor.createdAt.year}'),
              if (vendor.notes?.isNotEmpty == true)
                _DetailRow('Notes', vendor.notes!),
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
              context.go('/vendors/edit/${vendor.id}');
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showVendorActions(Vendor vendor) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Vendor'),
              onTap: () {
                Navigator.pop(context);
                context.go('/vendors/edit/${vendor.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Create Purchase Order'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoonDialog('Purchase Order');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Record Payment'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoonDialog('Payment Recording');
              },
            ),
            ListTile(
              leading: Icon(
                vendor.isActive ? Icons.pause_circle : Icons.play_circle,
                color: vendor.isActive ? Colors.orange : Colors.green,
              ),
              title: Text(
                  vendor.isActive ? 'Deactivate Vendor' : 'Activate Vendor'),
              onTap: () {
                Navigator.pop(context);
                _toggleVendorStatus(vendor);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Vendor',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(vendor);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleVendorStatus(Vendor vendor) async {
    try {
      final repository = ref.read(vendorRepositoryProvider);
      final updatedVendor = vendor.copyWith(
        isActive: !vendor.isActive,
        updatedAt: DateTime.now(),
      );
      await repository.updateVendor(updatedVendor);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vendor.isActive
                ? '${vendor.name} deactivated'
                : '${vendor.name} activated'),
            backgroundColor: Colors.green,
          ),
        );
        _loadVendors();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating vendor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Vendor vendor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text('Are you sure you want to delete "${vendor.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final repository = ref.read(vendorRepositoryProvider);
                await repository.deleteVendor(vendor.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${vendor.name} deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadVendors();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting vendor: $e'),
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

  void _handleMenuAction(String action) {
    switch (action) {
      case 'import':
        _showComingSoonDialog('Import Vendors');
        break;
      case 'export':
        _showComingSoonDialog('Export Vendors');
        break;
      case 'analytics':
        _showComingSoonDialog('Vendor Analytics');
        break;
    }
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature functionality is coming soon!'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
            width: 120,
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
