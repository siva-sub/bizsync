import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';
import '../repositories/invoice_repository.dart';
import '../services/invoice_service.dart';
import '../widgets/invoice_card.dart';
import '../widgets/invoice_filters_sheet.dart';
import '../widgets/invoice_search_delegate.dart';

/// Invoice list screen with comprehensive filtering and search
class InvoiceListScreen extends StatefulWidget {
  final InvoiceRepository repository;
  final InvoiceService invoiceService;

  const InvoiceListScreen({
    Key? key,
    required this.repository,
    required this.invoiceService,
  }) : super(key: key);

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  
  List<CRDTInvoiceEnhanced> _invoices = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  
  InvoiceSearchFilters _currentFilters = const InvoiceSearchFilters();
  String _selectedTab = 'all';
  String _sortBy = 'updated_at';
  bool _sortAscending = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMore) {
        _loadMoreInvoices();
      }
    }
  }

  Future<void> _loadInvoices({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
      _invoices.clear();
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final filters = _buildFiltersForTab(_selectedTab);
      final result = await widget.invoiceService.searchInvoices(filters);
      
      if (result.success && result.data != null) {
        setState(() {
          if (refresh) {
            _invoices = result.data!;
          } else {
            _invoices.addAll(result.data!);
          }
          _hasMore = result.data!.length == _pageSize;
          _currentPage++;
        });
      }
    } catch (e) {
      _showError('Failed to load invoices: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreInvoices() async {
    await _loadInvoices();
  }

  InvoiceSearchFilters _buildFiltersForTab(String tab) {
    List<InvoiceStatus>? statuses;
    
    switch (tab) {
      case 'draft':
        statuses = [InvoiceStatus.draft, InvoiceStatus.pending];
        break;
      case 'sent':
        statuses = [InvoiceStatus.sent, InvoiceStatus.viewed];
        break;
      case 'paid':
        statuses = [InvoiceStatus.paid];
        break;
      case 'partial':
        statuses = [InvoiceStatus.partiallyPaid];
        break;
      case 'overdue':
        statuses = [InvoiceStatus.overdue];
        break;
      case 'disputed':
        statuses = [InvoiceStatus.disputed];
        break;
      default:
        statuses = null;
    }

    return InvoiceSearchFilters(
      statuses: statuses,
      customerId: _currentFilters.customerId,
      issueDateFrom: _currentFilters.issueDateFrom,
      issueDateTo: _currentFilters.issueDateTo,
      dueDateFrom: _currentFilters.dueDateFrom,
      dueDateTo: _currentFilters.dueDateTo,
      amountFrom: _currentFilters.amountFrom,
      amountTo: _currentFilters.amountTo,
      isOverdue: _currentFilters.isOverdue,
      isDisputed: _currentFilters.isDisputed,
      tags: _currentFilters.tags,
      searchText: _currentFilters.searchText,
      limit: _pageSize,
      offset: _currentPage * _pageSize,
      sortBy: _sortBy,
      sortAscending: _sortAscending,
    );
  }

  void _onTabChanged(int index) {
    final tabs = ['all', 'draft', 'sent', 'paid', 'partial', 'overdue', 'disputed'];
    _selectedTab = tabs[index];
    _loadInvoices(refresh: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context, 
                delegate: InvoiceSearchDelegate(invoices: _invoices),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFiltersSheet(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: _onSortSelected,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'invoice_number',
                child: Text('Invoice Number'),
              ),
              const PopupMenuItem(
                value: 'issue_date',
                child: Text('Issue Date'),
              ),
              const PopupMenuItem(
                value: 'due_date',
                child: Text('Due Date'),
              ),
              const PopupMenuItem(
                value: 'total_amount',
                child: Text('Amount'),
              ),
              const PopupMenuItem(
                value: 'status',
                child: Text('Status'),
              ),
              const PopupMenuItem(
                value: 'customer_name',
                child: Text('Customer'),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
              _loadInvoices(refresh: true);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: _onTabChanged,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Draft'),
            Tab(text: 'Sent'),
            Tab(text: 'Paid'),
            Tab(text: 'Partial'),
            Tab(text: 'Overdue'),
            Tab(text: 'Disputed'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_currentFilters != const InvoiceSearchFilters())
            _buildActiveFiltersChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadInvoices(refresh: true),
              child: _buildInvoiceList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateInvoice(),
        tooltip: 'Create Invoice',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    final chips = <Widget>[];
    
    if (_currentFilters.customerId != null) {
      chips.add(_buildFilterChip('Customer', () {
        setState(() {
          _currentFilters = InvoiceSearchFilters(
            statuses: _currentFilters.statuses,
            issueDateFrom: _currentFilters.issueDateFrom,
            issueDateTo: _currentFilters.issueDateTo,
            dueDateFrom: _currentFilters.dueDateFrom,
            dueDateTo: _currentFilters.dueDateTo,
            amountFrom: _currentFilters.amountFrom,
            amountTo: _currentFilters.amountTo,
            isOverdue: _currentFilters.isOverdue,
            isDisputed: _currentFilters.isDisputed,
            tags: _currentFilters.tags,
            searchText: _currentFilters.searchText,
          );
        });
        _loadInvoices(refresh: true);
      }));
    }

    if (_currentFilters.issueDateFrom != null || _currentFilters.issueDateTo != null) {
      chips.add(_buildFilterChip('Date Range', () {
        setState(() {
          _currentFilters = InvoiceSearchFilters(
            statuses: _currentFilters.statuses,
            customerId: _currentFilters.customerId,
            dueDateFrom: _currentFilters.dueDateFrom,
            dueDateTo: _currentFilters.dueDateTo,
            amountFrom: _currentFilters.amountFrom,
            amountTo: _currentFilters.amountTo,
            isOverdue: _currentFilters.isOverdue,
            isDisputed: _currentFilters.isDisputed,
            tags: _currentFilters.tags,
            searchText: _currentFilters.searchText,
          );
        });
        _loadInvoices(refresh: true);
      }));
    }

    if (_currentFilters.amountFrom != null || _currentFilters.amountTo != null) {
      chips.add(_buildFilterChip('Amount Range', () {
        setState(() {
          _currentFilters = InvoiceSearchFilters(
            statuses: _currentFilters.statuses,
            customerId: _currentFilters.customerId,
            issueDateFrom: _currentFilters.issueDateFrom,
            issueDateTo: _currentFilters.issueDateTo,
            dueDateFrom: _currentFilters.dueDateFrom,
            dueDateTo: _currentFilters.dueDateTo,
            isOverdue: _currentFilters.isOverdue,
            isDisputed: _currentFilters.isDisputed,
            tags: _currentFilters.tags,
            searchText: _currentFilters.searchText,
          );
        });
        _loadInvoices(refresh: true);
      }));
    }

    if (_currentFilters.tags != null && _currentFilters.tags!.isNotEmpty) {
      chips.add(_buildFilterChip('Tags', () {
        setState(() {
          _currentFilters = InvoiceSearchFilters(
            statuses: _currentFilters.statuses,
            customerId: _currentFilters.customerId,
            issueDateFrom: _currentFilters.issueDateFrom,
            issueDateTo: _currentFilters.issueDateTo,
            dueDateFrom: _currentFilters.dueDateFrom,
            dueDateTo: _currentFilters.dueDateTo,
            amountFrom: _currentFilters.amountFrom,
            amountTo: _currentFilters.amountTo,
            isOverdue: _currentFilters.isOverdue,
            isDisputed: _currentFilters.isDisputed,
            searchText: _currentFilters.searchText,
          );
        });
        _loadInvoices(refresh: true);
      }));
    }

    if (chips.isNotEmpty) {
      chips.add(
        TextButton(
          onPressed: () {
            setState(() {
              _currentFilters = const InvoiceSearchFilters();
            });
            _loadInvoices(refresh: true);
          },
          child: const Text('Clear All'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        children: chips,
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 18),
    );
  }

  Widget _buildInvoiceList() {
    if (_isLoading && _invoices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_invoices.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: _invoices.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _invoices.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final invoice = _invoices[index];
        return InvoiceCard(
          invoice: invoice,
          onTap: () => _navigateToInvoiceDetail(invoice.id),
          onStatusChanged: _onInvoiceStatusChanged,
          onPaymentRecorded: _onPaymentRecorded,
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
          ElevatedButton.icon(
            onPressed: () => _navigateToCreateInvoice(),
            icon: const Icon(Icons.add),
            label: const Text('Create Invoice'),
          ),
        ],
      ),
    );
  }

  void _showFiltersSheet() {
    showModalBottomSheet<InvoiceSearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InvoiceFiltersSheet(
        currentFilters: _currentFilters,
        repository: widget.repository,
        statusFilters: _currentFilters.statuses ?? [],
        dateFromFilter: _currentFilters.issueDateFrom,
        dateToFilter: _currentFilters.issueDateTo,
        onFiltersChanged: (statuses, dateFrom, dateTo) {
          Navigator.of(context).pop(InvoiceSearchFilters(
            statuses: statuses,
            issueDateFrom: dateFrom,
            issueDateTo: dateTo,
          ));
        },
      ),
    ).then((filters) {
      if (filters != null) {
        setState(() {
          _currentFilters = filters;
        });
        _loadInvoices(refresh: true);
      }
    });
  }

  void _onSortSelected(String sortBy) {
    setState(() {
      _sortBy = sortBy;
    });
    _loadInvoices(refresh: true);
  }

  void _navigateToCreateInvoice() {
    context.go('/invoices/create');
    // Note: Consider using refresh callback when returning from create screen
  }

  void _navigateToInvoiceDetail(String invoiceId) {
    context.go('/invoices/detail/$invoiceId');
    // Note: Consider using refresh callback when returning from detail screen
  }

  void _onInvoiceStatusChanged(String invoiceId, InvoiceStatus newStatus) async {
    try {
      final result = await widget.invoiceService.changeStatus(
        invoiceId,
        newStatus,
        triggeredBy: 'user',
        reason: 'Status changed from invoice list',
      );

      if (result.success) {
        _showSuccess('Invoice status updated successfully');
        _loadInvoices(refresh: true);
      } else {
        _showError(result.errorMessage ?? 'Failed to update status');
      }
    } catch (e) {
      _showError('Failed to update status: $e');
    }
  }

  void _onPaymentRecorded(String invoiceId, double amount) async {
    try {
      final result = await widget.invoiceService.recordPayment(
        invoiceId: invoiceId,
        amount: amount,
        paymentMethod: 'manual',
        paymentDate: DateTime.now(),
        notes: 'Payment recorded from invoice list',
      );

      if (result.success) {
        _showSuccess('Payment recorded successfully');
        _loadInvoices(refresh: true);
      } else {
        _showError(result.errorMessage ?? 'Failed to record payment');
      }
    } catch (e) {
      _showError('Failed to record payment: $e');
    }
  }
}