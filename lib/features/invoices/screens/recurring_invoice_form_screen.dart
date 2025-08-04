import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/enhanced_invoice.dart';
import '../models/recurring_invoice_models.dart';
import '../services/recurring_invoice_service.dart';
import '../../../core/demo/demo_data_service.dart';

/// Form screen for creating and editing recurring invoice templates
class RecurringInvoiceFormScreen extends StatefulWidget {
  final RecurringInvoiceTemplate? template;

  const RecurringInvoiceFormScreen({
    super.key,
    this.template,
  });

  @override
  State<RecurringInvoiceFormScreen> createState() =>
      _RecurringInvoiceFormScreenState();
}

class _RecurringInvoiceFormScreenState
    extends State<RecurringInvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final RecurringInvoiceService _recurringService =
      RecurringInvoiceService.instance;
  final DemoDataService _demoService = DemoDataService();

  // Form controllers
  final _templateNameController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');
  final _maxOccurrencesController = TextEditingController();

  // Form state
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  RecurringPattern _selectedPattern = RecurringPattern.monthly;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _hasMaxOccurrences = false;
  List<InvoiceLineItem> _lineItems = [];
  double _subtotal = 0.0;
  double _taxAmount = 0.0;
  double _total = 0.0;

  // Available customers (demo data)
  List<Map<String, String>> _customers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    if (widget.template != null) {
      _populateFormFromTemplate();
    } else {
      _addDefaultLineItem();
    }
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    _intervalController.dispose();
    _maxOccurrencesController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      if (!_demoService.isInitialized) {
        await _demoService.initializeDemoData();
      }

      setState(() {
        _customers = [
          {'id': '1', 'name': 'Acme Corp'},
          {'id': '2', 'name': 'Tech Solutions Pte Ltd'},
          {'id': '3', 'name': 'Global Enterprises'},
          {'id': '4', 'name': 'Innovation Inc'},
          {'id': '5', 'name': 'Future Systems'},
        ];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customers: $e')),
        );
      }
    }
  }

  void _populateFormFromTemplate() {
    final template = widget.template!;

    _templateNameController.text = template.templateName;
    _selectedCustomerId = template.customerId;
    _selectedCustomerName = template.customerName;
    _selectedPattern = template.pattern;
    _intervalController.text = template.interval.toString();
    _startDate = template.startDate;
    _endDate = template.endDate;
    _hasMaxOccurrences = template.maxOccurrences != null;
    if (_hasMaxOccurrences) {
      _maxOccurrencesController.text = template.maxOccurrences.toString();
    }

    _lineItems = List.from(template.invoiceTemplate.lineItems);
    _calculateTotals();
  }

  void _addDefaultLineItem() {
    _lineItems.add(const InvoiceLineItem(
      id: '1',
      description: 'Service/Product',
      quantity: 1,
      unitPrice: 100.0,
      lineTotal: 100.0,
    ));
    _calculateTotals();
  }

  void _calculateTotals() {
    _subtotal = _lineItems.fold(0.0, (sum, item) => sum + item.lineTotal);
    _taxAmount = _subtotal * 0.07; // 7% GST
    _total = _subtotal + _taxAmount;
    setState(() {});
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }
    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final invoiceTemplate = EnhancedInvoice(
        id: '', // Will be set by the service
        invoiceNumber: '', // Will be generated
        customerId: _selectedCustomerId!,
        customerName: _selectedCustomerName!,
        issueDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        status: InvoiceStatus.draft,
        lineItems: _lineItems,
        subtotal: _subtotal,
        taxAmount: _taxAmount,
        totalAmount: _total,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isRecurring: true,
        recurringPattern: _selectedPattern.name,
      );

      if (widget.template != null) {
        // Update existing template
        final updatedTemplate = widget.template!.copyWith(
          templateName: _templateNameController.text,
          customerId: _selectedCustomerId!,
          customerName: _selectedCustomerName!,
          pattern: _selectedPattern,
          interval: int.parse(_intervalController.text),
          startDate: _startDate,
          endDate: _endDate,
          maxOccurrences: _hasMaxOccurrences
              ? int.tryParse(_maxOccurrencesController.text)
              : null,
          invoiceTemplate: invoiceTemplate,
        );

        await _recurringService.updateTemplate(updatedTemplate);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template updated successfully')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // Create new template
        await _recurringService.createRecurringTemplate(
          templateName: _templateNameController.text,
          customerId: _selectedCustomerId!,
          customerName: _selectedCustomerName!,
          pattern: _selectedPattern,
          interval: int.parse(_intervalController.text),
          startDate: _startDate,
          endDate: _endDate,
          maxOccurrences: _hasMaxOccurrences
              ? int.tryParse(_maxOccurrencesController.text)
              : null,
          invoiceTemplate: invoiceTemplate,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Recurring template created successfully')),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template != null
            ? 'Edit Recurring Template'
            : 'Create Recurring Template'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveTemplate,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 24),
            _buildRecurrenceSection(),
            const SizedBox(height: 24),
            _buildLineItemsSection(),
            const SizedBox(height: 24),
            _buildTotalsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _templateNameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                hintText: 'e.g., Monthly Service Fee',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a template name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCustomerId,
              decoration: const InputDecoration(
                labelText: 'Customer',
                border: OutlineInputBorder(),
              ),
              items: _customers.map((customer) {
                return DropdownMenuItem<String>(
                  value: customer['id'],
                  child: Text(customer['name']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCustomerId = value;
                  _selectedCustomerName =
                      _customers.firstWhere((c) => c['id'] == value)['name'];
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a customer';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recurrence Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RecurringPattern>(
                    value: _selectedPattern,
                    decoration: const InputDecoration(
                      labelText: 'Pattern',
                      border: OutlineInputBorder(),
                    ),
                    items: RecurringPattern.values.map((pattern) {
                      return DropdownMenuItem<RecurringPattern>(
                        value: pattern,
                        child: Text(_getPatternDisplayName(pattern)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPattern = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _intervalController,
                    decoration: const InputDecoration(
                      labelText: 'Every',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final intValue = int.tryParse(value ?? '');
                      if (intValue == null || intValue < 1) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ??
                            _startDate.add(const Duration(days: 365)),
                        firstDate: _startDate,
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 10)),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      } else {
                        setState(() => _endDate = null);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _endDate != null
                            ? DateFormat('dd/MM/yyyy').format(_endDate!)
                            : 'No end date',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _hasMaxOccurrences,
                  onChanged: (value) {
                    setState(() {
                      _hasMaxOccurrences = value!;
                      if (!_hasMaxOccurrences) {
                        _maxOccurrencesController.clear();
                      }
                    });
                  },
                ),
                const Text('Limit number of invoices'),
                if (_hasMaxOccurrences) ...[
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _maxOccurrencesController,
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _hasMaxOccurrences
                          ? (value) {
                              final intValue = int.tryParse(value ?? '');
                              if (intValue == null || intValue < 1) {
                                return 'Invalid';
                              }
                              return null;
                            }
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Invoice Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: _addLineItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._lineItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildLineItemCard(item, index);
            }),
            if (_lineItems.isEmpty)
              const Center(
                child: Text(
                  'No items added yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemCard(InvoiceLineItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextFormField(
              initialValue: item.description,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _updateLineItem(index, description: value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final qty = double.tryParse(value) ?? 1.0;
                      _updateLineItem(index, quantity: qty);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item.unitPrice.toStringAsFixed(2),
                    decoration: const InputDecoration(
                      labelText: 'Unit Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final price = double.tryParse(value) ?? 0.0;
                      _updateLineItem(index, unitPrice: price);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: Text(
                    '\$${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeLineItem(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice Total',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:'),
                Text('\$${_subtotal.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tax (7% GST):'),
                Text('\$${_taxAmount.toStringAsFixed(2)}'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '\$${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(InvoiceLineItem(
        id: (_lineItems.length + 1).toString(),
        description: 'Service/Product',
        quantity: 1,
        unitPrice: 100.0,
        lineTotal: 100.0,
      ));
    });
    _calculateTotals();
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
    _calculateTotals();
  }

  void _updateLineItem(
    int index, {
    String? description,
    double? quantity,
    double? unitPrice,
  }) {
    final item = _lineItems[index];
    final newQuantity = quantity ?? item.quantity;
    final newUnitPrice = unitPrice ?? item.unitPrice;

    _lineItems[index] = item.copyWith(
      description: description ?? item.description,
      quantity: newQuantity,
      unitPrice: newUnitPrice,
      lineTotal: newQuantity * newUnitPrice,
    );

    _calculateTotals();
  }

  String _getPatternDisplayName(RecurringPattern pattern) {
    switch (pattern) {
      case RecurringPattern.weekly:
        return 'Weekly';
      case RecurringPattern.biweekly:
        return 'Bi-weekly';
      case RecurringPattern.monthly:
        return 'Monthly';
      case RecurringPattern.quarterly:
        return 'Quarterly';
      case RecurringPattern.halfYearly:
        return 'Half-yearly';
      case RecurringPattern.yearly:
        return 'Yearly';
      case RecurringPattern.custom:
        return 'Custom';
    }
  }
}
