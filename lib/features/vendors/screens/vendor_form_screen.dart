import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/vendor.dart';
import '../repositories/vendor_repository.dart';

class VendorFormScreen extends ConsumerStatefulWidget {
  final String? vendorId;

  const VendorFormScreen({
    super.key,
    this.vendorId,
  });

  @override
  ConsumerState<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends ConsumerState<VendorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isLoading = false;
  bool _isActive = true;
  String _countryCode = 'SG';
  String _paymentTerms = 'net30';
  Vendor? _existingVendor;
  
  bool get _isEditing => widget.vendorId != null;

  final List<String> _countries = [
    'SG - Singapore',
    'MY - Malaysia',
    'TH - Thailand', 
    'ID - Indonesia',
    'VN - Vietnam',
    'PH - Philippines',
    'CN - China',
    'IN - India',
    'US - United States',
    'GB - United Kingdom',
    'AU - Australia',
    'Other',
  ];

  final List<Map<String, String>> _paymentTermsOptions = [
    {'value': 'cod', 'label': 'Cash on Delivery'},
    {'value': 'advance', 'label': 'Advance Payment'},
    {'value': 'net7', 'label': 'Net 7 days'},
    {'value': 'net15', 'label': 'Net 15 days'},
    {'value': 'net30', 'label': 'Net 30 days'},
    {'value': 'net60', 'label': 'Net 60 days'},
    {'value': 'net90', 'label': 'Net 90 days'},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadVendor();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _bankAccountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadVendor() async {
    setState(() => _isLoading = true);
    
    try {
      final repository = ref.read(vendorRepositoryProvider);
      _existingVendor = await repository.getVendor(widget.vendorId!);
      
      if (_existingVendor != null) {
        _nameController.text = _existingVendor!.name;
        _emailController.text = _existingVendor!.email ?? '';
        _phoneController.text = _existingVendor!.phone ?? '';
        _addressController.text = _existingVendor!.address ?? '';
        _contactPersonController.text = _existingVendor!.contactPerson ?? '';
        _websiteController.text = _existingVendor!.website ?? '';
        _taxIdController.text = _existingVendor!.taxId ?? '';
        _bankAccountController.text = _existingVendor!.bankAccount ?? '';
        _notesController.text = _existingVendor!.notes ?? '';
        _isActive = _existingVendor!.isActive;
        _countryCode = _existingVendor!.countryCode ?? 'SG';
        _paymentTerms = _existingVendor!.paymentTerms ?? 'net30';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vendor: $e')),
        );
      }
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Vendor' : 'Add Vendor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/vendors'),
        ),
        actions: [
          FilledButton(
            onPressed: _isLoading ? null : _saveVendor,
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
                                labelText: 'Vendor Name *',
                                hintText: 'Enter vendor name',
                                prefixIcon: Icon(Icons.store),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Vendor name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _contactPersonController,
                              decoration: const InputDecoration(
                                labelText: 'Contact Person',
                                hintText: 'Enter contact person name',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
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
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    decoration: const InputDecoration(
                                      labelText: 'Phone Number',
                                      hintText: '+65 9123 4567',
                                      prefixIcon: Icon(Icons.phone),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _websiteController,
                              decoration: const InputDecoration(
                                labelText: 'Website',
                                hintText: 'https://example.com',
                                prefixIcon: Icon(Icons.language),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Active Vendor'),
                              subtitle: const Text('Vendor can receive purchase orders'),
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
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: 'Full Address',
                                hintText: 'Enter complete address',
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Financial Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Financial Information',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _paymentTerms,
                              decoration: const InputDecoration(
                                labelText: 'Payment Terms',
                                prefixIcon: Icon(Icons.payment),
                                border: OutlineInputBorder(),
                              ),
                              items: _paymentTermsOptions.map((term) => DropdownMenuItem(
                                value: term['value'],
                                child: Text(term['label']!),
                              )).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _paymentTerms = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _taxIdController,
                              decoration: const InputDecoration(
                                labelText: 'Tax ID / Registration Number',
                                hintText: 'Enter tax identification number',
                                prefixIcon: Icon(Icons.receipt),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _bankAccountController,
                              decoration: const InputDecoration(
                                labelText: 'Bank Account Details',
                                hintText: 'Enter bank account information',
                                prefixIcon: Icon(Icons.account_balance),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // Additional Information Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Additional Information',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                hintText: 'Enter any additional notes or comments',
                                prefixIcon: Icon(Icons.note),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                            ),
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
      case 'CN': return 'China';
      case 'IN': return 'India';
      case 'US': return 'United States';
      case 'GB': return 'United Kingdom';
      case 'AU': return 'Australia';
      default: return 'Other';
    }
  }

  Future<void> _saveVendor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(vendorRepositoryProvider);
      final now = DateTime.now();
      
      final vendor = Vendor(
        id: _existingVendor?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        contactPerson: _contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        taxId: _taxIdController.text.trim().isEmpty ? null : _taxIdController.text.trim(),
        bankAccount: _bankAccountController.text.trim().isEmpty ? null : _bankAccountController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        countryCode: _countryCode,
        paymentTerms: _paymentTerms,
        isActive: _isActive,
        createdAt: _existingVendor?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditing) {
        await repository.updateVendor(vendor);
      } else {
        await repository.createVendor(vendor);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Vendor updated successfully' : 'Vendor added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/vendors');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vendor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }
}