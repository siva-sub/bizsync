import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';
import '../services/invoice_service.dart';
import '../widgets/line_item_form.dart';
import '../widgets/customer_picker.dart';
import '../../customers/repositories/customer_repository.dart';
import '../../../data/models/customer.dart';

/// Screen for creating or editing invoices
class InvoiceFormScreen extends StatefulWidget {
  final InvoiceService invoiceService;
  final CustomerRepository customerRepository;
  final String? invoiceId; // null for create, set for edit
  final CRDTInvoiceEnhanced? existingInvoice;

  const InvoiceFormScreen({
    Key? key,
    required this.invoiceService,
    required this.customerRepository,
    this.invoiceId,
    this.existingInvoice,
  }) : super(key: key);

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  late TabController _tabController;

  // Form controllers
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerEmailController = TextEditingController();
  final TextEditingController _billingAddressController = TextEditingController();
  final TextEditingController _shippingAddressController = TextEditingController();
  final TextEditingController _poNumberController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _footerController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _shippingController = TextEditingController();

  // Form state
  bool _isLoading = false;
  bool _isEditing = false;
  String? _selectedCustomerId;
  List<Customer> _customers = [];
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  PaymentTerm _paymentTerms = PaymentTerm.net30;
  String _currency = 'SGD';
  double _exchangeRate = 1.0;
  bool _autoReminders = true;
  int _reminderDaysBefore = 3;
  bool _autoFollowUp = true;

  // Line items
  List<Map<String, dynamic>> _lineItems = [];
  
  // Calculated totals
  double _subtotal = 0.0;
  double _taxAmount = 0.0;
  double _discountAmount = 0.0;
  double _shippingAmount = 0.0;
  double _totalAmount = 0.0;

  int _currentStep = 0;
  final List<String> _stepTitles = [
    'Basic Info',
    'Customer',
    'Line Items',
    'Settings',
    'Review',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stepTitles.length, vsync: this);
    _isEditing = widget.invoiceId != null;
    
    if (_isEditing && widget.existingInvoice != null) {
      _populateFormFromExisting();
    } else {
      _addEmptyLineItem();
    }
    
    _calculateDueDate();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await widget.customerRepository.getCustomers();
      setState(() {
        _customers = customers;
      });
    } catch (e) {
      // Handle error silently or show a snackbar
      print('Error loading customers: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _invoiceNumberController.dispose();
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _billingAddressController.dispose();
    _shippingAddressController.dispose();
    _poNumberController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    _footerController.dispose();
    _discountController.dispose();
    _shippingController.dispose();
    super.dispose();
  }

  void _populateFormFromExisting() {
    final invoice = widget.existingInvoice!;
    
    _invoiceNumberController.text = invoice.invoiceNumber.value;
    _selectedCustomerId = invoice.customerId.value;
    _customerNameController.text = invoice.customerName.value ?? '';
    _customerEmailController.text = invoice.customerEmail.value ?? '';
    _billingAddressController.text = invoice.billingAddress.value ?? '';
    _shippingAddressController.text = invoice.shippingAddress.value ?? '';
    _issueDate = invoice.issueDate.value;
    _dueDate = invoice.dueDate.value;
    _paymentTerms = invoice.paymentTerms.value;
    _poNumberController.text = invoice.poNumber.value ?? '';
    _referenceController.text = invoice.reference.value ?? '';
    _notesController.text = invoice.notes.value ?? '';
    _termsController.text = invoice.termsAndConditions.value ?? '';
    _footerController.text = invoice.footerText.value ?? '';
    _currency = invoice.currency.value;
    _exchangeRate = invoice.exchangeRate.value;
    _discountController.text = invoice.discountAmount.value.toString();
    _shippingController.text = invoice.shippingAmount.value.toString();
    _autoReminders = invoice.autoReminders.value;
    _reminderDaysBefore = invoice.reminderDaysBefore.value ?? 3;
    _autoFollowUp = invoice.autoFollowUp.value;
    
    // Load line items would require separate API call
    _loadExistingLineItems();
  }

  Future<void> _loadExistingLineItems() async {
    // This would load line items from the repository
    // For now, add a placeholder item
    _addEmptyLineItem();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Invoice' : 'Create Invoice'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          onTap: _onTabTapped,
          tabs: _stepTitles.asMap().entries.map((entry) {
            final index = entry.key;
            final title = entry.value;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: index <= _currentStep 
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: index <= _currentStep ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(title),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: [
            _buildBasicInfoStep(),
            _buildCustomerStep(),
            _buildLineItemsStep(),
            _buildSettingsStep(),
            _buildReviewStep(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Details',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _invoiceNumberController,
            decoration: const InputDecoration(
              labelText: 'Invoice Number *',
              hintText: 'Auto-generated if left empty',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              // Optional validation - can be auto-generated
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, _issueDate, 'Issue Date', (date) {
                    setState(() {
                      _issueDate = date;
                      _calculateDueDate();
                    });
                  }),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Issue Date *',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_formatDate(_issueDate)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, _dueDate ?? _issueDate, 'Due Date', (date) {
                    setState(() {
                      _dueDate = date;
                    });
                  }),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_dueDate != null ? _formatDate(_dueDate!) : 'Select date'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<PaymentTerm>(
            value: _paymentTerms,
            decoration: const InputDecoration(
              labelText: 'Payment Terms',
              border: OutlineInputBorder(),
            ),
            items: PaymentTerm.values.map((term) {
              return DropdownMenuItem(
                value: term,
                child: Text(_getPaymentTermDisplayName(term)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _paymentTerms = value;
                  _calculateDueDate();
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _poNumberController,
                  decoration: const InputDecoration(
                    labelText: 'PO Number',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: _showCustomerPicker,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_search),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedCustomerId != null 
                          ? 'Customer selected' 
                          : 'Select existing customer or create new',
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _customerNameController,
            decoration: const InputDecoration(
              labelText: 'Customer Name *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Customer name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _customerEmailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Enter a valid email address';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _billingAddressController,
            decoration: const InputDecoration(
              labelText: 'Billing Address',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _shippingAddressController.text == _billingAddressController.text,
                onChanged: (value) {
                  if (value == true) {
                    setState(() {
                      _shippingAddressController.text = _billingAddressController.text;
                    });
                  }
                },
              ),
              const Text('Same as billing address'),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _shippingAddressController,
            decoration: const InputDecoration(
              labelText: 'Shipping Address',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Line Items',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addEmptyLineItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _lineItems.length,
            itemBuilder: (context, index) {
              return LineItemForm(
                key: ValueKey(_lineItems[index]['id']),
                lineItem: _lineItems[index],
                onChanged: (updatedItem) {
                  setState(() {
                    _lineItems[index] = updatedItem;
                    _calculateTotals();
                  });
                },
                onRemove: _lineItems.length > 1 
                    ? () => _removeLineItem(index)
                    : null,
              );
            },
          ),
        ),
        _buildTotalsSection(),
      ],
    );
  }

  Widget _buildTotalsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _discountController,
                  decoration: const InputDecoration(
                    labelText: 'Discount Amount',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    _calculateTotals();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _shippingController,
                  decoration: const InputDecoration(
                    labelText: 'Shipping Amount',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    _calculateTotals();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTotalRow('Subtotal', _subtotal),
          _buildTaxBreakdown(),
          if (_discountAmount > 0) _buildTotalRow('Discount', -_discountAmount),
          if (_shippingAmount > 0) _buildTotalRow('Shipping', _shippingAmount),
          const Divider(),
          _buildTotalRow('Total', _totalAmount, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTaxBreakdown() {
    if (_lineItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group line items by GST category and rate
    final Map<String, List<Map<String, dynamic>>> taxGroups = {};
    for (final item in _lineItems) {
      final category = item['gst_category'] ?? 'standard';
      final rate = item['effective_gst_rate'] ?? 9.0;
      final key = '$category-${rate.toStringAsFixed(1)}';
      
      if (!taxGroups.containsKey(key)) {
        taxGroups[key] = [];
      }
      taxGroups[key]!.add(item);
    }

    // Build tax breakdown rows
    final List<Widget> taxRows = [];
    double totalTax = 0.0;

    for (final entry in taxGroups.entries) {
      final parts = entry.key.split('-');
      final category = parts[0];
      final rate = double.parse(parts[1]);
      final items = entry.value;
      
      double categoryTaxAmount = 0.0;
      for (final item in items) {
        categoryTaxAmount += item['gst_amount'] ?? 0.0;
      }
      
      totalTax += categoryTaxAmount;
      
      if (categoryTaxAmount > 0.0) {
        String taxLabel;
        switch (category) {
          case 'standard':
            taxLabel = 'GST (${rate.toStringAsFixed(1)}%)';
            break;
          case 'zeroRated':
            taxLabel = 'Zero-rated (0%)';
            break;
          case 'exempt':
            taxLabel = 'Exempt (0%)';
            break;
          default:
            taxLabel = 'Tax (${rate.toStringAsFixed(1)}%)';
        }
        
        taxRows.add(_buildTotalRow(taxLabel, categoryTaxAmount));

        // Add reasoning if available
        final reasoning = items.first['gst_reasoning'] as String?;
        if (reasoning != null && reasoning.isNotEmpty) {
          taxRows.add(
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                reasoning,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        }
      }
    }

    return Column(
      children: taxRows.isNotEmpty ? taxRows : [
        _buildTotalRow('Tax', totalTax),
      ],
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            '$_currency ${_formatAmount(amount)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                  ),
                  items: ['SGD', 'USD', 'EUR', 'GBP', 'JPY'].map((currency) {
                    return DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _currency = value;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: _exchangeRate.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Exchange Rate',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    final rate = double.tryParse(value);
                    if (rate != null) {
                      setState(() {
                        _exchangeRate = rate;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Automation Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Auto Reminders'),
            subtitle: const Text('Automatically send payment reminders'),
            value: _autoReminders,
            onChanged: (value) {
              setState(() {
                _autoReminders = value;
              });
            },
          ),
          if (_autoReminders)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                initialValue: _reminderDaysBefore.toString(),
                decoration: const InputDecoration(
                  labelText: 'Days before due date',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final days = int.tryParse(value);
                  if (days != null) {
                    setState(() {
                      _reminderDaysBefore = days;
                    });
                  }
                },
              ),
            ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Auto Follow-up'),
            subtitle: const Text('Automatically follow up on overdue invoices'),
            value: _autoFollowUp,
            onChanged: (value) {
              setState(() {
                _autoFollowUp = value;
              });
            },
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Internal notes (not shown on invoice)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _termsController,
            decoration: const InputDecoration(
              labelText: 'Terms & Conditions',
              hintText: 'Terms and conditions for this invoice',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _footerController,
            decoration: const InputDecoration(
              labelText: 'Footer Text',
              hintText: 'Text to appear at the bottom of the invoice',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Invoice',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildReviewSection('Invoice Details', [
            'Invoice Number: ${_invoiceNumberController.text.isNotEmpty ? _invoiceNumberController.text : 'Auto-generated'}',
            'Issue Date: ${_formatDate(_issueDate)}',
            'Due Date: ${_dueDate != null ? _formatDate(_dueDate!) : 'Not set'}',
            'Payment Terms: ${_getPaymentTermDisplayName(_paymentTerms)}',
            if (_poNumberController.text.isNotEmpty) 'PO Number: ${_poNumberController.text}',
            if (_referenceController.text.isNotEmpty) 'Reference: ${_referenceController.text}',
          ]),
          const SizedBox(height: 16),
          _buildReviewSection('Customer', [
            'Name: ${_customerNameController.text}',
            if (_customerEmailController.text.isNotEmpty) 'Email: ${_customerEmailController.text}',
            if (_billingAddressController.text.isNotEmpty) 'Billing: ${_billingAddressController.text}',
            if (_shippingAddressController.text.isNotEmpty) 'Shipping: ${_shippingAddressController.text}',
          ]),
          const SizedBox(height: 16),
          _buildReviewSection('Line Items (${_lineItems.length})', 
            _lineItems.map((item) => 
              '${item['description'] ?? 'Untitled'} - Qty: ${item['quantity'] ?? 1} @ $_currency ${_formatAmount(item['unit_price'] ?? 0)}'
            ).toList()
          ),
          const SizedBox(height: 16),
          _buildReviewSection('Totals', [
            'Subtotal: $_currency ${_formatAmount(_subtotal)}',
            'Tax: $_currency ${_formatAmount(_taxAmount)}',
            'Discount: $_currency ${_formatAmount(_discountAmount)}',
            'Shipping: $_currency ${_formatAmount(_shippingAmount)}',
            'Total: $_currency ${_formatAmount(_totalAmount)}',
          ]),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveInvoice,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: Text(
                  _isEditing ? 'Update Invoice' : 'Create Invoice',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(item),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Previous'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentStep < _stepTitles.length - 1 
                  ? _nextStep 
                  : _saveInvoice,
              child: Text(
                _currentStep < _stepTitles.length - 1 
                    ? 'Next' 
                    : (_isEditing ? 'Update' : 'Create'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTabTapped(int index) {
    if (index <= _currentStep || _validateCurrentStep()) {
      _goToStep(index);
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentStep = index;
      _tabController.animateTo(index);
    });
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      _goToStep(_currentStep + 1);
    }
  }

  void _previousStep() {
    _goToStep(_currentStep - 1);
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _tabController.animateTo(step);
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Basic Info
        return true; // Basic validation passed
      case 1: // Customer
        if (_customerNameController.text.isEmpty) {
          _showError('Customer name is required');
          return false;
        }
        return true;
      case 2: // Line Items
        if (_lineItems.isEmpty || _lineItems.every((item) => 
            (item['description'] ?? '').isEmpty && (item['unit_price'] ?? 0) == 0)) {
          _showError('At least one line item is required');
          return false;
        }
        return true;
      case 3: // Settings
        return true;
      case 4: // Review
        return _formKey.currentState?.validate() ?? false;
      default:
        return true;
    }
  }

  void _calculateDueDate() {
    if (_paymentTerms != PaymentTerm.custom) {
      setState(() {
        _dueDate = _issueDate.add(Duration(days: _paymentTerms.days));
      });
    }
  }

  void _calculateTotals() {
    double subtotal = 0.0;
    double taxAmount = 0.0;

    for (final item in _lineItems) {
      // Use the calculated values from line items
      subtotal += item['net_amount'] ?? 0.0;
      taxAmount += item['gst_amount'] ?? 0.0;
    }

    final discountAmount = double.tryParse(_discountController.text) ?? 0.0;
    final shippingAmount = double.tryParse(_shippingController.text) ?? 0.0;
    final totalAmount = subtotal + taxAmount - discountAmount + shippingAmount;

    setState(() {
      _subtotal = subtotal;
      _taxAmount = taxAmount;
      _discountAmount = discountAmount;
      _shippingAmount = shippingAmount;
      _totalAmount = totalAmount;
    });
  }

  void _addEmptyLineItem() {
    setState(() {
      _lineItems.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'description': '',
        'quantity': 1.0,
        'unit_price': 0.0,
        'tax_rate': 9.0, // Default GST rate
        'gst_category': 'standard', // Default to standard GST
        'tax_method': 'exclusive', // Default to tax exclusive
        'net_amount': 0.0,
        'gst_amount': 0.0,
        'line_total': 0.0,
      });
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
      _calculateTotals();
    });
  }

  void _showCustomerPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Select Customer',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: CustomerPicker(
                  customers: _customers,
                  selectedCustomerId: _selectedCustomerId,
                  onCustomerSelected: (customer) {
                    if (customer != null) {
                      setState(() {
                        _selectedCustomerId = customer.id;
                        _customerNameController.text = customer.name;
                        _customerEmailController.text = customer.email ?? '';
                        _billingAddressController.text = customer.address ?? '';
                      });
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectDate(BuildContext context, DateTime initialDate, String title, Function(DateTime) onDateSelected) {
    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: title,
    ).then((date) {
      if (date != null) {
        onDateSelected(date);
      }
    });
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = _isEditing 
          ? await _updateExistingInvoice()
          : await _createNewInvoice();

      if (result.success) {
        _showSuccess(_isEditing ? 'Invoice updated successfully' : 'Invoice created successfully');
        Navigator.of(context).pop(result.data);
      } else {
        _showError(result.errorMessage ?? 'Failed to save invoice');
      }
    } catch (e) {
      _showError('Failed to save invoice: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<InvoiceOperationResult<CRDTInvoiceEnhanced>> _createNewInvoice() async {
    return await widget.invoiceService.createInvoice(
      customerId: _selectedCustomerId ?? 'temp',
      customerName: _customerNameController.text,
      customerEmail: _customerEmailController.text.isNotEmpty ? _customerEmailController.text : null,
      billingAddress: _billingAddressController.text.isNotEmpty ? _billingAddressController.text : null,
      shippingAddress: _shippingAddressController.text.isNotEmpty ? _shippingAddressController.text : null,
      issueDate: _issueDate,
      dueDate: _dueDate,
      paymentTerms: _paymentTerms,
      poNumber: _poNumberController.text.isNotEmpty ? _poNumberController.text : null,
      reference: _referenceController.text.isNotEmpty ? _referenceController.text : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      termsAndConditions: _termsController.text.isNotEmpty ? _termsController.text : null,
      lineItems: _lineItems,
      currency: _currency,
      exchangeRate: _exchangeRate,
    );
  }

  Future<InvoiceOperationResult<CRDTInvoiceEnhanced>> _updateExistingInvoice() async {
    final updates = <String, dynamic>{
      'customer_name': _customerNameController.text,
      'customer_email': _customerEmailController.text.isNotEmpty ? _customerEmailController.text : null,
      'billing_address': _billingAddressController.text.isNotEmpty ? _billingAddressController.text : null,
      'shipping_address': _shippingAddressController.text.isNotEmpty ? _shippingAddressController.text : null,
      'issue_date': _issueDate.millisecondsSinceEpoch,
      'due_date': _dueDate?.millisecondsSinceEpoch,
      'po_number': _poNumberController.text.isNotEmpty ? _poNumberController.text : null,
      'reference': _referenceController.text.isNotEmpty ? _referenceController.text : null,
      'notes': _notesController.text.isNotEmpty ? _notesController.text : null,
      'terms_and_conditions': _termsController.text.isNotEmpty ? _termsController.text : null,
      'currency': _currency,
      'exchange_rate': _exchangeRate,
      'discount_amount': _discountAmount,
      'shipping_amount': _shippingAmount,
    };

    return await widget.invoiceService.updateInvoice(widget.invoiceId!, updates);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),  
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  String _getPaymentTermDisplayName(PaymentTerm term) {
    switch (term) {
      case PaymentTerm.net15:
        return 'Net 15 days';
      case PaymentTerm.net30:
        return 'Net 30 days';
      case PaymentTerm.net45:
        return 'Net 45 days';
      case PaymentTerm.net60:
        return 'Net 60 days';
      case PaymentTerm.net90:
        return 'Net 90 days';
      case PaymentTerm.dueOnReceipt:
        return 'Due on receipt';
      case PaymentTerm.custom:
        return 'Custom';
    }
  }
}