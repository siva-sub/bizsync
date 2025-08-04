import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';
import '../providers/invoice_providers.dart';
import '../widgets/invoice_status_chip.dart';
import '../widgets/invoice_filters_sheet.dart';
import '../widgets/invoice_search_delegate.dart';
import '../widgets/invoice_actions_sheet.dart';

class ProfessionalInvoiceListScreen extends ConsumerStatefulWidget {
  const ProfessionalInvoiceListScreen({super.key});

  @override
  ConsumerState<ProfessionalInvoiceListScreen> createState() =>
      _ProfessionalInvoiceListScreenState();
}

class _ProfessionalInvoiceListScreenState
    extends ConsumerState<ProfessionalInvoiceListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final notifier = ref.read(invoiceListProvider.notifier);
      final state = ref.read(invoiceListProvider);
      if (!state.isLoading && state.hasMore) {
        notifier.loadInvoices();
      }
    }
  }

  void _showInvoiceActions(CRDTInvoiceEnhanced invoice) {
    showModalBottomSheet(
      context: context,
      builder: (context) => InvoiceActionsSheet(
        invoice: invoice,
        onEdit: () {
          Navigator.pop(context);
          context.go('/invoices/edit/${invoice.id}');
        },
        onDelete: () async {
          Navigator.pop(context);
          final confirmed = await _confirmDelete(invoice);
          if (confirmed) {
            ref.read(invoiceListProvider.notifier).deleteInvoice(invoice.id);
          }
        },
        onChangeStatus: (status) async {
          Navigator.pop(context);
          ref
              .read(invoiceListProvider.notifier)
              .changeInvoiceStatus(invoice.id, status);
        },
        onDuplicate: () {
          Navigator.pop(context);
          context.go('/invoices/duplicate/${invoice.id}');
        },
        onGeneratePayment: () {
          Navigator.pop(context);
          _showPaymentDialog(invoice);
        },
      ),
    );
  }

  Future<bool> _confirmDelete(CRDTInvoiceEnhanced invoice) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text(
          'Are you sure you want to delete invoice ${invoice.invoiceNumber.value}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showPaymentDialog(CRDTInvoiceEnhanced invoice) {
    // This would show SGQR payment generation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Payment'),
        content: const Text('SGQR payment generation coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFilters() {
    final state = ref.read(invoiceListProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InvoiceFiltersSheet(
        statusFilters: state.statusFilters,
        customerFilter: state.customerFilter,
        dateFromFilter: state.dateFromFilter,
        dateToFilter: state.dateToFilter,
        onFiltersChanged: (statuses, customerId, dateFrom, dateTo) {
          final notifier = ref.read(invoiceListProvider.notifier);
          notifier.filterByStatus(statuses);
          notifier.filterByCustomer(customerId);
          notifier.filterByDateRange(dateFrom, dateTo);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceListProvider);
    final notifier = ref.read(invoiceListProvider.notifier);
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    // Show error snackbar
    ref.listen<InvoiceListState>(invoiceListProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => notifier.loadInvoices(refresh: true),
            ),
          ),
        );
      }
    });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => notifier.loadInvoices(refresh: true),
        child: Column(
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
                            controller: _searchController,
                            hintText: 'Search invoices...',
                            leading: const Icon(Icons.search),
                            onChanged: (query) =>
                                notifier.searchInvoices(query),
                            trailing: [
                              if (state.searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    notifier.searchInvoices('');
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: _showFilters,
                          icon: const Icon(Icons.filter_list),
                          label: Text(_getActiveFiltersText(state)),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => context.go('/invoices/create'),
                          icon: const Icon(Icons.add),
                          label: const Text('New Invoice'),
                        ),
                      ],
                    ),
                    if (_hasActiveFilters(state)) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (state.statusFilters.isNotEmpty)
                            Chip(
                              label: Text(
                                  'Status: ${state.statusFilters.length} selected'),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => notifier.filterByStatus([]),
                            ),
                          if (state.customerFilter != null)
                            Chip(
                              label: const Text('Customer filtered'),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => notifier.filterByCustomer(null),
                            ),
                          if (state.dateFromFilter != null ||
                              state.dateToFilter != null)
                            Chip(
                              label: const Text('Date filtered'),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () =>
                                  notifier.filterByDateRange(null, null),
                            ),
                          if (_hasActiveFilters(state))
                            TextButton(
                              onPressed: () => notifier.clearFilters(),
                              child: const Text('Clear All'),
                            ),
                        ],
                      ),
                    ],
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
                    '${state.invoices.length} invoices',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const Spacer(),
                  if (state.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Invoice list
            Expanded(
              child: state.invoices.isEmpty && !state.isLoading
                  ? _buildEmptyState()
                  : _buildInvoiceList(state, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceList(InvoiceListState state, bool isDesktop) {
    if (isDesktop) {
      return _buildDataTable(state);
    } else {
      return _buildMobileList(state);
    }
  }

  Widget _buildDataTable(InvoiceListState state) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        minWidth: 900,
        columns: const [
          DataColumn2(
            label: Text('Invoice #'),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text('Customer'),
            size: ColumnSize.L,
          ),
          DataColumn2(
            label: Text('Date'),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text('Due Date'),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text('Amount'),
            size: ColumnSize.S,
            numeric: true,
          ),
          DataColumn2(
            label: Text('Status'),
            size: ColumnSize.S,
          ),
          DataColumn2(
            label: Text('Actions'),
            size: ColumnSize.S,
          ),
        ],
        rows: state.invoices.map((invoice) {
          return DataRow2(
            cells: [
              DataCell(
                Text(
                  invoice.invoiceNumber.value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => context.go('/invoices/view/${invoice.id}'),
              ),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      invoice.customerName.value ?? 'Unknown Customer',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (invoice.customerEmail.value != null)
                      Text(
                        invoice.customerEmail.value!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                  ],
                ),
                onTap: () => context.go('/invoices/view/${invoice.id}'),
              ),
              DataCell(
                Text(
                  '${invoice.issueDate.value.day}/${invoice.issueDate.value.month}/${invoice.issueDate.value.year}',
                ),
                onTap: () => context.go('/invoices/view/${invoice.id}'),
              ),
              DataCell(
                invoice.calculateDueDate() != null
                    ? Text(
                        '${invoice.calculateDueDate()!.day}/${invoice.calculateDueDate()!.month}/${invoice.calculateDueDate()!.year}',
                        style: TextStyle(
                          color: invoice.isOverdue ? Colors.red : null,
                          fontWeight:
                              invoice.isOverdue ? FontWeight.w600 : null,
                        ),
                      )
                    : const Text('-'),
                onTap: () => context.go('/invoices/view/${invoice.id}'),
              ),
              DataCell(
                Text(
                  '${invoice.currency.value} ${invoice.totalAmount.value.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => context.go('/invoices/view/${invoice.id}'),
              ),
              DataCell(
                InvoiceStatusChip(status: invoice.status.value),
                onTap: () => context.go('/invoices/view/${invoice.id}'),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showInvoiceActions(invoice),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileList(InvoiceListState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: state.invoices.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.invoices.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final invoice = state.invoices[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => context.go('/invoices/view/${invoice.id}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        invoice.invoiceNumber.value,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      InvoiceStatusChip(status: invoice.status.value),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    invoice.customerName.value ?? 'Unknown Customer',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (invoice.customerEmail.value != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      invoice.customerEmail.value!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Amount',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            Text(
                              '${invoice.currency.value} ${invoice.totalAmount.value.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Due Date',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            Text(
                              invoice.calculateDueDate() != null
                                  ? '${invoice.calculateDueDate()!.day}/${invoice.calculateDueDate()!.month}/${invoice.calculateDueDate()!.year}'
                                  : 'No due date',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        invoice.isOverdue ? Colors.red : null,
                                    fontWeight: invoice.isOverdue
                                        ? FontWeight.w600
                                        : null,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () => _showInvoiceActions(invoice),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No invoices found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first invoice to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/invoices/create'),
            icon: const Icon(Icons.add),
            label: const Text('Create Invoice'),
          ),
        ],
      ),
    );
  }

  String _getActiveFiltersText(InvoiceListState state) {
    final count = _getActiveFiltersCount(state);
    if (count == 0) return 'Filters';
    return 'Filters ($count)';
  }

  int _getActiveFiltersCount(InvoiceListState state) {
    int count = 0;
    if (state.statusFilters.isNotEmpty) count++;
    if (state.customerFilter != null) count++;
    if (state.dateFromFilter != null || state.dateToFilter != null) count++;
    return count;
  }

  bool _hasActiveFilters(InvoiceListState state) {
    return _getActiveFiltersCount(state) > 0;
  }
}
