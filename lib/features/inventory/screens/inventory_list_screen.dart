import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(productRepositoryProvider);
      _products = await repository.getProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }

    _applyFilters();
    setState(() => _isLoading = false);
  }

  void _applyFilters() {
    _filteredProducts = _products.where((product) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!product.name.toLowerCase().contains(query) &&
            !(product.description?.toLowerCase().contains(query) ?? false) &&
            !(product.barcode?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }

      // Apply stock filter
      switch (_selectedFilter) {
        case 'in_stock':
          return product.isInStock;
        case 'low_stock':
          return product.isLowStock;
        case 'out_of_stock':
          return product.stockQuantity == 0;
        default:
          return true;
      }
    }).toList();

    // Apply sorting
    _filteredProducts.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'price':
          comparison = a.price.compareTo(b.price);
          break;
        case 'stock':
          comparison = a.stockQuantity.compareTo(b.stockQuantity);
          break;
        case 'created':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });
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

  void _onSortChanged(String sortBy) {
    setState(() {
      if (_sortBy == sortBy) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = sortBy;
        _sortAscending = true;
      }
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
                          hintText: 'Search products...',
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
                        onPressed: () => context.go('/inventory/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Product'),
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
                                Text('Import Products'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(Icons.download),
                                SizedBox(width: 8),
                                Text('Export Products'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'categories',
                            child: Row(
                              children: [
                                Icon(Icons.category),
                                SizedBox(width: 8),
                                Text('Manage Categories'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: _handleMenuAction,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                                value: 'all', label: Text('All Products')),
                            ButtonSegment(
                                value: 'in_stock', label: Text('In Stock')),
                            ButtonSegment(
                                value: 'low_stock', label: Text('Low Stock')),
                            ButtonSegment(
                                value: 'out_of_stock',
                                label: Text('Out of Stock')),
                          ],
                          selected: {_selectedFilter},
                          onSelectionChanged: (Set<String> selected) {
                            _onFilterChanged(selected.first);
                          },
                        ),
                      ),
                    ],
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
                  '${_filteredProducts.length} of ${_products.length} products',
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
                : _filteredProducts.isEmpty
                    ? _buildEmptyState()
                    : Card(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: DataTable2(
                          columnSpacing: 12,
                          horizontalMargin: 12,
                          minWidth: 900,
                          sortColumnIndex: _getSortColumnIndex(),
                          sortAscending: _sortAscending,
                          columns: [
                            DataColumn2(
                              label: const Text('Product'),
                              size: ColumnSize.L,
                              onSort: (columnIndex, ascending) =>
                                  _onSortChanged('name'),
                            ),
                            DataColumn2(
                              label: const Text('Price'),
                              size: ColumnSize.S,
                              numeric: true,
                              onSort: (columnIndex, ascending) =>
                                  _onSortChanged('price'),
                            ),
                            DataColumn2(
                              label: const Text('Stock'),
                              size: ColumnSize.S,
                              numeric: true,
                              onSort: (columnIndex, ascending) =>
                                  _onSortChanged('stock'),
                            ),
                            const DataColumn2(
                              label: Text('Profit'),
                              size: ColumnSize.S,
                              numeric: true,
                            ),
                            const DataColumn2(
                              label: Text('Status'),
                              size: ColumnSize.S,
                            ),
                            DataColumn2(
                              label: const Text('Created'),
                              size: ColumnSize.M,
                              onSort: (columnIndex, ascending) =>
                                  _onSortChanged('created'),
                            ),
                            const DataColumn2(
                              label: Text('Actions'),
                              size: ColumnSize.S,
                            ),
                          ],
                          rows: _filteredProducts.map((product) {
                            return DataRow2(
                              onTap: () => _showProductDetails(product),
                              cells: [
                                DataCell(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (product.description?.isNotEmpty ==
                                          true)
                                        Text(
                                          product.description!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (product.barcode?.isNotEmpty == true)
                                        Text(
                                          'SKU: ${product.barcode}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[500],
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '\$${product.price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (product.cost != null)
                                        Text(
                                          'Cost: \$${product.cost!.toStringAsFixed(2)}',
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
                                  Text(
                                    product.stockQuantity.toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _getStockColor(product),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '\$${product.profitAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        '${product.profitMarginPercentage.toStringAsFixed(1)}%',
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
                                  _buildStatusChip(product),
                                ),
                                DataCell(
                                  Text(
                                    '${product.createdAt.day}/${product.createdAt.month}/${product.createdAt.year}',
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => context.go(
                                            '/inventory/edit/${product.id}'),
                                        tooltip: 'Edit Product',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.more_vert,
                                            size: 20),
                                        onPressed: () =>
                                            _showProductActions(product),
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
                : Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'all'
                ? 'No products found'
                : 'No products yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'all'
                ? 'Try adjusting your search or filters'
                : 'Add your first product to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty && _selectedFilter == 'all')
            FilledButton.icon(
              onPressed: () => context.go('/inventory/create'),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Product product) {
    Color color;
    String text;

    if (product.stockQuantity == 0) {
      color = Colors.red;
      text = 'Out of Stock';
    } else if (product.isLowStock) {
      color = Colors.orange;
      text = 'Low Stock';
    } else {
      color = Colors.green;
      text = 'In Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getStockColor(Product product) {
    if (product.stockQuantity == 0) return Colors.red;
    if (product.isLowStock) return Colors.orange;
    return Colors.green;
  }

  int? _getSortColumnIndex() {
    switch (_sortBy) {
      case 'name':
        return 0;
      case 'price':
        return 1;
      case 'stock':
        return 2;
      case 'created':
        return 5;
      default:
        return null;
    }
  }

  void _showProductDetails(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Description', product.description ?? 'Not provided'),
              _DetailRow('Price', '\$${product.price.toStringAsFixed(2)}'),
              if (product.cost != null)
                _DetailRow('Cost', '\$${product.cost!.toStringAsFixed(2)}'),
              _DetailRow('Stock Quantity', product.stockQuantity.toString()),
              _DetailRow('Profit Margin',
                  '${product.profitMarginPercentage.toStringAsFixed(1)}%'),
              if (product.barcode?.isNotEmpty == true)
                _DetailRow('Barcode/SKU', product.barcode!),
              _DetailRow('Created',
                  '${product.createdAt.day}/${product.createdAt.month}/${product.createdAt.year}'),
              _DetailRow('Last Updated',
                  '${product.updatedAt.day}/${product.updatedAt.month}/${product.updatedAt.year}'),
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
              context.go('/inventory/edit/${product.id}');
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showProductActions(Product product) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Product'),
              onTap: () {
                Navigator.pop(context);
                context.go('/inventory/edit/${product.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Duplicate Product'),
              onTap: () {
                Navigator.pop(context);
                _duplicateProduct(product);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text('Adjust Stock'),
              onTap: () {
                Navigator.pop(context);
                _showStockAdjustmentDialog(product);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Generate Barcode'),
              onTap: () {
                Navigator.pop(context);
                _showComingSoonDialog('Barcode Generation');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Product',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(product);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStockAdjustmentDialog(Product product) {
    final controller = TextEditingController();
    String adjustmentType = 'add';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Adjust Stock - ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Stock: ${product.stockQuantity}'),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'add', label: Text('Add Stock')),
                  ButtonSegment(value: 'remove', label: Text('Remove Stock')),
                  ButtonSegment(value: 'set', label: Text('Set Stock')),
                ],
                selected: {adjustmentType},
                onSelectionChanged: (Set<String> selected) {
                  setState(() {
                    adjustmentType = selected.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: adjustmentType == 'set'
                      ? 'New Stock Quantity'
                      : 'Quantity',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _adjustStock(product, adjustmentType, controller.text);
                Navigator.pop(context);
              },
              child: const Text('Adjust'),
            ),
          ],
        ),
      ),
    );
  }

  void _adjustStock(Product product, String type, String quantityStr) {
    final quantity = int.tryParse(quantityStr);
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid quantity')),
      );
      return;
    }

    int newStock;
    switch (type) {
      case 'add':
        newStock = product.stockQuantity + quantity;
        break;
      case 'remove':
        newStock = (product.stockQuantity - quantity)
            .clamp(0, double.infinity)
            .toInt();
        break;
      case 'set':
        newStock = quantity.clamp(0, double.infinity).toInt();
        break;
      default:
        return;
    }

    final updatedProduct = product.copyWith(
      stockQuantity: newStock,
      updatedAt: DateTime.now(),
    );

    _updateProduct(updatedProduct);
  }

  void _duplicateProduct(Product product) {
    final duplicatedProduct = product.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${product.name} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _createProduct(duplicatedProduct);
  }

  void _createProduct(Product product) async {
    try {
      final repository = ref.read(productRepositoryProvider);
      await repository.createProduct(product);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product duplicated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error duplicating product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateProduct(Product product) async {
    try {
      final repository = ref.read(productRepositoryProvider);
      await repository.updateProduct(product);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock adjusted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adjusting stock: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final repository = ref.read(productRepositoryProvider);
                await repository.deleteProduct(product.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadProducts();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting product: $e'),
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
        _showComingSoonDialog('Import Products');
        break;
      case 'export':
        _showComingSoonDialog('Export Products');
        break;
      case 'categories':
        _showComingSoonDialog('Category Management');
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
