import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/customer.dart';
import '../repositories/customer_repository.dart';

class ProfessionalCustomerFormScreen extends ConsumerStatefulWidget {
  final String? customerId;

  const ProfessionalCustomerFormScreen({
    super.key,
    this.customerId,
  });

  @override
  ConsumerState<ProfessionalCustomerFormScreen> createState() =>
      _ProfessionalCustomerFormScreenState();
}

class _ProfessionalCustomerFormScreenState
    extends ConsumerState<ProfessionalCustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _billingAddressController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  final _uenController = TextEditingController();
  final _gstNumberController = TextEditingController();
  
  bool _isLoading = false;
  bool _isActive = true;
  bool _gstRegistered = false;
  String _countryCode = 'SG';
  Customer? _existingCustomer;
  
  bool get _isEditing => widget.customerId != null;

  final List<String> _countries = [
    'SG - Singapore',
    'MY - Malaysia', 
    'TH - Thailand',
    'ID - Indonesia',
    'VN - Vietnam',
    'PH - Philippines',
    'US - United States',
    'GB - United Kingdom',
    'AU - Australia',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadCustomer();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _billingAddressController.dispose();
    _shippingAddressController.dispose();
    _uenController.dispose();
    _gstNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);
    
    try {
      final repository = ref.read(customerRepositoryProvider);
      _existingCustomer = await repository.getCustomer(widget.customerId!);
      
      if (_existingCustomer != null) {
        _nameController.text = _existingCustomer!.name;
        _emailController.text = _existingCustomer!.email ?? '';
        _phoneController.text = _existingCustomer!.phone ?? '';
        _addressController.text = _existingCustomer!.address ?? '';
        _billingAddressController.text = _existingCustomer!.billingAddress ?? '';
        _shippingAddressController.text = _existingCustomer!.shippingAddress ?? '';
        _uenController.text = _existingCustomer!.uen ?? '';
        _gstNumberController.text = _existingCustomer!.gstRegistrationNumber ?? '';
        _isActive = _existingCustomer!.isActive;
        _gstRegistered = _existingCustomer!.gstRegistered;
        _countryCode = _existingCustomer!.countryCode ?? 'SG';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customer: $e')),
        );
      }
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Customer' : 'Add Customer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/customers'),
        ),
        actions: [
          FilledButton(
            onPressed: _isLoading ? null : _saveCustomer,
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
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name *',
                                hintText: 'Enter customer name',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'Enter email address',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value?.isNotEmpty == true) {
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                                    return 'Enter a valid email address';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '+65 9123 4567',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: '$_countryCode - ${_getCountryName(_countryCode)}',
                              decoration: const InputDecoration(
                                labelText: 'Country',
                                prefixIcon: Icon(Icons.public),
                                border: OutlineInputBorder(),
                              ),
                              items: _countries.map((country) => DropdownMenuItem(
                                value: country,
                                child: Text(country),
                              )).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _countryCode = value.split(' - ')[0];
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Active Customer'),
                              subtitle: const Text('Customer can receive invoices'),
                              value: _isActive,
                              onChanged: (value) => setState(() => _isActive = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Address Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Address Information',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'General Address',
                                hintText: 'Enter general address',
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _billingAddressController,
                              decoration: const InputDecoration(
                                labelText: 'Billing Address',
                                hintText: 'Enter billing address',
                                prefixIcon: Icon(Icons.receipt_long),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _shippingAddressController,
                              decoration: const InputDecoration(
                                labelText: 'Shipping Address',
                                hintText: 'Enter shipping address',
                                prefixIcon: Icon(Icons.local_shipping),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Tax Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tax Information',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _uenController,
                              decoration: const InputDecoration(
                                labelText: 'UEN (Unique Entity Number)',
                                hintText: 'Enter Singapore UEN',
                                prefixIcon: Icon(Icons.business),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('GST Registered'),
                              subtitle: const Text('Customer is registered for GST'),
                              value: _gstRegistered,
                              onChanged: (value) => setState(() => _gstRegistered = value),
                            ),
                            if (_gstRegistered) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _gstNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'GST Registration Number',
                                  hintText: '200012345M',
                                  prefixIcon: Icon(Icons.receipt),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (_gstRegistered && (value?.isEmpty ?? true)) {
                                    return 'GST number is required for GST registered customers';
                                  }
                                  if (value?.isNotEmpty == true) {
                                    if (!RegExp(r'^\d{9}[A-Z]$').hasMatch(value!)) {
                                      return 'Invalid GST number format (e.g., 200012345M)';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],
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

  String _getCountryName(String code) {
    switch (code) {
      case 'SG': return 'Singapore';
      case 'MY': return 'Malaysia';
      case 'TH': return 'Thailand';
      case 'ID': return 'Indonesia';
      case 'VN': return 'Vietnam';
      case 'PH': return 'Philippines';
      case 'US': return 'United States';
      case 'GB': return 'United Kingdom';
      case 'AU': return 'Australia';
      default: return 'Other';
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(customerRepositoryProvider);
      final now = DateTime.now();
      
      final customer = Customer(
        id: _existingCustomer?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        billingAddress: _billingAddressController.text.trim().isEmpty ? null : _billingAddressController.text.trim(),
        shippingAddress: _shippingAddressController.text.trim().isEmpty ? null : _shippingAddressController.text.trim(),
        uen: _uenController.text.trim().isEmpty ? null : _uenController.text.trim(),
        gstRegistrationNumber: _gstNumberController.text.trim().isEmpty ? null : _gstNumberController.text.trim(),
        countryCode: _countryCode,
        isActive: _isActive,
        gstRegistered: _gstRegistered,
        createdAt: _existingCustomer?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditing) {
        await repository.updateCustomer(customer);
      } else {
        await repository.createCustomer(customer);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Customer updated successfully' : 'Customer added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/customers');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving customer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }
}