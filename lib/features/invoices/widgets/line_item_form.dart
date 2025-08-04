import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/invoice_models.dart';
import '../../tax/services/singapore_gst_service.dart';
import '../../tax/services/tax_settings_service.dart';

/// Form widget for individual line items with Singapore GST tax categories
class LineItemForm extends StatefulWidget {
  final CRDTInvoiceItem? item;
  final Map<String, dynamic>? lineItem;
  final Function(Map<String, dynamic>)? onChanged;
  final Function(Map<String, dynamic>)? onUpdate;
  final Function(Map<String, dynamic>)? onSave;
  final VoidCallback? onRemove;
  final VoidCallback? onDelete;

  const LineItemForm({
    Key? key,
    this.item,
    this.lineItem,
    this.onChanged,
    this.onUpdate,
    this.onSave,
    this.onRemove,
    this.onDelete,
  }) : super(key: key);

  @override
  State<LineItemForm> createState() => _LineItemFormState();
}

class _LineItemFormState extends State<LineItemForm> {
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _unitPriceController;
  late TextEditingController _discountController;
  late TextEditingController _taxRateController;

  LineItemType _itemType = LineItemType.product;
  TaxCalculationMethod _taxMethod = TaxCalculationMethod.exclusive;
  GstTaxCategory _gstCategory = GstTaxCategory.standard;
  
  bool _companyGstRegistered = true;
  bool _customerGstRegistered = false;

  @override
  void initState() {
    super.initState();
    
    final data = widget.item?.toJson() ?? widget.lineItem ?? {};
    
    _loadGstRegistrationStatus();
    
    _descriptionController = TextEditingController(
      text: data['description'] ?? '',
    );
    _quantityController = TextEditingController(
      text: (data['quantity'] ?? 1.0).toString(),
    );
    _unitPriceController = TextEditingController(
      text: (data['unit_price'] ?? 0.0).toString(),
    );
    _discountController = TextEditingController(
      text: (data['discount'] ?? 0.0).toString(),
    );
    _taxRateController = TextEditingController(
      text: (data['tax_rate'] ?? 9.0).toString(), // Updated to current 9% GST rate
    );

    if (data['item_type'] != null) {
      _itemType = LineItemType.fromString(data['item_type']);
    }
    if (data['tax_method'] != null) {
      _taxMethod = TaxCalculationMethod.fromString(data['tax_method']);
    }
    if (data['gst_category'] != null) {
      try {
        _gstCategory = GstTaxCategory.values.firstWhere(
          (category) => category.name == data['gst_category']
        );
      } catch (e) {
        _gstCategory = GstTaxCategory.standard;
      }
    }

    _descriptionController.addListener(_onChanged);
    _quantityController.addListener(_onChanged);
    _unitPriceController.addListener(_onChanged);
    _discountController.addListener(_onChanged);
    _taxRateController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _discountController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }
  
  Future<void> _loadGstRegistrationStatus() async {
    try {
      final companyRegistered = await TaxSettingsService().getCompanyGstRegistrationStatus();
      final customerRegistered = await TaxSettingsService().getCustomerGstRegistrationStatus(null);
      
      if (mounted) {
        setState(() {
          _companyGstRegistered = companyRegistered;
          _customerGstRegistered = customerRegistered;
        });
      }
    } catch (e) {
      // Fallback to default values
      if (mounted) {
        setState(() {
          _companyGstRegistered = true;
          _customerGstRegistered = false;
        });
      }
    }
  }

  void _onChanged() {
    final data = widget.item?.toJson() ?? widget.lineItem ?? {};
    final updatedItem = Map<String, dynamic>.from(data);
    
    updatedItem['description'] = _descriptionController.text;
    updatedItem['quantity'] = double.tryParse(_quantityController.text) ?? 1.0;
    updatedItem['unit_price'] = double.tryParse(_unitPriceController.text) ?? 0.0;
    updatedItem['discount'] = double.tryParse(_discountController.text) ?? 0.0;
    updatedItem['tax_rate'] = double.tryParse(_taxRateController.text) ?? 0.0;
    updatedItem['item_type'] = _itemType.value;
    updatedItem['tax_method'] = _taxMethod.value;
    updatedItem['gst_category'] = _gstCategory.name;

    // Calculate line total
    final quantity = updatedItem['quantity'] as double;
    final unitPrice = updatedItem['unit_price'] as double;
    final discount = updatedItem['discount'] as double;
    final taxRate = updatedItem['tax_rate'] as double;

    double subtotal = quantity * unitPrice;
    
    // Apply discount
    if (discount > 0) {
      if (discount <= 1.0) {
        // Percentage discount
        subtotal = subtotal * (1 - discount);
      } else {
        // Fixed amount discount
        subtotal = subtotal - discount;
      }
    }

    // Calculate GST using Singapore GST service
    GstCalculationResult gstResult;
    if (_taxMethod == TaxCalculationMethod.exclusive) {
      gstResult = SingaporeGstService.calculateGst(
        amount: subtotal,
        calculationDate: DateTime.now(),
        taxCategory: _gstCategory,
        isGstRegistered: _companyGstRegistered,
        customerIsGstRegistered: _customerGstRegistered
      );
    } else {
      gstResult = SingaporeGstService.calculateGstInclusive(
        totalAmount: subtotal,
        calculationDate: DateTime.now(),
        taxCategory: _gstCategory,
        isGstRegistered: _companyGstRegistered,
        customerIsGstRegistered: _customerGstRegistered
      );
    }

    updatedItem['line_total'] = gstResult.totalAmount;
    updatedItem['gst_amount'] = gstResult.gstAmount;
    updatedItem['net_amount'] = gstResult.netAmount;
    updatedItem['effective_gst_rate'] = gstResult.gstRate * 100;
    updatedItem['gst_reasoning'] = gstResult.reasoning;

    if (widget.onChanged != null) {
      widget.onChanged!(updatedItem);
    }
    if (widget.onUpdate != null) {
      widget.onUpdate!(updatedItem);
    }
    if (widget.onSave != null) {
      widget.onSave!(updatedItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 12),
            _buildQuantityAndPriceRow(),
            const SizedBox(height: 12),
            _buildDiscountAndTaxRow(),
            const SizedBox(height: 12),
            _buildGstCategoryRow(),
            const SizedBox(height: 12),
            _buildTaxSettings(),
            const SizedBox(height: 16),
            _buildTotal(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<LineItemType>(
            value: _itemType,
            decoration: const InputDecoration(
              labelText: 'Item Type',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: LineItemType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getItemTypeDisplayName(type)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _itemType = value;
                });
                _onChanged();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        if (widget.onRemove != null)
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Remove item',
          ),
        if (widget.onDelete != null)
          IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Remove item',
          ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description *',
        hintText: 'Enter item description',
        border: OutlineInputBorder(),
      ),
      maxLines: 2,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Description is required';
        }
        return null;
      },
    );
  }

  Widget _buildQuantityAndPriceRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            validator: (value) {
              final quantity = double.tryParse(value ?? '');
              if (quantity == null || quantity <= 0) {
                return 'Invalid quantity';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _unitPriceController,
            decoration: const InputDecoration(
              labelText: 'Unit Price',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            validator: (value) {
              final price = double.tryParse(value ?? '');
              if (price == null || price < 0) {
                return 'Invalid price';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountAndTaxRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _discountController,
            decoration: const InputDecoration(
              labelText: 'Discount %',
              hintText: '0.1 for 10% or 50 for \$50',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _taxRateController,
            decoration: const InputDecoration(
              labelText: 'Tax Rate %',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGstCategoryRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<GstTaxCategory>(
            value: _gstCategory,
            decoration: const InputDecoration(
              labelText: 'GST Category',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: GstTaxCategory.values.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(
                  category.displayName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _gstCategory = value;
                  // Update tax rate based on category
                  if (value == GstTaxCategory.standard) {
                    _taxRateController.text = '9.0';
                  } else {
                    _taxRateController.text = '0.0';
                  }
                });
                _onChanged();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
              color: _getCategoryColor(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category Info',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _gstCategory.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxSettings() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<TaxCalculationMethod>(
            value: _taxMethod,
            decoration: const InputDecoration(
              labelText: 'Tax Method',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: TaxCalculationMethod.values.map((method) {
              return DropdownMenuItem(
                value: method,
                child: Text(_getTaxMethodDisplayName(method)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _taxMethod = value;
                });
                _onChanged();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tax Method Info',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTaxMethodDescription(_taxMethod),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotal() {
    final quantity = double.tryParse(_quantityController.text) ?? 1.0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;

    double subtotal = quantity * unitPrice;
    double discountAmount = 0.0;
    
    if (discount > 0) {
      if (discount <= 1.0) {
        discountAmount = subtotal * discount;
      } else {
        discountAmount = discount;
      }
    }
    
    final afterDiscount = subtotal - discountAmount;
    
    // Calculate GST using Singapore GST service
    GstCalculationResult gstResult;
    if (_taxMethod == TaxCalculationMethod.exclusive) {
      gstResult = SingaporeGstService.calculateGst(
        amount: afterDiscount,
        calculationDate: DateTime.now(),
        taxCategory: _gstCategory,
        isGstRegistered: _companyGstRegistered,
        customerIsGstRegistered: _customerGstRegistered
      );
    } else {
      gstResult = SingaporeGstService.calculateGstInclusive(
        totalAmount: afterDiscount,
        calculationDate: DateTime.now(),
        taxCategory: _gstCategory,
        isGstRegistered: _companyGstRegistered,
        customerIsGstRegistered: _customerGstRegistered
      );
    }

    final total = gstResult.totalAmount;
    final gstAmount = gstResult.gstAmount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', subtotal),
          if (discountAmount > 0)
            _buildTotalRow('Discount', -discountAmount, color: Colors.red),
          if (gstAmount > 0)
            _buildTotalRow('GST (${(gstResult.gstRate * 100).toStringAsFixed(1)}%)', gstAmount),
          if (gstResult.reasoning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                gstResult.reasoning,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const Divider(),
          _buildTotalRow('Line Total', total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            '\$ ${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Theme.of(context).primaryColor : color,
            ),
          ),
        ],
      ),
    );
  }

  String _getItemTypeDisplayName(LineItemType type) {
    switch (type) {
      case LineItemType.product:
        return 'Product';
      case LineItemType.service:
        return 'Service';
      case LineItemType.discount:
        return 'Discount';
      case LineItemType.shipping:
        return 'Shipping';
      case LineItemType.tax:
        return 'Tax';
      case LineItemType.custom:
        return 'Custom';
    }
  }

  String _getTaxMethodDisplayName(TaxCalculationMethod method) {
    switch (method) {
      case TaxCalculationMethod.exclusive:
        return 'Tax Exclusive';
      case TaxCalculationMethod.inclusive:
        return 'Tax Inclusive';
      case TaxCalculationMethod.compound:
        return 'Compound Tax';
    }
  }

  String _getTaxMethodDescription(TaxCalculationMethod method) {
    switch (method) {
      case TaxCalculationMethod.exclusive:
        return 'Tax added to amount';
      case TaxCalculationMethod.inclusive:
        return 'Tax included in amount';
      case TaxCalculationMethod.compound:
        return 'Tax on tax';
    }
  }

  Color _getCategoryColor() {
    switch (_gstCategory) {
      case GstTaxCategory.standard:
        return Colors.green[50]!;
      case GstTaxCategory.zeroRated:
        return Colors.blue[50]!;
      case GstTaxCategory.exempt:
        return Colors.orange[50]!;
      case GstTaxCategory.reducedRate:
        return Colors.purple[50]!;
    }
  }
}