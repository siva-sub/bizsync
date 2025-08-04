import 'dart:async';
import 'dart:convert';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/database/crdt_database_service.dart';
import '../../../core/database/conflict_resolver.dart';
import '../../../core/utils/uuid_generator.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';
import '../services/invoice_service.dart';

/// Invoice query builder for complex database queries
class InvoiceQueryBuilder {
  final Map<String, dynamic> _filters = {};
  final List<String> _orderBy = [];
  int? _limit;
  int? _offset;

  InvoiceQueryBuilder whereStatus(List<InvoiceStatus> statuses) {
    _filters['status_in'] = statuses.map((s) => s.value).toList();
    return this;
  }

  InvoiceQueryBuilder whereCustomer(String customerId) {
    _filters['customer_id'] = customerId;
    return this;
  }

  InvoiceQueryBuilder whereDateRange(DateTime from, DateTime to,
      {String field = 'issue_date'}) {
    _filters['${field}_from'] = from.millisecondsSinceEpoch;
    _filters['${field}_to'] = to.millisecondsSinceEpoch;
    return this;
  }

  InvoiceQueryBuilder whereAmountRange(double from, double to) {
    _filters['total_amount_from'] = from;
    _filters['total_amount_to'] = to;
    return this;
  }

  InvoiceQueryBuilder whereOverdue(bool isOverdue) {
    _filters['is_overdue'] = isOverdue;
    return this;
  }

  InvoiceQueryBuilder whereDisputed(bool isDisputed) {
    _filters['is_disputed'] = isDisputed;
    return this;
  }

  InvoiceQueryBuilder whereDeleted(bool includeDeleted) {
    _filters['include_deleted'] = includeDeleted;
    return this;
  }

  InvoiceQueryBuilder whereInvoiceNumber(String invoiceNumber) {
    _filters['invoice_number'] = invoiceNumber;
    return this;
  }

  InvoiceQueryBuilder whereTags(List<String> tags, {bool matchAll = false}) {
    _filters['tags'] = tags;
    _filters['tags_match_all'] = matchAll;
    return this;
  }

  InvoiceQueryBuilder whereSearchText(String searchText) {
    _filters['search_text'] = searchText;
    return this;
  }

  InvoiceQueryBuilder orderBy(String field, {bool ascending = true}) {
    _orderBy.add('${field}_${ascending ? 'asc' : 'desc'}');
    return this;
  }

  InvoiceQueryBuilder limit(int limit) {
    _limit = limit;
    return this;
  }

  InvoiceQueryBuilder offset(int offset) {
    _offset = offset;
    return this;
  }

  Map<String, dynamic> build() {
    final query = Map<String, dynamic>.from(_filters);
    if (_orderBy.isNotEmpty) query['order_by'] = _orderBy;
    if (_limit != null) query['limit'] = _limit;
    if (_offset != null) query['offset'] = _offset;
    return query;
  }
}

/// Repository for invoice-related database operations
class InvoiceRepository {
  final CRDTDatabaseService _databaseService;
  final ConflictResolver _conflictResolver;
  final String _nodeId;

  InvoiceRepository(
    this._databaseService,
    this._conflictResolver,
    this._nodeId,
  );

  /// Create a new invoice
  Future<CRDTInvoiceEnhanced> createInvoice(CRDTInvoiceEnhanced invoice) async {
    await _databaseService.upsertEntity('invoices', invoice);
    return invoice;
  }

  /// Update an existing invoice
  Future<CRDTInvoiceEnhanced> updateInvoice(CRDTInvoiceEnhanced invoice) async {
    // Handle potential conflicts
    final existing = await getInvoiceById(invoice.id);
    if (existing != null) {
      // Merge with existing version
      existing.mergeWith(invoice);
      await _databaseService.upsertEntity('invoices', existing);
      return existing;
    } else {
      await _databaseService.upsertEntity('invoices', invoice);
      return invoice;
    }
  }

  /// Get invoice by ID
  Future<CRDTInvoiceEnhanced?> getInvoiceById(String invoiceId) async {
    final entity = await _databaseService.getEntity('invoices', invoiceId);
    return entity as CRDTInvoiceEnhanced?;
  }

  /// Get invoice by invoice number
  Future<CRDTInvoiceEnhanced?> getInvoiceByNumber(String invoiceNumber) async {
    final results = await queryInvoices(
      InvoiceQueryBuilder().whereInvoiceNumber(invoiceNumber).limit(1).build(),
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Query invoices with complex filters
  Future<List<CRDTInvoiceEnhanced>> queryInvoices(
      Map<String, dynamic> query) async {
    // This would implement complex SQL-like queries against the CRDT database
    // For now, return a simulated result
    final entities = await _databaseService.queryEntities('invoices', query);
    return entities.cast<CRDTInvoiceEnhanced>();
  }

  /// Get invoices with pagination
  Future<List<CRDTInvoiceEnhanced>> getInvoices({
    int limit = 50,
    int offset = 0,
    List<InvoiceStatus>? statuses,
    String? customerId,
    DateTime? fromDate,
    DateTime? toDate,
    String? sortBy,
    bool sortAscending = true,
  }) async {
    final query = InvoiceQueryBuilder().limit(limit).offset(offset);

    if (statuses != null && statuses.isNotEmpty) {
      query.whereStatus(statuses);
    }

    if (customerId != null) {
      query.whereCustomer(customerId);
    }

    if (fromDate != null && toDate != null) {
      query.whereDateRange(fromDate, toDate);
    }

    if (sortBy != null) {
      query.orderBy(sortBy, ascending: sortAscending);
    }

    return queryInvoices(query.build());
  }

  /// Get overdue invoices
  Future<List<CRDTInvoiceEnhanced>> getOverdueInvoices() async {
    return queryInvoices(
      InvoiceQueryBuilder()
          .whereOverdue(true)
          .whereStatus([
            InvoiceStatus.sent,
            InvoiceStatus.viewed,
            InvoiceStatus.partiallyPaid,
            InvoiceStatus.overdue,
          ])
          .orderBy('due_date', ascending: true)
          .build(),
    );
  }

  /// Get disputed invoices
  Future<List<CRDTInvoiceEnhanced>> getDisputedInvoices() async {
    return queryInvoices(
      InvoiceQueryBuilder()
          .whereDisputed(true)
          .orderBy('dispute_date', ascending: false)
          .build(),
    );
  }

  /// Get invoices by customer
  Future<List<CRDTInvoiceEnhanced>> getInvoicesByCustomer(
    String customerId, {
    int limit = 100,
    List<InvoiceStatus>? statuses,
  }) async {
    final query = InvoiceQueryBuilder()
        .whereCustomer(customerId)
        .limit(limit)
        .orderBy('issue_date', ascending: false);

    if (statuses != null && statuses.isNotEmpty) {
      query.whereStatus(statuses);
    }

    return queryInvoices(query.build());
  }

  /// Search invoices by text
  Future<List<CRDTInvoiceEnhanced>> searchInvoices(
    String searchText, {
    int limit = 50,
    int offset = 0,
  }) async {
    return queryInvoices(
      InvoiceQueryBuilder()
          .whereSearchText(searchText)
          .limit(limit)
          .offset(offset)
          .orderBy('updated_at', ascending: false)
          .build(),
    );
  }

  /// Get invoice statistics
  Future<Map<String, dynamic>> getInvoiceStatistics({
    String? customerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = InvoiceQueryBuilder().whereDeleted(false);

    if (customerId != null) {
      query.whereCustomer(customerId);
    }

    if (fromDate != null && toDate != null) {
      query.whereDateRange(fromDate, toDate);
    }

    final invoices = await queryInvoices(query.build());

    final stats = <String, dynamic>{};
    final statusCounts = <String, int>{};
    double totalAmount = 0.0;
    double paidAmount = 0.0;
    double overdueAmount = 0.0;
    int overdueCount = 0;
    int disputedCount = 0;

    for (final invoice in invoices) {
      final status = invoice.status.value.value;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      totalAmount += invoice.totalAmount.value;

      if (invoice.status.value == InvoiceStatus.paid) {
        paidAmount += invoice.totalAmount.value;
      }

      if (invoice.isOverdue) {
        overdueAmount += invoice.remainingBalance;
        overdueCount++;
      }

      if (invoice.isDisputed.value) {
        disputedCount++;
      }
    }

    stats['total_invoices'] = invoices.length;
    stats['status_breakdown'] = statusCounts;
    stats['total_amount'] = totalAmount;
    stats['paid_amount'] = paidAmount;
    stats['outstanding_amount'] = totalAmount - paidAmount;
    stats['overdue_amount'] = overdueAmount;
    stats['overdue_count'] = overdueCount;
    stats['disputed_count'] = disputedCount;
    stats['average_invoice_value'] =
        invoices.isEmpty ? 0.0 : totalAmount / invoices.length;
    stats['payment_rate'] =
        totalAmount > 0 ? (paidAmount / totalAmount) * 100 : 0.0;

    return stats;
  }

  /// Delete invoice (soft delete)
  Future<void> deleteInvoice(String invoiceId) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice != null) {
      final timestamp = HLCTimestamp.now(_nodeId);
      invoice.isDeleted = true;
      invoice.updatedAt = timestamp;
      invoice.version = invoice.version.tick();

      await _databaseService.upsertEntity('invoices', invoice);
    }
  }

  /// Restore deleted invoice
  Future<void> restoreInvoice(String invoiceId) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice != null && invoice.isDeleted) {
      final timestamp = HLCTimestamp.now(_nodeId);
      invoice.isDeleted = false;
      invoice.updatedAt = timestamp;
      invoice.version = invoice.version.tick();

      await _databaseService.upsertEntity('invoices', invoice);
    }
  }

  /// Line Item Operations

  /// Create line item
  Future<CRDTInvoiceItem> createLineItem(CRDTInvoiceItem item) async {
    await _databaseService.upsertEntity('invoice_items', item);
    return item;
  }

  /// Update line item
  Future<CRDTInvoiceItem> updateLineItem(CRDTInvoiceItem item) async {
    final existing = await getLineItemById(item.id);
    if (existing != null) {
      existing.mergeWith(item);
      await _databaseService.upsertEntity('invoice_items', existing);
      return existing;
    } else {
      await _databaseService.upsertEntity('invoice_items', item);
      return item;
    }
  }

  /// Get line item by ID
  Future<CRDTInvoiceItem?> getLineItemById(String itemId) async {
    final entity = await _databaseService.getEntity('invoice_items', itemId);
    return entity as CRDTInvoiceItem?;
  }

  /// Get line items for invoice
  Future<List<CRDTInvoiceItem>> getInvoiceLineItems(String invoiceId) async {
    final entities = await _databaseService.queryEntities('invoice_items', {
      'invoice_id': invoiceId,
      'include_deleted': false,
    });

    final items = entities.cast<CRDTInvoiceItem>();
    items.sort((a, b) => a.sortOrder.value.compareTo(b.sortOrder.value));
    return items;
  }

  /// Delete line item
  Future<void> deleteLineItem(String itemId) async {
    final item = await getLineItemById(itemId);
    if (item != null) {
      final timestamp = HLCTimestamp.now(_nodeId);
      item.isDeleted = true;
      item.updatedAt = timestamp;
      item.version = item.version.tick();

      await _databaseService.upsertEntity('invoice_items', item);
    }
  }

  /// Payment Operations

  /// Create payment
  Future<CRDTInvoicePayment> createPayment(CRDTInvoicePayment payment) async {
    await _databaseService.upsertEntity('invoice_payments', payment);
    return payment;
  }

  /// Update payment
  Future<CRDTInvoicePayment> updatePayment(CRDTInvoicePayment payment) async {
    final existing = await getPaymentById(payment.id);
    if (existing != null) {
      existing.mergeWith(payment);
      await _databaseService.upsertEntity('invoice_payments', existing);
      return existing;
    } else {
      await _databaseService.upsertEntity('invoice_payments', payment);
      return payment;
    }
  }

  /// Get payment by ID
  Future<CRDTInvoicePayment?> getPaymentById(String paymentId) async {
    final entity =
        await _databaseService.getEntity('invoice_payments', paymentId);
    return entity as CRDTInvoicePayment?;
  }

  /// Get payments for invoice
  Future<List<CRDTInvoicePayment>> getInvoicePayments(String invoiceId) async {
    final entities = await _databaseService.queryEntities('invoice_payments', {
      'invoice_id': invoiceId,
      'include_deleted': false,
    });

    final payments = entities.cast<CRDTInvoicePayment>();
    payments.sort((a, b) => b.paymentDate.value.compareTo(a.paymentDate.value));
    return payments;
  }

  /// Delete payment
  Future<void> deletePayment(String paymentId) async {
    final payment = await getPaymentById(paymentId);
    if (payment != null) {
      final timestamp = HLCTimestamp.now(_nodeId);
      payment.isDeleted = true;
      payment.updatedAt = timestamp;
      payment.version = payment.version.tick();

      await _databaseService.upsertEntity('invoice_payments', payment);
    }
  }

  /// Workflow Operations

  /// Create workflow entry
  Future<CRDTInvoiceWorkflow> createWorkflowEntry(
      CRDTInvoiceWorkflow workflow) async {
    await _databaseService.upsertEntity('invoice_workflow', workflow);
    return workflow;
  }

  /// Get workflow entries for invoice
  Future<List<CRDTInvoiceWorkflow>> getInvoiceWorkflow(String invoiceId) async {
    final entities = await _databaseService.queryEntities('invoice_workflow', {
      'invoice_id': invoiceId,
      'include_deleted': false,
    });

    final workflow = entities.cast<CRDTInvoiceWorkflow>();
    workflow.sort((a, b) => b.timestamp.value.compareTo(a.timestamp.value));
    return workflow;
  }

  /// Batch Operations

  /// Batch update invoices
  Future<List<CRDTInvoiceEnhanced>> batchUpdateInvoices(
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    final results = <CRDTInvoiceEnhanced>[];

    for (final invoice in invoices) {
      final updated = await updateInvoice(invoice);
      results.add(updated);
    }

    return results;
  }

  /// Batch create invoices
  Future<List<CRDTInvoiceEnhanced>> batchCreateInvoices(
    List<CRDTInvoiceEnhanced> invoices,
  ) async {
    for (final invoice in invoices) {
      await _databaseService.upsertEntity('invoices', invoice);
    }
    return invoices;
  }

  /// Data Integrity and Maintenance

  /// Validate data integrity
  Future<List<String>> validateDataIntegrity() async {
    final issues = <String>[];

    // Check for orphaned line items
    final allItems = await _databaseService.queryEntities('invoice_items', {});
    for (final item in allItems.cast<CRDTInvoiceItem>()) {
      final invoice = await getInvoiceById(item.invoiceId.value);
      if (invoice == null) {
        issues.add('Orphaned line item: ${item.id}');
      }
    }

    // Check for orphaned payments
    final allPayments =
        await _databaseService.queryEntities('invoice_payments', {});
    for (final payment in allPayments.cast<CRDTInvoicePayment>()) {
      final invoice = await getInvoiceById(payment.invoiceId.value);
      if (invoice == null) {
        issues.add('Orphaned payment: ${payment.id}');
      }
    }

    // Check for calculation inconsistencies
    final allInvoices = await queryInvoices({});
    for (final invoice in allInvoices) {
      final items = await getInvoiceLineItems(invoice.id);
      double calculatedSubtotal = 0.0;

      for (final item in items) {
        calculatedSubtotal += item.lineTotal.value;
      }

      const tolerance = 0.01;
      if ((calculatedSubtotal - invoice.subtotal.value).abs() > tolerance) {
        issues.add(
            'Calculation mismatch for invoice: ${invoice.invoiceNumber.value}');
      }
    }

    return issues;
  }

  /// Clean up deleted records
  Future<int> cleanupDeletedRecords({DateTime? olderThan}) async {
    final cutoffDate =
        olderThan ?? DateTime.now().subtract(const Duration(days: 90));
    int cleanedCount = 0;

    // Clean up deleted invoices
    final deletedInvoices = await queryInvoices({
      'is_deleted': true,
      'updated_at_before': cutoffDate.millisecondsSinceEpoch,
    });

    for (final invoice in deletedInvoices) {
      await _databaseService.deleteEntity('invoices', invoice.id);
      cleanedCount++;
    }

    return cleanedCount;
  }

  /// Synchronization and Conflict Resolution

  /// Merge conflicting invoices
  Future<CRDTInvoiceEnhanced> mergeConflictingInvoices(
    CRDTInvoiceEnhanced local,
    CRDTInvoiceEnhanced remote,
  ) async {
    // Create conflict object
    final conflict = DataConflict<CRDTInvoiceEnhanced>(
      id: local.id,
      type: ConflictType.concurrent,
      localVersion: local,
      remoteVersion: remote,
      detectedAt: DateTime.now(),
      tableName: 'invoices',
    );

    // Use conflict resolver to merge
    final resolution = await _conflictResolver.resolveConflict(conflict);
    await _databaseService.upsertEntity('invoices', resolution.resolvedValue);
    return resolution.resolvedValue;
  }

  /// Get invoices modified since timestamp
  Future<List<CRDTInvoiceEnhanced>> getInvoicesModifiedSince(
      DateTime timestamp) async {
    return queryInvoices({
      'updated_at_after': timestamp.millisecondsSinceEpoch,
    });
  }

  /// Get invoice changes for synchronization
  Future<Map<String, dynamic>> getInvoiceChanges(
    DateTime since, {
    int limit = 1000,
  }) async {
    final invoices = await getInvoicesModifiedSince(since);

    return {
      'invoices': invoices.map((i) => i.toCRDTJson()).take(limit).toList(),
      'has_more': invoices.length > limit,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Apply remote changes
  Future<void> applyRemoteChanges(List<Map<String, dynamic>> changes) async {
    for (final change in changes) {
      // This would deserialize and merge remote changes
      // Implementation depends on the specific CRDT serialization format

      final invoiceId = change['id'] as String;
      final existing = await getInvoiceById(invoiceId);

      if (existing != null) {
        // Merge changes - this would need proper deserialization
        // For now, skip implementation details
      }
    }
  }

  /// Performance and Caching

  /// Get frequently accessed invoices for caching
  Future<List<CRDTInvoiceEnhanced>> getFrequentlyAccessedInvoices({
    int limit = 100,
  }) async {
    // This would typically track access patterns
    // For now, return recent invoices
    return queryInvoices(
      InvoiceQueryBuilder()
          .orderBy('updated_at', ascending: false)
          .limit(limit)
          .build(),
    );
  }

  /// Preload related data for performance
  Future<Map<String, dynamic>> getInvoiceWithRelatedData(
      String invoiceId) async {
    final invoice = await getInvoiceById(invoiceId);
    if (invoice == null) {
      throw Exception('Invoice not found');
    }

    final items = await getInvoiceLineItems(invoiceId);
    final payments = await getInvoicePayments(invoiceId);
    final workflow = await getInvoiceWorkflow(invoiceId);

    return {
      'invoice': invoice.toJson(),
      'items': items.map((i) => i.toJson()).toList(),
      'payments': payments.map((p) => p.toJson()).toList(),
      'workflow': workflow.map((w) => w.toJson()).toList(),
    };
  }
}
