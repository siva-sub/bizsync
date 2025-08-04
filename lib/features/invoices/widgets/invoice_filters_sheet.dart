import 'package:flutter/material.dart';
import '../models/invoice_models.dart';
import '../services/invoice_service.dart';
import '../repositories/invoice_repository.dart';
import 'invoice_status_chip.dart';

class InvoiceFiltersSheet extends StatefulWidget {
  final InvoiceSearchFilters currentFilters;
  final InvoiceRepository repository;
  final List<InvoiceStatus> statusFilters;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final Function(List<InvoiceStatus>, DateTime?, DateTime?) onFiltersChanged;

  const InvoiceFiltersSheet({
    super.key,
    required this.currentFilters,
    required this.repository,
    required this.statusFilters,
    required this.onFiltersChanged,
    this.dateFromFilter,
    this.dateToFilter,
  });

  @override
  State<InvoiceFiltersSheet> createState() => _InvoiceFiltersSheetState();
}

class _InvoiceFiltersSheetState extends State<InvoiceFiltersSheet> {
  late List<InvoiceStatus> _selectedStatuses;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _selectedStatuses = List.from(widget.statusFilters);
    _dateFrom = widget.dateFromFilter;
    _dateTo = widget.dateToFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Filter Invoices',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearAll,
                child: const Text('Clear All'),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status Filter
          Text(
            'Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: InvoiceStatus.values.map((status) {
              final isSelected = _selectedStatuses.contains(status);
              return FilterChip(
                label: Text(_getStatusDisplayName(status)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedStatuses.add(status);
                    } else {
                      _selectedStatuses.remove(status);
                    }
                  });
                },
                avatar: isSelected
                    ? null
                    : InvoiceStatusChip(status: status).build(context),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Date Range Filter
          Text(
            'Date Range',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectFromDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _dateFrom != null
                        ? '${_dateFrom!.day}/${_dateFrom!.month}/${_dateFrom!.year}'
                        : 'From Date',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectToDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _dateTo != null
                        ? '${_dateTo!.day}/${_dateTo!.month}/${_dateTo!.year}'
                        : 'To Date',
                  ),
                ),
              ),
            ],
          ),
          if (_dateFrom != null || _dateTo != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _dateFrom = null;
                  _dateTo = null;
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear dates'),
            ),
          ],
          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _applyFilters,
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _selectFromDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _dateTo ?? DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _dateFrom = date;
      });
    }
  }

  void _selectToDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: _dateFrom ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _dateTo = date;
      });
    }
  }

  void _clearAll() {
    setState(() {
      _selectedStatuses.clear();
      _dateFrom = null;
      _dateTo = null;
    });
  }

  void _applyFilters() {
    widget.onFiltersChanged(
      _selectedStatuses,
      _dateFrom,
      _dateTo,
    );
    Navigator.of(context).pop();
  }

  String _getStatusDisplayName(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.approved:
        return 'Approved';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.viewed:
        return 'Viewed';
      case InvoiceStatus.partiallyPaid:
        return 'Partially Paid';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.disputed:
        return 'Disputed';
      case InvoiceStatus.voided:
        return 'Voided';
      case InvoiceStatus.refunded:
        return 'Refunded';
    }
  }
}
