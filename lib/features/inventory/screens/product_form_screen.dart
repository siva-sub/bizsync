import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({
    super.key,
    this.productId,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();

  bool _isLoading = false;
  Product? _existingProduct;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadProduct();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(productRepositoryProvider);
      _existingProduct = await repository.getProduct(widget.productId!);

      if (_existingProduct != null) {
        _nameController.text = _existingProduct!.name;
        _descriptionController.text = _existingProduct!.description ?? '';
        _priceController.text = _existingProduct!.price.toString();
        _costController.text = _existingProduct!.cost?.toString() ?? '';
        _stockController.text = _existingProduct!.stockQuantity.toString();
        _barcodeController.text = _existingProduct!.barcode ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading product: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/inventory'),
        ),
        actions: [
          FilledButton(
            onPressed: _isLoading ? null : _saveProduct,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Update' : 'Save'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading && _isEditing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Basic Information',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Product Name *',
                                hintText: 'Enter product name',
                                prefixIcon: Icon(Icons.inventory_2),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Product name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText: 'Enter product description',
                                prefixIcon: Icon(Icons.description),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'Barcode/SKU',
                                hintText: 'Enter barcode or SKU',
                                prefixIcon: Icon(Icons.qr_code),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Pricing Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pricing Information',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _priceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Selling Price *',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.attach_money),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true) {
                                        return 'Selling price is required';
                                      }
                                      final price = double.tryParse(value!);
                                      if (price == null || price < 0) {
                                        return 'Enter a valid price';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _costController,
                                    decoration: const InputDecoration(
                                      labelText: 'Cost Price',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.money_off),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    validator: (value) {
                                      if (value?.isNotEmpty == true) {
                                        final cost = double.tryParse(value!);
                                        if (cost == null || cost < 0) {
                                          return 'Enter a valid cost';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildProfitCalculator(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Inventory Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inventory Information',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _stockController,
                              decoration: const InputDecoration(
                                labelText: 'Stock Quantity',
                                hintText: '0',
                                prefixIcon: Icon(Icons.inventory),
                                border: OutlineInputBorder(),
                                helperText: 'Current stock on hand',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value?.isNotEmpty == true) {
                                  final stock = int.tryParse(value!);
                                  if (stock == null || stock < 0) {
                                    return 'Enter a valid stock quantity';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildStockStatus(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfitCalculator() {
    return ValueListenableBuilder(
      valueListenable: _priceController,
      builder: (context, priceValue, child) => ValueListenableBuilder(
        valueListenable: _costController,
        builder: (context, costValue, child) {
          final price = double.tryParse(_priceController.text) ?? 0.0;
          final cost = double.tryParse(_costController.text) ?? 0.0;
          final profit = price - cost;
          final margin = cost > 0 ? (profit / cost) * 100 : 0.0;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profit Calculator',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profit per Unit',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '\$${profit.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: profit >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profit Margin',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${margin.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: margin >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockStatus() {
    return ValueListenableBuilder(
      valueListenable: _stockController,
      builder: (context, stockValue, child) {
        final stock = int.tryParse(_stockController.text) ?? 0;

        Color statusColor;
        String statusText;
        IconData statusIcon;

        if (stock == 0) {
          statusColor = Colors.red;
          statusText = 'Out of Stock';
          statusIcon = Icons.error;
        } else if (stock < 10) {
          statusColor = Colors.orange;
          statusText = 'Low Stock';
          statusIcon = Icons.warning;
        } else {
          statusColor = Colors.green;
          statusText = 'In Stock';
          statusIcon = Icons.check_circle;
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Status',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (stock > 0)
                Text(
                  '$stock units',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(productRepositoryProvider);
      final now = DateTime.now();

      final price = double.parse(_priceController.text);
      final cost = _costController.text.isEmpty
          ? null
          : double.parse(_costController.text);
      final stock =
          _stockController.text.isEmpty ? 0 : int.parse(_stockController.text);

      final product = Product(
        id: _existingProduct?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: price,
        cost: cost,
        stockQuantity: stock,
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        createdAt: _existingProduct?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditing) {
        await repository.updateProduct(product);
      } else {
        await repository.createProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Product updated successfully'
                : 'Product added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/inventory');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }
}
