import 'package:flutter/material.dart';
import '../../../data/models/customer.dart';

/// Customer picker widget for invoice forms
class CustomerPicker extends StatefulWidget {
  final String? selectedCustomerId;
  final List<Customer> customers;
  final ValueChanged<Customer?> onCustomerSelected;
  final bool enabled;

  const CustomerPicker({
    Key? key,
    this.selectedCustomerId,
    required this.customers,
    required this.onCustomerSelected,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<CustomerPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _filteredCustomers = [];
  bool _showDropdown = false;
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _filteredCustomers = widget.customers;
    _selectedCustomer = widget.customers
        .where((c) => c.id == widget.selectedCustomerId)
        .firstOrNull;
    if (_selectedCustomer != null) {
      _searchController.text = _selectedCustomer!.name;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = widget.customers;
      } else {
        _filteredCustomers = widget.customers
            .where((customer) =>
                customer.name.toLowerCase().contains(query.toLowerCase()) ||
                (customer.email?.toLowerCase().contains(query.toLowerCase()) ??
                    false) ||
                (customer.uen?.toLowerCase().contains(query.toLowerCase()) ??
                    false))
            .toList();
      }
    });
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _searchController.text = customer.name;
      _showDropdown = false;
    });
    widget.onCustomerSelected(customer);
  }

  void _clearSelection() {
    setState(() {
      _selectedCustomer = null;
      _searchController.clear();
      _filteredCustomers = widget.customers;
      _showDropdown = false;
    });
    widget.onCustomerSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _searchController,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: 'Select Customer',
            hintText: 'Search by name, email, or UEN',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedCustomer != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: widget.enabled ? _clearSelection : null,
                    tooltip: 'Clear selection',
                  ),
                IconButton(
                  icon: Icon(
                      _showDropdown ? Icons.expand_less : Icons.expand_more),
                  onPressed: widget.enabled
                      ? () {
                          setState(() {
                            _showDropdown = !_showDropdown;
                          });
                        }
                      : null,
                  tooltip: 'Toggle dropdown',
                ),
              ],
            ),
          ),
          onChanged: widget.enabled
              ? (value) {
                  _filterCustomers(value);
                  setState(() {
                    _showDropdown = true;
                    if (value != _selectedCustomer?.name) {
                      _selectedCustomer = null;
                    }
                  });
                }
              : null,
          onTap: widget.enabled
              ? () {
                  setState(() {
                    _showDropdown = true;
                  });
                }
              : null,
        ),
        if (_showDropdown && widget.enabled) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _filteredCustomers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No customers found',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
                      final isSelected = customer.id == _selectedCustomer?.id;

                      return ListTile(
                        selected: isSelected,
                        title: Text(
                          customer.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (customer.email != null)
                              Text(
                                customer.email!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (customer.uen != null)
                              Text(
                                'UEN: ${customer.uen}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (customer.gstRegistered)
                              Chip(
                                label: const Text('GST'),
                                backgroundColor: Colors.green[100],
                                labelStyle: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[800],
                                ),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                          ],
                        ),
                        onTap: () => _selectCustomer(customer),
                      );
                    },
                  ),
          ),
        ],
        if (_selectedCustomer != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCustomer!.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (_selectedCustomer!.email != null)
                        Text(
                          _selectedCustomer!.email!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (_selectedCustomer!.uen != null)
                        Text(
                          'UEN: ${_selectedCustomer!.uen}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                    ],
                  ),
                ),
                if (_selectedCustomer!.gstRegistered)
                  Chip(
                    label: const Text('GST Registered'),
                    backgroundColor: Colors.green[100],
                    labelStyle: TextStyle(
                      fontSize: 10,
                      color: Colors.green[800],
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
