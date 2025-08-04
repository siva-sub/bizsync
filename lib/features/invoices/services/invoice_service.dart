import 'dart:async';
import 'dart:convert';
import '../../../core/crdt/hybrid_logical_clock.dart';
import '../../../core/crdt/vector_clock.dart';
import '../../../core/database/transaction_manager.dart';
import '../../../core/database/crdt_database_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../models/invoice_models.dart';
import '../models/enhanced_invoice_model.dart';
import 'invoice_workflow_service.dart';
import 'invoice_calculation_service.dart';

/// Invoice operation result
class InvoiceOperationResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final Map<String, dynamic>? context;

  const InvoiceOperationResult({
    required this.success,
    this.data,
    this.errorMessage,
    this.context,
  });

  factory InvoiceOperationResult.success(T data,
      {Map<String, dynamic>? context}) {
    return InvoiceOperationResult(
      success: true,
      data: data,
      context: context,
    );
  }

  factory InvoiceOperationResult.failure(String errorMessage,
      {Map<String, dynamic>? context}) {
    return InvoiceOperationResult(
      success: false,
      errorMessage: errorMessage,
      context: context,
    );
  }
}

/// Invoice search filters
class InvoiceSearchFilters {
  final List<InvoiceStatus>? statuses;
  final String? customerId;
  final DateTime? issueDateFrom;
  final DateTime? issueDateTo;
  final DateTime? dueDateFrom;
  final DateTime? dueDateTo;
  final double? amountFrom;
  final double? amountTo;
  final bool? isOverdue;
  final bool? isDisputed;
  final List<String>? tags;
  final String? searchText;
  final int? limit;
  final int? offset;
  final String? sortBy;
  final bool? sortAscending;

  const InvoiceSearchFilters({
    this.statuses,
    this.customerId,
    this.issueDateFrom,
    this.issueDateTo,
    this.dueDateFrom,
    this.dueDateTo,
    this.amountFrom,
    this.amountTo,
    this.isOverdue,
    this.isDisputed,
    this.tags,
    this.searchText,
    this.limit,
    this.offset,
    this.sortBy,
    this.sortAscending,
  });

  Map<String, dynamic> toJson() {
    return {
      'statuses': statuses?.map((s) => s.value).toList(),
      'customer_id': customerId,
      'issue_date_from': issueDateFrom?.millisecondsSinceEpoch,
      'issue_date_to': issueDateTo?.millisecondsSinceEpoch,
      'due_date_from': dueDateFrom?.millisecondsSinceEpoch,
      'due_date_to': dueDateTo?.millisecondsSinceEpoch,
      'amount_from': amountFrom,
      'amount_to': amountTo,
      'is_overdue': isOverdue,
      'is_disputed': isDisputed,
      'tags': tags,
      'search_text': searchText,
      'limit': limit,
      'offset': offset,
      'sort_by': sortBy,
      'sort_ascending': sortAscending,
    };
  }
}

/// Invoice batch operation
class InvoiceBatchOperation {
  final String operation; // 'update_status', 'send', 'cancel', 'delete'
  final List<String> invoiceIds;
  final Map<String, dynamic>? parameters;

  const InvoiceBatchOperation({
    required this.operation,
    required this.invoiceIds,
    this.parameters,
  });
}

/// Main invoice service with comprehensive ACID transaction support
class InvoiceService {
  final CRDTDatabaseService _databaseService;
  final TransactionManager _transactionManager;
  final InvoiceWorkflowService _workflowService;
  final InvoiceCalculationService _calculationService;
  final String _nodeId;

  InvoiceService(
    this._databaseService,
    this._transactionManager,
    this._workflowService,
    this._calculationService,
    this._nodeId,
  );

  /// Create a new invoice with transaction support
  Future<InvoiceOperationResult<CRDTInvoiceEnhanced>> createInvoice({
    required String customerId,
    String? customerName,
    String? customerEmail,
    String? billingAddress,
    String? shippingAddress,
    required DateTime issueDate,
    DateTime? dueDate,
    PaymentTerm paymentTerms = PaymentTerm.net30,
    String? poNumber,
    String? reference,
    String? notes,
    String? termsAndConditions,
    List<Map<String, dynamic>>? lineItems,
    Map<String, dynamic>? customFields,
    String currency = 'SGD',
    double exchangeRate = 1.0,
  }) async {
    // Validate required parameters
    if (customerId.isEmpty) {
      return InvoiceOperationResult.failure('Customer ID cannot be empty');
    }
    if (currency.isEmpty) {
      return InvoiceOperationResult.failure('Currency cannot be empty');
    }
    if (exchangeRate <= 0) {
      return InvoiceOperationResult.failure('Exchange rate must be positive');
    }
    
    return await _transactionManager.runInTransaction((transaction) async {
      try {
        final invoiceId = UuidGenerator.generateId();
        final timestamp = HLCTimestamp.now(_nodeId);

        // Generate invoice number
        final invoiceNumber = await _generateInvoiceNumber();

        // Create the invoice with null-safe parameters
        final invoice = CRDTInvoiceEnhanced(
          id: invoiceId,
          nodeId: _nodeId,
          createdAt: timestamp,
          updatedAt: timestamp,
          version: VectorClock(_nodeId),
          invoiceNum: invoiceNumber,
          customer: customerId.isNotEmpty ? customerId : null,
          customerNameValue: customerName?.isNotEmpty == true ? customerName : null,
          customerEmailValue: customerEmail?.isNotEmpty == true ? customerEmail : null,
          billingAddr: billingAddress?.isNotEmpty == true ? billingAddress : null,
          shippingAddr: shippingAddress?.isNotEmpty == true ? shippingAddress : null,
          issue: issueDate,
          due: dueDate,
          payment: paymentTerms,
          po: poNumber?.isNotEmpty == true ? poNumber : null,
          ref: reference?.isNotEmpty == true ? reference : null,
          invoiceNotes: notes?.isNotEmpty == true ? notes : null,
          terms: termsAndConditions?.isNotEmpty == true ? termsAndConditions : null,
          custom: customFields,
          curr: currency,
          exchange: exchangeRate,
        );

        // Add line items if provided
        if (lineItems != null && lineItems.isNotEmpty) {
          for (int i = 0; i < lineItems.length; i++) {
            final itemData = lineItems[i];
            final itemResult = await _addLineItem(
              invoice,
              itemData,
              sortOrder: i,
              skipCalculation: true,
            );

            if (!itemResult.success) {
              throw Exception(
                  'Failed to add line item: ${itemResult.errorMessage}');
            }
          }

          // Recalculate totals after adding all items
          await _recalculateInvoiceTotals(invoice);
        }

        // Save to database
        await _databaseService.upsertEntity('invoices', invoice);

        // Create initial workflow entry
        await _createWorkflowEntry(
          invoice.id,
          InvoiceStatus.draft,
          InvoiceStatus.draft,
          'Invoice created',
          'system',
          {'created': true},
        );

        return InvoiceOperationResult.success(
          invoice,
          context: {'invoice_number': invoiceNumber},
        );
      } catch (e) {
        throw Exception('Failed to create invoice: $e');
      }
    });
  }

  /// Update an existing invoice
  Future<InvoiceOperationResult<CRDTInvoiceEnhanced>> updateInvoice(
    String invoiceId,
    Map<String, dynamic> updates,
  ) async {
    return await _transactionManager.runInTransaction((transaction) async {
      try {
        final invoice = await getInvoiceById(invoiceId);
        if (invoice.data == null) {
          return InvoiceOperationResult.failure('Invoice not found');
        }

        final invoiceData = invoice.data!;
        final timestamp = HLCTimestamp.now(_nodeId);
        bool needsRecalculation = false;

        // Apply updates with null safety
        if (updates.containsKey('customer_id')) {
          final customerId = updates['customer_id'] as String?;
          if (customerId != null && customerId.isNotEmpty) {
            invoiceData.customerId.setValue(customerId, timestamp);
          }
        }
        if (updates.containsKey('customer_name')) {
          final customerName = updates['customer_name'] as String?;
          invoiceData.customerName.setValue(
            customerName?.isNotEmpty == true ? customerName : null, 
            timestamp
          );
        }
        if (updates.containsKey('customer_email')) {
          final customerEmail = updates['customer_email'] as String?;
          invoiceData.customerEmail.setValue(
            customerEmail?.isNotEmpty == true ? customerEmail : null, 
            timestamp
          );
        }
        if (updates.containsKey('billing_address')) {
          final billingAddress = updates['billing_address'] as String?;
          invoiceData.billingAddress.setValue(
            billingAddress?.isNotEmpty == true ? billingAddress : null, 
            timestamp
          );
        }
        if (updates.containsKey('shipping_address')) {
          final shippingAddress = updates['shipping_address'] as String?;
          invoiceData.shippingAddress.setValue(
            shippingAddress?.isNotEmpty == true ? shippingAddress : null, 
            timestamp
          );
        }
        if (updates.containsKey('issue_date')) {
          invoiceData.issueDate.setValue(
            DateTime.fromMillisecondsSinceEpoch(updates['issue_date']),
            timestamp,
          );
        }
        if (updates.containsKey('due_date')) {
          final dueDate = updates['due_date'] != null
              ? DateTime.fromMillisecondsSinceEpoch(updates['due_date'])
              : null;
          invoiceData.dueDate.setValue(dueDate, timestamp);
        }
        if (updates.containsKey('payment_terms')) {
          invoiceData.paymentTerms.setValue(
            PaymentTerm.fromString(updates['payment_terms']),
            timestamp,
          );
        }
        if (updates.containsKey('po_number')) {
          final poNumber = updates['po_number'] as String?;
          invoiceData.poNumber.setValue(
            poNumber?.isNotEmpty == true ? poNumber : null, 
            timestamp
          );
        }
        if (updates.containsKey('reference')) {
          final reference = updates['reference'] as String?;
          invoiceData.reference.setValue(
            reference?.isNotEmpty == true ? reference : null, 
            timestamp
          );
        }
        if (updates.containsKey('notes')) {
          final notes = updates['notes'] as String?;
          invoiceData.notes.setValue(
            notes?.isNotEmpty == true ? notes : null, 
            timestamp
          );
        }
        if (updates.containsKey('terms_and_conditions')) {
          final termsAndConditions = updates['terms_and_conditions'] as String?;
          invoiceData.termsAndConditions.setValue(
            termsAndConditions?.isNotEmpty == true ? termsAndConditions : null, 
            timestamp
          );
        }
        if (updates.containsKey('footer_text')) {
          final footerText = updates['footer_text'] as String?;
          invoiceData.footerText.setValue(
            footerText?.isNotEmpty == true ? footerText : null, 
            timestamp
          );
        }
        if (updates.containsKey('custom_fields')) {
          invoiceData.customFields
              .setValue(updates['custom_fields'], timestamp);
        }
        if (updates.containsKey('currency')) {
          invoiceData.currency.setValue(updates['currency'], timestamp);
          needsRecalculation = true;
        }
        if (updates.containsKey('exchange_rate')) {
          invoiceData.exchangeRate
              .setValue(updates['exchange_rate'], timestamp);
          needsRecalculation = true;
        }

        // Handle financial updates
        if (updates.containsKey('subtotal') ||
            updates.containsKey('tax_amount') ||
            updates.containsKey('discount_amount') ||
            updates.containsKey('shipping_amount') ||
            updates.containsKey('total_amount')) {
          invoiceData.updateTotals(
            newSubtotal: updates['subtotal'],
            newTaxAmount: updates['tax_amount'],
            newDiscountAmount: updates['discount_amount'],
            newShippingAmount: updates['shipping_amount'],
            newTotalAmount: updates['total_amount'],
            timestamp: timestamp,
          );
        } else if (needsRecalculation) {
          await _recalculateInvoiceTotals(invoiceData);
        }

        // Update timestamp
        invoiceData.updatedAt = timestamp;
        invoiceData.version = invoiceData.version.tick();

        // Save to database
        await _databaseService.upsertEntity('invoices', invoiceData);

        return InvoiceOperationResult.success(invoiceData);
      } catch (e) {
        throw Exception('Failed to update invoice: $e');
      }
    });
  }

  /// Add line item to invoice
  Future<InvoiceOperationResult<CRDTInvoiceItem>> addLineItem(
    String invoiceId,
    Map<String, dynamic> itemData,
  ) async {
    return await _transactionManager.runInTransaction((transaction) async {
      try {
        final invoiceResult = await getInvoiceById(invoiceId);
        if (invoiceResult.data == null) {
          return InvoiceOperationResult.failure('Invoice not found');
        }

        final invoice = invoiceResult.data!;
        final result = await _addLineItem(invoice, itemData);

        if (result.success && result.data != null) {
          // Recalculate invoice totals
          await _recalculateInvoiceTotals(invoice);
          await _databaseService.upsertEntity('invoices', invoice);
        }

        return result;
      } catch (e) {
        throw Exception('Failed to add line item: $e');
      }
    });
  }

  /// Update line item
  Future<InvoiceOperationResult<CRDTInvoiceItem>> updateLineItem(
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    return await _transactionManager.runInTransaction((transaction) async {
      try {
        final item = await _getLineItemById(itemId);
        if (item == null) {
          return InvoiceOperationResult.failure('Line item not found');
        }

        final timestamp = HLCTimestamp.now(_nodeId);

        // Apply updates
        item.updateItem(
          newDescription: updates['description'],
          newQuantity: updates['quantity']?.toDouble(),
          newUnitPrice: updates['unit_price']?.toDouble(),
          newDiscount: updates['discount']?.toDouble(),
          newTaxRate: updates['tax_rate']?.toDouble(),
          newTaxMethod: updates['tax_method'] != null
              ? TaxCalculationMethod.fromString(updates['tax_method'])
              : null,
          timestamp: timestamp,
        );

        // Save line item
        await _databaseService.upsertEntity('invoice_items', item);

        // Recalculate invoice totals
        final invoiceResult = await getInvoiceById(item.invoiceId.value);
        if (invoiceResult.data != null) {
          await _recalculateInvoiceTotals(invoiceResult.data!);
          await _databaseService.upsertEntity('invoices', invoiceResult.data!);
        }

        return InvoiceOperationResult.success(item);
      } catch (e) {
        throw Exception('Failed to update line item: $e');
      }
    });
  }

  /// Remove line item from invoice
  Future<InvoiceOperationResult<bool>> removeLineItem(String itemId) async {
    return await _transactionManager.runInTransaction((transaction) async {
      try {
        final item = await _getLineItemById(itemId);
        if (item == null) {
          return InvoiceOperationResult.failure('Line item not found');
        }

        final invoiceId = item.invoiceId.value;

        // Mark item as deleted
        final timestamp = HLCTimestamp.now(_nodeId);
        item.isDeleted = true;
        item.updatedAt = timestamp;
        item.version = item.version.tick();

        await _databaseService.upsertEntity('invoice_items', item);

        // Remove from invoice
        final invoiceResult = await getInvoiceById(invoiceId);
        if (invoiceResult.data != null) {
          invoiceResult.data!.removeItem(itemId);
          await _recalculateInvoiceTotals(invoiceResult.data!);
          await _databaseService.upsertEntity('invoices', invoiceResult.data!);
        }

        return InvoiceOperationResult.success(true);
      } catch (e) {
        throw Exception('Failed to remove line item: $e');
      }
    });
  }

  /// Record payment for invoice
  Future<InvoiceOperationResult<CRDTInvoicePayment>> recordPayment({
    required String invoiceId,
    required double amount,
    required String paymentMethod,
    required DateTime paymentDate,
    String? paymentReference,
    String? transactionId,
    String? notes,
    Map<String, dynamic>? paymentDetails,
  }) async {
    return await _transactionManager.runInTransaction((transaction) async {
      try {
        final invoiceResult = await getInvoiceById(invoiceId);
        if (invoiceResult.data == null) {
          return InvoiceOperationResult.failure('Invoice not found');
        }

        final invoice = invoiceResult.data!;
        final timestamp = HLCTimestamp.now(_nodeId);

        // Create payment record
        final paymentId = UuidGenerator.generateId();
        final payment = CRDTInvoicePayment(
          id: paymentId,
          nodeId: _nodeId,
          createdAt: timestamp,
          updatedAt: timestamp,
          version: VectorClock(_nodeId),
          paymentInvoiceId: invoiceId,
          paymentPaymentReference: paymentReference ?? paymentId,
          paymentAmount: amount,
          paymentPaymentDate: paymentDate,
          paymentPaymentMethod: paymentMethod,
          paymentStatus: 'completed',
          paymentTransactionId: transactionId,
          paymentNotes: notes,
          paymentPaymentDetails: paymentDetails,
        );

        // Record payment on invoice
        invoice.recordPayment(amount, timestamp);
        invoice.addPayment(paymentId);

        // Save both payment and invoice
        await _databaseService.upsertEntity('invoice_payments', payment);
        await _databaseService.upsertEntity('invoices', invoice);

        // Create workflow entry
        await _createWorkflowEntry(
          invoiceId,
          invoice.status.value,
          invoice.status.value, // Status might have changed in recordPayment
          'Payment recorded: ${amount.toStringAsFixed(2)} ${invoice.currency.value}',
          'system',
          {
            'payment_id': paymentId,
            'amount': amount,
            'payment_method': paymentMethod,
          },
        );

        return InvoiceOperationResult.success(payment);
      } catch (e) {
        throw Exception('Failed to record payment: $e');
      }
    });
  }

  /// Change invoice status
  Future<InvoiceOperationResult<CRDTInvoiceEnhanced>> changeStatus(
    String invoiceId,
    InvoiceStatus newStatus, {
    String? reason,
    String? triggeredBy,
    Map<String, dynamic>? context,
  }) async {
    return await _transactionManager.runInTransaction((transaction) async {
      try {
        final invoiceResult = await getInvoiceById(invoiceId);
        if (invoiceResult.data == null) {
          return InvoiceOperationResult.failure('Invoice not found');
        }

        final invoice = invoiceResult.data!;

        // Use workflow service to handle status transition
        final transitionResult = await _workflowService.transitionStatus(
          invoice,
          newStatus,
          reason: reason,
          triggeredBy: triggeredBy,
          context: context,
        );

        if (!transitionResult.success) {
          return InvoiceOperationResult.failure(transitionResult.errorMessage!);
        }

        // Save updated invoice
        await _databaseService.upsertEntity('invoices', invoice);

        // Create workflow entry
        await _createWorkflowEntry(
          invoiceId,
          transitionResult.fromStatus!,
          transitionResult.toStatus!,
          reason ?? 'Status changed',
          triggeredBy ?? 'user',
          context,
        );

        return InvoiceOperationResult.success(invoice);
      } catch (e) {
        throw Exception('Failed to change status: $e');
      }
    });
  }

  /// Get invoice by ID
  Future<InvoiceOperationResult<CRDTInvoiceEnhanced>> getInvoiceById(
      String invoiceId) async {
    try {
      final entity = await _databaseService.getEntity('invoices', invoiceId);
      if (entity == null) {
        return InvoiceOperationResult.failure('Invoice not found');
      }

      // Convert entity to CRDTInvoiceEnhanced
      // This would require implementing fromCRDTJson method
      // For now, assume we have the invoice
      final invoice = entity as CRDTInvoiceEnhanced;

      return InvoiceOperationResult.success(invoice);
    } catch (e) {
      return InvoiceOperationResult.failure('Failed to get invoice: $e');
    }
  }

  /// Search invoices with filters
  Future<InvoiceOperationResult<List<CRDTInvoiceEnhanced>>> searchInvoices(
    InvoiceSearchFilters filters,
  ) async {
    try {
      // This would implement complex query logic based on filters
      // For now, return empty list
      final invoices = <CRDTInvoiceEnhanced>[];

      return InvoiceOperationResult.success(invoices);
    } catch (e) {
      return InvoiceOperationResult.failure('Failed to search invoices: $e');
    }
  }

  /// Get invoice line items
  Future<InvoiceOperationResult<List<CRDTInvoiceItem>>> getInvoiceItems(
      String invoiceId) async {
    try {
      // Query line items for invoice
      final items = <CRDTInvoiceItem>[];

      return InvoiceOperationResult.success(items);
    } catch (e) {
      return InvoiceOperationResult.failure('Failed to get invoice items: $e');
    }
  }

  /// Get invoice payments
  Future<InvoiceOperationResult<List<CRDTInvoicePayment>>> getInvoicePayments(
      String invoiceId) async {
    try {
      // Query payments for invoice
      final payments = <CRDTInvoicePayment>[];

      return InvoiceOperationResult.success(payments);
    } catch (e) {
      return InvoiceOperationResult.failure(
          'Failed to get invoice payments: $e');
    }
  }

  /// Get invoice workflow history
  Future<InvoiceOperationResult<List<CRDTInvoiceWorkflow>>> getInvoiceWorkflow(
      String invoiceId) async {
    try {
      // Query workflow entries for invoice
      final workflow = <CRDTInvoiceWorkflow>[];

      return InvoiceOperationResult.success(workflow);
    } catch (e) {
      return InvoiceOperationResult.failure(
          'Failed to get invoice workflow: $e');
    }
  }

  /// Perform batch operations on invoices
  Future<InvoiceOperationResult<Map<String, dynamic>>> performBatchOperation(
    InvoiceBatchOperation operation,
  ) async {
    return await _transactionManager.runInTransaction((transaction) async {
      try {
        final results = <String, dynamic>{};
        final successes = <String>[];
        final failures = <String, String>{};

        for (final invoiceId in operation.invoiceIds) {
          try {
            switch (operation.operation) {
              case 'update_status':
                final status =
                    InvoiceStatus.fromString(operation.parameters!['status']);
                final result = await changeStatus(
                  invoiceId,
                  status,
                  reason: operation.parameters?['reason'],
                  triggeredBy: 'batch_operation',
                );

                if (result.success) {
                  successes.add(invoiceId);
                } else {
                  failures[invoiceId] = result.errorMessage!;
                }
                break;

              case 'send':
                final result = await changeStatus(
                  invoiceId,
                  InvoiceStatus.sent,
                  reason: 'Batch send operation',
                  triggeredBy: 'batch_operation',
                );

                if (result.success) {
                  successes.add(invoiceId);
                } else {
                  failures[invoiceId] = result.errorMessage!;
                }
                break;

              case 'cancel':
                final result = await changeStatus(
                  invoiceId,
                  InvoiceStatus.cancelled,
                  reason: 'Batch cancel operation',
                  triggeredBy: 'batch_operation',
                );

                if (result.success) {
                  successes.add(invoiceId);
                } else {
                  failures[invoiceId] = result.errorMessage!;
                }
                break;

              case 'delete':
                final result = await deleteInvoice(invoiceId);

                if (result.success) {
                  successes.add(invoiceId);
                } else {
                  failures[invoiceId] = result.errorMessage!;
                }
                break;

              default:
                failures[invoiceId] =
                    'Unknown operation: ${operation.operation}';
            }
          } catch (e) {
            failures[invoiceId] = 'Error: $e';
          }
        }

        results['successes'] = successes;
        results['failures'] = failures;
        results['total_processed'] = operation.invoiceIds.length;
        results['success_count'] = successes.length;
        results['failure_count'] = failures.length;

        return InvoiceOperationResult.success(results);
      } catch (e) {
        throw Exception('Failed to perform batch operation: $e');
      }
    });
  }

  /// Delete invoice (soft delete)
  Future<InvoiceOperationResult<bool>> deleteInvoice(String invoiceId) async {
    return await _transactionManager.runInTransaction((transaction) async {
      try {
        final invoiceResult = await getInvoiceById(invoiceId);
        if (invoiceResult.data == null) {
          return InvoiceOperationResult.failure('Invoice not found');
        }

        final invoice = invoiceResult.data!;
        final timestamp = HLCTimestamp.now(_nodeId);

        // Mark as deleted
        invoice.isDeleted = true;
        invoice.updatedAt = timestamp;
        invoice.version = invoice.version.tick();

        // Save to database
        await _databaseService.upsertEntity('invoices', invoice);

        // Create workflow entry
        await _createWorkflowEntry(
          invoiceId,
          invoice.status.value,
          invoice.status.value,
          'Invoice deleted',
          'user',
          {'soft_delete': true},
        );

        return InvoiceOperationResult.success(true);
      } catch (e) {
        throw Exception('Failed to delete invoice: $e');
      }
    });
  }

  /// Process automated workflows for all invoices
  Future<InvoiceOperationResult<Map<String, dynamic>>>
      processAutomatedWorkflows() async {
    try {
      // Get all active invoices
      final invoicesResult = await searchInvoices(const InvoiceSearchFilters());
      if (!invoicesResult.success) {
        return InvoiceOperationResult.failure(
            'Failed to get invoices for automation');
      }

      final results = await _workflowService
          .processAutomatedTransitions(invoicesResult.data!);

      final processedCount = results.length;
      final successCount = results.where((r) => r.success).length;

      return InvoiceOperationResult.success({
        'processed_count': processedCount,
        'success_count': successCount,
        'results': results.map((r) => r.toJson()).toList(),
      });
    } catch (e) {
      return InvoiceOperationResult.failure(
          'Failed to process automated workflows: $e');
    }
  }

  /// Internal helper methods

  Future<String> _generateInvoiceNumber() async {
    // This would implement invoice number generation logic
    // For now, use timestamp-based approach
    final now = DateTime.now();
    return 'INV-${now.year}${now.month.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch}';
  }

  Future<InvoiceOperationResult<CRDTInvoiceItem>> _addLineItem(
    CRDTInvoiceEnhanced invoice,
    Map<String, dynamic> itemData, {
    int sortOrder = 0,
    bool skipCalculation = false,
  }) async {
    // Validate required fields
    final description = itemData['description']?.toString().trim() ?? '';
    if (description.isEmpty) {
      return InvoiceOperationResult.failure('Line item description cannot be empty');
    }
    
    final quantity = (itemData['quantity'] as num?)?.toDouble() ?? 1.0;
    if (quantity <= 0) {
      return InvoiceOperationResult.failure('Line item quantity must be positive');
    }
    
    final unitPrice = (itemData['unit_price'] as num?)?.toDouble() ?? 0.0;
    if (unitPrice < 0) {
      return InvoiceOperationResult.failure('Line item unit price cannot be negative');
    }
    
    final itemId = UuidGenerator.generateId();
    final timestamp = HLCTimestamp.now(_nodeId);

    final item = CRDTInvoiceItem(
      id: itemId,
      nodeId: _nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(_nodeId),
      invoiceItemInvoiceId: invoice.id,
      invoiceItemProductId: itemData['product_id']?.toString(),
      invoiceItemDescription: description,
      invoiceItemType: itemData['item_type'] != null
          ? LineItemType.fromString(itemData['item_type'].toString())
          : LineItemType.product,
      invoiceItemQuantity: quantity,
      invoiceItemUnitPrice: unitPrice,
      invoiceItemDiscount: (itemData['discount'] as num?)?.toDouble() ?? 0.0,
      invoiceItemTaxRate: (itemData['tax_rate'] as num?)?.toDouble() ?? 0.0,
      invoiceItemTaxMethod: itemData['tax_method'] != null
          ? TaxCalculationMethod.fromString(itemData['tax_method'].toString())
          : TaxCalculationMethod.exclusive,
      invoiceItemSortOrder: sortOrder,
      invoiceItemMetadata: itemData['metadata'] as Map<String, dynamic>?,
    );

    // Calculate line total
    final lineTotal = item.calculateLineTotal();
    item.lineTotal.setValue(lineTotal, timestamp);

    // Add to invoice
    invoice.addItem(itemId);

    // Save line item
    await _databaseService.upsertEntity('invoice_items', item);

    return InvoiceOperationResult.success(item);
  }

  Future<void> _recalculateInvoiceTotals(CRDTInvoiceEnhanced invoice) async {
    final calculation =
        await _calculationService.calculateInvoiceTotals(invoice.id);

    if (calculation.success && calculation.data != null) {
      final totals = calculation.data!;
      final timestamp = HLCTimestamp.now(_nodeId);

      invoice.updateTotals(
        newSubtotal: totals['subtotal'],
        newTaxAmount: totals['tax_amount'],
        newDiscountAmount: totals['discount_amount'],
        newShippingAmount: totals['shipping_amount'],
        newTotalAmount: totals['total_amount'],
        timestamp: timestamp,
      );
    }
  }

  Future<CRDTInvoiceItem?> _getLineItemById(String itemId) async {
    final entity = await _databaseService.getEntity('invoice_items', itemId);
    return entity as CRDTInvoiceItem?;
  }

  Future<void> _createWorkflowEntry(
    String invoiceId,
    InvoiceStatus fromStatus,
    InvoiceStatus toStatus,
    String reason,
    String triggeredBy,
    Map<String, dynamic>? context,
  ) async {
    final workflowId = UuidGenerator.generateId();
    final timestamp = HLCTimestamp.now(_nodeId);

    final workflow = CRDTInvoiceWorkflow(
      id: workflowId,
      nodeId: _nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: VectorClock(_nodeId),
      workflowInvoiceId: invoiceId,
      workflowFromStatus: fromStatus,
      workflowToStatus: toStatus,
      workflowTriggeredBy: triggeredBy,
      workflowReason: reason,
      workflowTimestamp: DateTime.now(),
      workflowContext: context,
    );

    await _databaseService.upsertEntity('invoice_workflow', workflow);
  }
}

/// Extension methods for WorkflowTransitionResult
extension WorkflowTransitionResultExtension on WorkflowTransitionResult {
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'error_message': errorMessage,
      'from_status': fromStatus?.value,
      'to_status': toStatus?.value,
      'context': context,
    };
  }
}
