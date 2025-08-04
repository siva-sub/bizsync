import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';
import '../providers/invoice_providers.dart';
import '../widgets/customer_picker.dart';
import '../widgets/line_item_form.dart';
import '../../../data/models/customer.dart';
import '../../../core/services/notification_service.dart';

class ProfessionalInvoiceFormScreen extends ConsumerStatefulWidget {
  final String? invoiceId;

  const ProfessionalInvoiceFormScreen({
    super.key,
    this.invoiceId,
  });

  @override
  ConsumerState<ProfessionalInvoiceFormScreen> createState() =>
      _ProfessionalInvoiceFormScreenState();
}

class _ProfessionalInvoiceFormScreenState
    extends ConsumerState<ProfessionalInvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _billingAddressController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  final _poNumberController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  final _termsController = TextEditingController();
  final _footerController = TextEditingController();
  
  String? _selectedCustomerId;
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  PaymentTerm _paymentTerms = PaymentTerm.net30;
  String _currency = 'SGD';
  double _exchangeRate = 1.0;
  bool _sameAsShipping = true;
  
  bool get _isEditing => widget.invoiceId != null;
  
  @override
  void initState() {
    super.initState();
    _dueDate = _issueDate.add(Duration(days: _paymentTerms.days));
  }
  
  @override
  void dispose() {
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _billingAddressController.dispose();
    _shippingAddressController.dispose();
    _poNumberController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(invoiceFormProvider(widget.invoiceId));
    final formNotifier = ref.read(invoiceFormProvider(widget.invoiceId).notifier);
    
    // Update form fields when invoice data loads
    if (formState.invoice != null && _isEditing) {
      _updateFormFields(formState.invoice!);
    }
    
    // Show loading indicator
    if (formState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Show error if loading failed
    if (formState.error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Invoice' : 'Create Invoice'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading invoice',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                formState.error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/invoices'),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ResponsiveBreakpoints.of(context).smallerThan(TABLET)
              ? (_isEditing ? 'Edit' : 'Create')
              : (_isEditing ? 'Edit Invoice' : 'Create Invoice'),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/invoices'),
        ),
        actions: [
          TextButton(
            onPressed: formState.isSaving ? null : () => _saveAsDraft(formNotifier),
            child: const Text('Save Draft'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: formState.isSaving ? null : () => _saveInvoice(formNotifier),
            child: formState.isSaving 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Update' : 'Create'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerSection(formState),
              const SizedBox(height: 24),
              _buildInvoiceDetailsSection(),
              const SizedBox(height: 24),
              _buildLineItemsSection(formState, formNotifier),
              const SizedBox(height: 24),
              _buildTotalsSection(formState),
              const SizedBox(height: 24),
              _buildNotesSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _updateFormFields(CRDTInvoiceEnhanced invoice) {
    if (_customerNameController.text.isEmpty) {
      _selectedCustomerId = invoice.customerId.value;
      _customerNameController.text = invoice.customerName.value ?? '';
      _customerEmailController.text = invoice.customerEmail.value ?? '';
      _billingAddressController.text = invoice.billingAddress.value ?? '';
      _shippingAddressController.text = invoice.shippingAddress.value ?? '';
      _poNumberController.text = invoice.poNumber.value ?? '';
      _referenceController.text = invoice.reference.value ?? '';
      _notesController.text = invoice.notes.value ?? '';
      _termsController.text = invoice.termsAndConditions.value ?? '';
      _footerController.text = invoice.footerText.value ?? '';
      _issueDate = invoice.issueDate.value;
      _dueDate = invoice.dueDate.value;
      _paymentTerms = invoice.paymentTerms.value;
      _currency = invoice.currency.value;
      _exchangeRate = invoice.exchangeRate.value;
    }
  }
  
  Widget _buildCustomerSection(InvoiceFormState formState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            CustomerPicker(
              selectedCustomerId: _selectedCustomerId,
              customers: formState.customers,
              onCustomerSelected: (customer) {
                setState(() {
                  _selectedCustomerId = customer?.id;
                  _customerNameController.text = customer?.name ?? '';
                  _customerEmailController.text = customer?.email ?? '';
                  _billingAddressController.text = customer?.address ?? '';
                  if (_sameAsShipping) {
                    _shippingAddressController.text = customer?.address ?? '';
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Customer name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerEmailController,
              decoration: const InputDecoration(
                labelText: 'Customer Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
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
            CheckboxListTile(
              title: const Text('Shipping address same as billing'),
              value: _sameAsShipping,
              onChanged: (value) {
                setState(() {
                  _sameAsShipping = value ?? true;
                  if (_sameAsShipping) {
                    _shippingAddressController.text = _billingAddressController.text;
                  }
                });
              },
            ),
            if (!_sameAsShipping) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _shippingAddressController,
                decoration: const InputDecoration(
                  labelText: 'Shipping Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildInvoiceDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invoice Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Issue Date',
                      border: OutlineInputBorder(),
                    ),
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _issueDate,
                          firstDate: DateTime(2020),
                          // Limit to reasonable future dates - max 1 year ahead
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          // Additional validation for issue dates - allow reasonable future dating
                          if (date.isAfter(DateTime.now().add(const Duration(days: 180)))) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invoice issue date cannot be more than 6 months in the future'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _issueDate = date;
                            if (_paymentTerms != PaymentTerm.custom) {
                              _dueDate = date.add(Duration(days: _paymentTerms.days));
                            }
                          });
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_issueDate.day}/${_issueDate.month}/${_issueDate.year}'),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<PaymentTerm>(
                    value: _paymentTerms,
                    decoration: const InputDecoration(
                      labelText: 'Payment Terms',
                      border: OutlineInputBorder(),
                    ),
                    items: PaymentTerm.values.map((term) {
                      return DropdownMenuItem(
                        value: term,
                        child: Text(term.value.replaceAll('_', ' ').toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _paymentTerms = value;
                          if (value != PaymentTerm.custom) {
                            _dueDate = _issueDate.add(Duration(days: value.days));
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due Date',
                      border: OutlineInputBorder(),
                    ),
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? _issueDate.add(const Duration(days: 30)),
                          firstDate: _issueDate,
                          // Due dates can be up to 1 year after issue date, but limit excessive future dates
                          lastDate: _issueDate.add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _dueDate = date;
                            _paymentTerms = PaymentTerm.custom;
                          });
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_dueDate != null 
                              ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                              : 'Select date'),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _currency,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            border: OutlineInputBorder(),
                          ),
                          items: ['SGD', 'USD', 'EUR', 'GBP', 'MYR']
                              .map((currency) => DropdownMenuItem(
                                    value: currency,
                                    child: Text(currency),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _currency = value;
                              });
                            }
                          },
                        ),
                      ),
                      if (_currency != 'SGD') ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            initialValue: _exchangeRate.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Rate',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _exchangeRate = double.tryParse(value) ?? 1.0;
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLineItemsSection(InvoiceFormState formState, InvoiceFormNotifier formNotifier) {
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
                  'Line Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _addLineItem(formNotifier),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (formState.lineItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No line items added yet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add items to your invoice using the button above',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
              ...formState.lineItems.map((item) => LineItemForm(
                key: ValueKey(item.id),
                item: item,
                onUpdate: (itemData) => formNotifier.updateLineItem(item.id, itemData),
                onDelete: () => formNotifier.removeLineItem(item.id),
              )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTotalsSection(InvoiceFormState formState) {
    final invoice = formState.invoice;
    if (invoice == null) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildTotalRow('Subtotal', invoice.subtotal.value, _currency),
            if (invoice.discountAmount.value > 0)
              _buildTotalRow('Discount', -invoice.discountAmount.value, _currency),
            if (invoice.shippingAmount.value > 0)
              _buildTotalRow('Shipping', invoice.shippingAmount.value, _currency),
            _buildTotalRow('Tax (GST)', invoice.taxAmount.value, _currency),
            const Divider(),
            _buildTotalRow(
              'Total',
              invoice.totalAmount.value,
              _currency,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTotalRow(String label, double amount, String currency, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '$currency ${amount.toStringAsFixed(2)}',
            style: isTotal
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                hintText: 'Internal notes (not visible to customer)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _termsController,
              decoration: const InputDecoration(
                labelText: 'Terms and Conditions',
                border: OutlineInputBorder(),
                hintText: 'Payment terms, conditions, etc.',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _footerController,
              decoration: const InputDecoration(
                labelText: 'Footer Text',
                border: OutlineInputBorder(),
                hintText: 'Thank you message, contact info, etc.',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
  
  void _addLineItem(InvoiceFormNotifier formNotifier) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Line Item'),
          content: const LineItemForm(
            onSave: null, // Will be handled by the dialog
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                // This would collect data from the LineItemForm
                final itemData = {
                  'description': 'New Item',
                  'quantity': 1.0,
                  'unit_price': 0.0,
                  'tax_rate': 7.0, // GST in Singapore
                  'item_type': 'product',
                  'tax_method': 'exclusive',
                };
                formNotifier.addLineItem(itemData);
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
  
  void _saveAsDraft(InvoiceFormNotifier formNotifier) async {
    final invoiceData = _buildInvoiceData();
    invoiceData['status'] = 'draft';
    
    await formNotifier.saveInvoice(invoiceData);
    
    final formState = ref.read(invoiceFormProvider(widget.invoiceId));
    if (formState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formState.error!),
          backgroundColor: Colors.red,
        ),
      );
    } else if (formState.successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formState.successMessage!),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  
  void _saveInvoice(InvoiceFormNotifier formNotifier) async {
    if (_formKey.currentState?.validate() ?? false) {
      final invoiceData = _buildInvoiceData();
      
      await formNotifier.saveInvoice(invoiceData);
      
      final formState = ref.read(invoiceFormProvider(widget.invoiceId));
      if (formState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formState.error!),
            backgroundColor: Colors.red,
          ),
        );
      } else if (formState.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formState.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to invoice list
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.go('/invoices');
          }
        });
      }
    }
  }
  
  Map<String, dynamic> _buildInvoiceData() {
    return {
      'customer_id': _selectedCustomerId,
      'customer_name': _customerNameController.text,
      'customer_email': _customerEmailController.text.isEmpty ? null : _customerEmailController.text,
      'billing_address': _billingAddressController.text.isEmpty ? null : _billingAddressController.text,
      'shipping_address': _shippingAddressController.text.isEmpty ? null : _shippingAddressController.text,
      'issue_date': _issueDate.millisecondsSinceEpoch,
      'due_date': _dueDate?.millisecondsSinceEpoch,
      'payment_terms': _paymentTerms.value,
      'po_number': _poNumberController.text.isEmpty ? null : _poNumberController.text,
      'reference': _referenceController.text.isEmpty ? null : _referenceController.text,
      'notes': _notesController.text.isEmpty ? null : _notesController.text,
      'terms_and_conditions': _termsController.text.isEmpty ? null : _termsController.text,
      'footer_text': _footerController.text.isEmpty ? null : _footerController.text,
      'currency': _currency,
      'exchange_rate': _exchangeRate,
    };
  }
}