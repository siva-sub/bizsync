import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/database/crdt_database_service.dart';
import '../../../core/database/transaction_manager.dart';
import '../../../core/database/conflict_resolver.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../../data/models/customer.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../presentation/providers/app_providers.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';
import '../repositories/invoice_repository.dart';
import '../services/invoice_service.dart';
import '../services/invoice_workflow_service.dart';
import '../services/invoice_calculation_service.dart';

// Core dependencies
final nodeIdProvider = Provider<String>((ref) {
  return 'bizsync_${DateTime.now().millisecondsSinceEpoch}';
});

// Database service provider - imported from app providers
// Remove this declaration since it should come from the main app providers

final transactionManagerProvider = Provider<TransactionManager>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.transactionManager;
});

final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return ConflictResolver();
});

// Service providers
final invoiceCalculationServiceProvider = Provider<InvoiceCalculationService>((ref) {
  return InvoiceCalculationService();
});

final invoiceWorkflowServiceProvider = Provider<InvoiceWorkflowService>((ref) {
  return InvoiceWorkflowService();
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final conflictResolver = ref.watch(conflictResolverProvider);
  final nodeId = ref.watch(nodeIdProvider);
  
  return InvoiceRepository(databaseService, conflictResolver, nodeId);
});

final invoiceServiceProvider = Provider<InvoiceService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final transactionManager = ref.watch(transactionManagerProvider);
  final workflowService = ref.watch(invoiceWorkflowServiceProvider);
  final calculationService = ref.watch(invoiceCalculationServiceProvider);
  final nodeId = ref.watch(nodeIdProvider);
  
  return InvoiceService(
    databaseService,
    transactionManager,
    workflowService,
    calculationService,
    nodeId,
  );
});

// State providers for invoice management
class InvoiceListState {
  final List<CRDTInvoiceEnhanced> invoices;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final List<InvoiceStatus> statusFilters;
  final String? customerFilter;
  final DateTime? dateFromFilter;
  final DateTime? dateToFilter;
  final bool hasMore;

  const InvoiceListState({
    this.invoices = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.statusFilters = const [],
    this.customerFilter,
    this.dateFromFilter,
    this.dateToFilter,
    this.hasMore = true,
  });

  InvoiceListState copyWith({
    List<CRDTInvoiceEnhanced>? invoices,
    bool? isLoading,
    String? error,
    String? searchQuery,
    List<InvoiceStatus>? statusFilters,
    String? customerFilter,
    DateTime? dateFromFilter,
    DateTime? dateToFilter,
    bool? hasMore,
  }) {
    return InvoiceListState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilters: statusFilters ?? this.statusFilters,
      customerFilter: customerFilter ?? this.customerFilter,
      dateFromFilter: dateFromFilter ?? this.dateFromFilter,
      dateToFilter: dateToFilter ?? this.dateToFilter,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class InvoiceListNotifier extends StateNotifier<InvoiceListState> {
  final InvoiceService _invoiceService;
  final InvoiceRepository _repository;

  InvoiceListNotifier(this._invoiceService, this._repository) : super(const InvoiceListState()) {
    loadInvoices();
  }

  Future<void> loadInvoices({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, error: null);
    } else if (state.isLoading) {
      return;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final filters = InvoiceSearchFilters(
        searchText: state.searchQuery.isEmpty ? null : state.searchQuery,
        statuses: state.statusFilters.isEmpty ? null : state.statusFilters,
        customerId: state.customerFilter,
        issueDateFrom: state.dateFromFilter,
        issueDateTo: state.dateToFilter,
        limit: 50,
        offset: refresh ? 0 : state.invoices.length,
        sortBy: 'updated_at',
        sortAscending: false,
      );

      final result = await _invoiceService.searchInvoices(filters);
      
      if (result.success && result.data != null) {
        final newInvoices = result.data!;
        final updatedInvoices = refresh 
            ? newInvoices 
            : [...state.invoices, ...newInvoices];
        
        state = state.copyWith(
          invoices: updatedInvoices,
          isLoading: false,
          hasMore: newInvoices.length >= 50,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.errorMessage ?? 'Failed to load invoices',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load invoices: $e',
      );
    }
  }

  Future<void> searchInvoices(String query) async {
    state = state.copyWith(searchQuery: query);
    await loadInvoices(refresh: true);
  }

  Future<void> filterByStatus(List<InvoiceStatus> statuses) async {
    state = state.copyWith(statusFilters: statuses);
    await loadInvoices(refresh: true);
  }

  Future<void> filterByCustomer(String? customerId) async {
    state = state.copyWith(customerFilter: customerId);
    await loadInvoices(refresh: true);
  }

  Future<void> filterByDateRange(DateTime? from, DateTime? to) async {
    state = state.copyWith(dateFromFilter: from, dateToFilter: to);
    await loadInvoices(refresh: true);
  }

  Future<void> clearFilters() async {
    state = const InvoiceListState();
    await loadInvoices(refresh: true);
  }

  Future<void> deleteInvoice(String invoiceId) async {
    try {
      final result = await _invoiceService.deleteInvoice(invoiceId);
      if (result.success) {
        // Remove from local state
        final updatedInvoices = state.invoices.where((i) => i.id != invoiceId).toList();
        state = state.copyWith(invoices: updatedInvoices);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete invoice: $e');
    }
  }

  Future<void> changeInvoiceStatus(String invoiceId, InvoiceStatus newStatus) async {
    try {
      final result = await _invoiceService.changeStatus(invoiceId, newStatus);
      if (result.success && result.data != null) {
        // Update local state
        final updatedInvoices = state.invoices.map((invoice) {
          return invoice.id == invoiceId ? result.data! : invoice;
        }).toList();
        state = state.copyWith(invoices: updatedInvoices);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update invoice status: $e');
    }
  }
}

final invoiceListProvider = StateNotifierProvider<InvoiceListNotifier, InvoiceListState>((ref) {
  final invoiceService = ref.watch(invoiceServiceProvider);
  final repository = ref.watch(invoiceRepositoryProvider);
  return InvoiceListNotifier(invoiceService, repository);
});

// Invoice form state
class InvoiceFormState {
  final CRDTInvoiceEnhanced? invoice;
  final List<CRDTInvoiceItem> lineItems;
  final List<Customer> customers;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? successMessage;
  final bool isEditing;

  const InvoiceFormState({
    this.invoice,
    this.lineItems = const [],
    this.customers = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.successMessage,
    this.isEditing = false,
  });

  InvoiceFormState copyWith({
    CRDTInvoiceEnhanced? invoice,
    List<CRDTInvoiceItem>? lineItems,
    List<Customer>? customers,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? successMessage,
    bool? isEditing,
  }) {
    return InvoiceFormState(
      invoice: invoice ?? this.invoice,
      lineItems: lineItems ?? this.lineItems,
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      successMessage: successMessage,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}

class InvoiceFormNotifier extends StateNotifier<InvoiceFormState> {
  final InvoiceService _invoiceService;
  final InvoiceRepository _repository;

  InvoiceFormNotifier(this._invoiceService, this._repository) : super(const InvoiceFormState());

  Future<void> loadInvoice(String invoiceId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _invoiceService.getInvoiceById(invoiceId);
      if (result.success && result.data != null) {
        final lineItems = await _repository.getInvoiceLineItems(invoiceId);
        state = state.copyWith(
          invoice: result.data,
          lineItems: lineItems,
          isLoading: false,
          isEditing: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.errorMessage ?? 'Invoice not found',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load invoice: $e',
      );
    }
  }

  Future<void> loadCustomers() async {
    try {
      final repository = CustomerRepository();
      final customers = await repository.getAllCustomers();
      state = state.copyWith(customers: customers);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load customers: $e');
    }
  }

  Future<void> createNewInvoice() async {
    final now = DateTime.now();
    final nodeId = 'bizsync_${now.millisecondsSinceEpoch}';
    final timestamp = HLCTimestamp.now(nodeId);
    
    final newInvoice = CRDTInvoiceEnhanced(
      id: UuidGenerator.generateId(),
      nodeId: nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(nodeId),
      invoiceNum: 'DRAFT-${now.millisecondsSinceEpoch}',
      issue: now,
      due: now.add(const Duration(days: 30)),
    );

    state = state.copyWith(
      invoice: newInvoice,
      lineItems: [],
      isEditing: false,
    );
  }

  Future<void> saveInvoice(Map<String, dynamic> invoiceData) async {
    state = state.copyWith(isSaving: true, error: null);
    
    try {
      if (state.isEditing && state.invoice != null) {
        // Update existing invoice
        final result = await _invoiceService.updateInvoice(state.invoice!.id, invoiceData);
        if (result.success && result.data != null) {
          state = state.copyWith(
            invoice: result.data,
            isSaving: false,
            successMessage: 'Invoice updated successfully',
          );
        } else {
          state = state.copyWith(
            isSaving: false,
            error: result.errorMessage ?? 'Failed to update invoice',
          );
        }
      } else {
        // Create new invoice
        final result = await _invoiceService.createInvoice(
          customerId: invoiceData['customer_id'],
          customerName: invoiceData['customer_name'],
          customerEmail: invoiceData['customer_email'],
          billingAddress: invoiceData['billing_address'],
          shippingAddress: invoiceData['shipping_address'],
          issueDate: DateTime.fromMillisecondsSinceEpoch(invoiceData['issue_date']),
          dueDate: invoiceData['due_date'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(invoiceData['due_date'])
              : null,
          paymentTerms: PaymentTerm.fromString(invoiceData['payment_terms'] ?? 'net_30'),
          poNumber: invoiceData['po_number'],
          reference: invoiceData['reference'],
          notes: invoiceData['notes'],
          termsAndConditions: invoiceData['terms_and_conditions'],
          lineItems: invoiceData['line_items'],
          customFields: invoiceData['custom_fields'],
          currency: invoiceData['currency'] ?? 'SGD',
          exchangeRate: invoiceData['exchange_rate']?.toDouble() ?? 1.0,
        );
        
        if (result.success && result.data != null) {
          state = state.copyWith(
            invoice: result.data,
            isSaving: false,
            successMessage: 'Invoice created successfully',
            isEditing: true,
          );
        } else {
          state = state.copyWith(
            isSaving: false,
            error: result.errorMessage ?? 'Failed to create invoice',
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'Failed to save invoice: $e',
      );
    }
  }

  Future<void> addLineItem(Map<String, dynamic> itemData) async {
    if (state.invoice == null) return;
    
    try {
      final result = await _invoiceService.addLineItem(state.invoice!.id, itemData);
      if (result.success && result.data != null) {
        final updatedItems = [...state.lineItems, result.data!];
        state = state.copyWith(lineItems: updatedItems);
        
        // Reload invoice to get updated totals
        await loadInvoice(state.invoice!.id);
      } else {
        state = state.copyWith(error: result.errorMessage ?? 'Failed to add line item');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to add line item: $e');
    }
  }

  Future<void> updateLineItem(String itemId, Map<String, dynamic> itemData) async {
    try {
      final result = await _invoiceService.updateLineItem(itemId, itemData);
      if (result.success && result.data != null) {
        final updatedItems = state.lineItems.map((item) {
          return item.id == itemId ? result.data! : item;
        }).toList();
        state = state.copyWith(lineItems: updatedItems);
        
        // Reload invoice to get updated totals
        if (state.invoice != null) {
          await loadInvoice(state.invoice!.id);
        }
      } else {
        state = state.copyWith(error: result.errorMessage ?? 'Failed to update line item');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update line item: $e');
    }
  }

  Future<void> removeLineItem(String itemId) async {
    try {
      final result = await _invoiceService.removeLineItem(itemId);
      if (result.success) {
        final updatedItems = state.lineItems.where((item) => item.id != itemId).toList();
        state = state.copyWith(lineItems: updatedItems);
        
        // Reload invoice to get updated totals
        if (state.invoice != null) {
          await loadInvoice(state.invoice!.id);
        }
      } else {
        state = state.copyWith(error: result.errorMessage ?? 'Failed to remove line item');
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove line item: $e');
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final invoiceFormProvider = StateNotifierProvider.family<InvoiceFormNotifier, InvoiceFormState, String?>((ref, invoiceId) {
  final invoiceService = ref.watch(invoiceServiceProvider);
  final repository = ref.watch(invoiceRepositoryProvider);
  final notifier = InvoiceFormNotifier(invoiceService, repository);
  
  if (invoiceId != null) {
    notifier.loadInvoice(invoiceId);
  } else {
    notifier.createNewInvoice();
  }
  
  notifier.loadCustomers();
  return notifier;
});

// Invoice detail provider
final invoiceDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, invoiceId) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return await repository.getInvoiceWithRelatedData(invoiceId);
});

// Invoice statistics provider
final invoiceStatisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return await repository.getInvoiceStatistics();
});

// Invoice workflow provider
final invoiceWorkflowProvider = FutureProvider.family<List<CRDTInvoiceWorkflow>, String>((ref, invoiceId) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return await repository.getInvoiceWorkflow(invoiceId);
});

// Invoice payments provider
final invoicePaymentsProvider = FutureProvider.family<List<CRDTInvoicePayment>, String>((ref, invoiceId) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  return await repository.getInvoicePayments(invoiceId);
});

// Customer repository provider
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

// Customers provider for dropdowns
final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final repository = ref.watch(customerRepositoryProvider);
  return await repository.getAllCustomers();
});

// SGQR generation provider
final sgqrProvider = FutureProvider.family<String?, Map<String, dynamic>>((ref, params) async {
  // This would generate SGQR code for invoice payment
  // Implementation would use the existing SGQR service
  return null;
});