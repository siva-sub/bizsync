import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/customer_statement_models.dart';
import '../../invoices/models/enhanced_invoice.dart';
import '../../../core/database/crdt_database_service.dart';
import '../../../core/services/notification_service.dart';

/// Service for generating and managing customer statements
class CustomerStatementService {
  static CustomerStatementService? _instance;
  static CustomerStatementService get instance => _instance ??= CustomerStatementService._();
  
  CustomerStatementService._();

  final CRDTDatabaseService _databaseService = CRDTDatabaseService();
  final NotificationService _notificationService = NotificationService();
  final Uuid _uuid = const Uuid();

  static const String _paymentsTable = 'customer_payments';
  static const String _statementLogTable = 'statement_generation_log';

  /// Initialize the service and database tables
  Future<void> initialize() async {
    await _createTables();
  }

  /// Create database tables for customer statements
  Future<void> _createTables() async {
    const createPaymentsTable = '''
      CREATE TABLE IF NOT EXISTS $_paymentsTable (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        invoice_id TEXT NOT NULL,
        invoice_number TEXT,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        method TEXT NOT NULL,
        reference TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''';

    const createStatementLogTable = '''
      CREATE TABLE IF NOT EXISTS $_statementLogTable (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        statement_date TEXT NOT NULL,
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        generated_by TEXT NOT NULL,
        generated_at TEXT NOT NULL,
        file_path TEXT,
        email_sent INTEGER DEFAULT 0
      )
    ''';

    final db = await _databaseService.database;
    await db.execute(createPaymentsTable);
    await db.execute(createStatementLogTable);
  }

  /// Record a customer payment
  Future<CustomerPayment> recordPayment({
    required String customerId,
    required String invoiceId,
    required double amount,
    required DateTime paymentDate,
    required PaymentMethod method,
    String? invoiceNumber,
    String? reference,
    String? notes,
  }) async {
    final payment = CustomerPayment(
      id: _uuid.v4(),
      customerId: customerId,
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      amount: amount,
      paymentDate: paymentDate,
      method: method,
      reference: reference,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await _savePayment(payment);

    // Send notification
    await _notificationService.sendNotification(
      title: 'Payment Recorded',
      message: 'Payment of \$${amount.toStringAsFixed(2)} recorded for ${invoiceNumber ?? invoiceId}',
      data: {
        'type': 'payment_recorded',
        'payment_id': payment.id,
        'customer_id': customerId,
        'amount': amount.toString(),
      },
    );

    return payment;
  }

  /// Save payment to database
  Future<void> _savePayment(CustomerPayment payment) async {
    const sql = '''
      INSERT OR REPLACE INTO $_paymentsTable (
        id, customer_id, invoice_id, invoice_number, amount,
        payment_date, method, reference, notes, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''';

    final db = await _databaseService.database;
    await db.execute(sql, [
      payment.id,
      payment.customerId,
      payment.invoiceId,
      payment.invoiceNumber,
      payment.amount,
      payment.paymentDate.toIso8601String(),
      payment.method.name,
      payment.reference,
      payment.notes,
      payment.createdAt.toIso8601String(),
    ]);
  }

  /// Get customer payments
  Future<List<CustomerPayment>> getCustomerPayments({
    required String customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String sql = 'SELECT * FROM $_paymentsTable WHERE customer_id = ?';
    final params = <dynamic>[customerId];

    if (startDate != null) {
      sql += ' AND payment_date >= ?';
      params.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      sql += ' AND payment_date <= ?';
      params.add(endDate.toIso8601String());
    }

    sql += ' ORDER BY payment_date DESC';

    final db = await _databaseService.database;
    final results = await db.rawQuery(sql, params);
    return results.map((row) => _paymentFromRow(row)).toList();
  }

  /// Generate customer statement
  Future<CustomerStatement> generateCustomerStatement({
    required String customerId,
    required String customerName,
    StatementGenerationOptions? options,
  }) async {
    options ??= StatementGenerationOptions.currentMonth();

    // Get customer invoices for the period
    final invoices = await _getCustomerInvoices(
      customerId: customerId,
      startDate: options.startDate,
      endDate: options.endDate,
    );

    // Get customer payments for the period
    final payments = await getCustomerPayments(
      customerId: customerId,
      startDate: options.startDate,
      endDate: options.endDate,
    );

    // Calculate opening balance (invoices before period minus payments before period)
    final openingBalance = await _calculateOpeningBalance(
      customerId: customerId,
      asOfDate: options.startDate,
    );

    // Generate summary
    final summary = _generateStatementSummary(
      customerId: customerId,
      customerName: customerName,
      options: options,
      invoices: invoices,
      payments: payments,
      openingBalance: openingBalance,
    );

    // Generate transactions
    final transactions = _generateStatementTransactions(
      invoices: invoices,
      payments: payments,
      openingBalance: openingBalance,
    );

    final statement = CustomerStatement(
      summary: summary,
      transactions: transactions,
      generatedAt: DateTime.now(),
      generatedBy: 'System', // TODO: Get current user
    );

    // Log statement generation
    await _logStatementGeneration(statement);

    return statement;
  }

  /// Get customer invoices for a period
  Future<List<EnhancedInvoice>> _getCustomerInvoices({
    required String customerId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // This would query the invoices table - using placeholder data for demo
    // In real implementation, this would query the actual invoices table
    return [
      // Placeholder invoices - replace with actual database query
      EnhancedInvoice(
        id: 'inv-1',
        invoiceNumber: 'INV-2024-001',
        customerId: customerId,
        customerName: 'Demo Customer',
        issueDate: startDate.add(const Duration(days: 5)),
        dueDate: startDate.add(const Duration(days: 35)),
        status: InvoiceStatus.sent,
        lineItems: const [],
        subtotal: 1000.0,
        taxAmount: 70.0,
        totalAmount: 1070.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  /// Calculate opening balance for a customer
  Future<double> _calculateOpeningBalance({
    required String customerId,
    required DateTime asOfDate,
  }) async {
    try {
      // Get total invoiced before the period
      const invoicesSql = '''
        SELECT COALESCE(SUM(total_amount), 0) as total_invoiced 
        FROM invoices 
        WHERE customer_id = ? AND issue_date < ?
      ''';
      
      final db = await _databaseService.database;
      final invoicesResult = await db.rawQuery(invoicesSql, [
        customerId,
        asOfDate.toIso8601String(),
      ]);
      
      final totalInvoiced = (invoicesResult.first['total_invoiced'] as num?)?.toDouble() ?? 0.0;

      // Get total paid before the period
      const paymentsSql = '''
        SELECT COALESCE(SUM(amount), 0) as total_paid 
        FROM $_paymentsTable 
        WHERE customer_id = ? AND payment_date < ?
      ''';
      
      final paymentsResult = await db.rawQuery(paymentsSql, [
        customerId,
        asOfDate.toIso8601String(),
      ]);
      
      final totalPaid = (paymentsResult.first['total_paid'] as num?)?.toDouble() ?? 0.0;

      return totalInvoiced - totalPaid;
    } catch (e) {
      // If tables don't exist or query fails, return 0
      return 0.0;
    }
  }

  /// Generate statement summary
  CustomerStatementSummary _generateStatementSummary({
    required String customerId,
    required String customerName,
    required StatementGenerationOptions options,
    required List<EnhancedInvoice> invoices,
    required List<CustomerPayment> payments,
    required double openingBalance,
  }) {
    final totalInvoiced = invoices.fold(0.0, (sum, inv) => sum + inv.totalAmount);
    final totalPaid = payments.fold(0.0, (sum, pay) => sum + pay.amount);
    final closingBalance = openingBalance + totalInvoiced - totalPaid;

    // Calculate aging
    final now = DateTime.now();
    double overdue30 = 0.0;
    double overdue60 = 0.0;
    double overdue90 = 0.0;

    for (final invoice in invoices) {
      if (invoice.status != InvoiceStatus.paid) {
        final daysPastDue = now.difference(invoice.dueDate).inDays;
        
        if (daysPastDue > 90) {
          overdue90 += invoice.totalAmount;
        } else if (daysPastDue > 60) {
          overdue60 += invoice.totalAmount;
        } else if (daysPastDue > 30) {
          overdue30 += invoice.totalAmount;
        }
      }
    }

    final paidInvoices = invoices.where((inv) => inv.status == InvoiceStatus.paid).length;
    final unpaidInvoices = invoices.length - paidInvoices;

    return CustomerStatementSummary(
      customerId: customerId,
      customerName: customerName,
      statementDate: DateTime.now(),
      periodStart: options.startDate,
      periodEnd: options.endDate,
      openingBalance: openingBalance,
      totalInvoiced: totalInvoiced,
      totalPaid: totalPaid,
      closingBalance: closingBalance,
      currentBalance: closingBalance, // Assuming current balance equals closing balance
      overdue30Days: overdue30,
      overdue60Days: overdue60,
      overdue90Days: overdue90,
      totalInvoices: invoices.length,
      paidInvoices: paidInvoices,
      unpaidInvoices: unpaidInvoices,
    );
  }

  /// Generate statement transactions
  List<StatementTransaction> _generateStatementTransactions({
    required List<EnhancedInvoice> invoices,
    required List<CustomerPayment> payments,
    required double openingBalance,
  }) {
    final transactions = <StatementTransaction>[];
    double runningBalance = openingBalance;

    // Add opening balance if non-zero
    if (openingBalance != 0) {
      transactions.add(StatementTransaction(
        id: _uuid.v4(),
        date: invoices.isNotEmpty ? invoices.first.issueDate : DateTime.now(),
        type: StatementTransactionType.openingBalance,
        description: 'Opening Balance',
        reference: null,
        debit: openingBalance > 0 ? openingBalance : 0,
        credit: openingBalance < 0 ? -openingBalance : 0,
        balance: runningBalance,
      ));
    }

    // Combine and sort invoices and payments by date
    final allEntries = <_TransactionEntry>[];
    
    for (final invoice in invoices) {
      allEntries.add(_TransactionEntry(
        date: invoice.issueDate,
        type: 'invoice',
        data: invoice,
      ));
    }
    
    for (final payment in payments) {
      allEntries.add(_TransactionEntry(
        date: payment.paymentDate,
        type: 'payment',
        data: payment,
      ));
    }

    allEntries.sort((a, b) => a.date.compareTo(b.date));

    // Generate transactions in chronological order
    for (final entry in allEntries) {
      if (entry.type == 'invoice') {
        final invoice = entry.data as EnhancedInvoice;
        runningBalance += invoice.totalAmount;
        
        transactions.add(StatementTransaction.fromInvoice(
          id: _uuid.v4(),
          invoice: invoice,
          balance: runningBalance,
        ));
      } else if (entry.type == 'payment') {
        final payment = entry.data as CustomerPayment;
        runningBalance -= payment.amount;
        
        transactions.add(StatementTransaction.fromPayment(
          id: _uuid.v4(),
          payment: payment,
          balance: runningBalance,
        ));
      }
    }

    return transactions;
  }

  /// Get customer balance summary
  Future<CustomerBalanceSummary> getCustomerBalanceSummary(String customerId) async {
    try {
      // Get customer info - placeholder
      const customerName = 'Demo Customer'; // TODO: Get from customers table

      // Get current balance
      final currentBalance = await _calculateOpeningBalance(
        customerId: customerId,
        asOfDate: DateTime.now().add(const Duration(days: 1)),
      );

      // Get overdue invoices
      final now = DateTime.now();
      const overdueInvoicesSql = '''
        SELECT COALESCE(SUM(total_amount), 0) as overdue_amount,
               COUNT(*) as overdue_count
        FROM invoices 
        WHERE customer_id = ? 
        AND due_date < ? 
        AND status NOT IN ('paid', 'cancelled', 'voided')
      ''';

      final db = await _databaseService.database;
      final overdueResult = await db.rawQuery(overdueInvoicesSql, [
        customerId,
        now.toIso8601String(),
      ]);

      final overdueBalance = (overdueResult.first['overdue_amount'] as num?)?.toDouble() ?? 0.0;

      // Get total invoices count
      const totalInvoicesSql = '''
        SELECT COUNT(*) as total_invoices,
               COUNT(CASE WHEN status NOT IN ('paid', 'cancelled', 'voided') THEN 1 END) as unpaid_invoices
        FROM invoices 
        WHERE customer_id = ?
      ''';

      final invoicesResult = await db.rawQuery(totalInvoicesSql, [customerId]);
      final totalInvoices = (invoicesResult.first['total_invoices'] as int?) ?? 0;
      final unpaidInvoices = (invoicesResult.first['unpaid_invoices'] as int?) ?? 0;

      // Get last invoice date
      const lastInvoiceSql = '''
        SELECT MAX(issue_date) as last_invoice_date
        FROM invoices 
        WHERE customer_id = ?
      ''';

      final lastInvoiceResult = await db.rawQuery(lastInvoiceSql, [customerId]);
      final lastInvoiceDateStr = lastInvoiceResult.first['last_invoice_date'] as String?;
      final lastInvoiceDate = lastInvoiceDateStr != null 
          ? DateTime.parse(lastInvoiceDateStr)
          : DateTime.now();

      // Get last payment date
      const lastPaymentSql = '''
        SELECT MAX(payment_date) as last_payment_date
        FROM $_paymentsTable 
        WHERE customer_id = ?
      ''';

      final lastPaymentResult = await db.rawQuery(lastPaymentSql, [customerId]);
      final lastPaymentDateStr = lastPaymentResult.first['last_payment_date'] as String?;
      final lastPaymentDate = lastPaymentDateStr != null 
          ? DateTime.parse(lastPaymentDateStr)
          : null;

      final daysSinceLastPayment = lastPaymentDate != null
          ? now.difference(lastPaymentDate).inDays
          : 0;

      return CustomerBalanceSummary(
        customerId: customerId,
        customerName: customerName,
        currentBalance: currentBalance,
        overdueBalance: overdueBalance,
        lastInvoiceDate: lastInvoiceDate,
        lastPaymentDate: lastPaymentDate,
        totalInvoices: totalInvoices,
        unpaidInvoices: unpaidInvoices,
        daysSinceLastPayment: daysSinceLastPayment,
      );

    } catch (e) {
      // Return empty summary if queries fail
      return CustomerBalanceSummary(
        customerId: customerId,
        customerName: 'Unknown Customer',
        currentBalance: 0.0,
        overdueBalance: 0.0,
        lastInvoiceDate: DateTime.now(),
        totalInvoices: 0,
        unpaidInvoices: 0,
      );
    }
  }

  /// Get all customers with balances
  Future<List<CustomerBalanceSummary>> getAllCustomerBalances() async {
    try {
      // Get all customers with invoices - this is a simplified version
      const sql = '''
        SELECT DISTINCT customer_id, customer_name
        FROM invoices
        ORDER BY customer_name
      ''';

      final db = await _databaseService.database;
      final results = await db.rawQuery(sql);
      final balances = <CustomerBalanceSummary>[];

      for (final row in results) {
        final customerId = row['customer_id'] as String;
        final balance = await getCustomerBalanceSummary(customerId);
        balances.add(balance);
      }

      return balances;
    } catch (e) {
      return [];
    }
  }

  /// Log statement generation
  Future<void> _logStatementGeneration(CustomerStatement statement) async {
    const sql = '''
      INSERT INTO $_statementLogTable (
        id, customer_id, statement_date, period_start, period_end,
        generated_by, generated_at, file_path, email_sent
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''';

    final db = await _databaseService.database;
    await db.execute(sql, [
      _uuid.v4(),
      statement.summary.customerId,
      statement.summary.statementDate.toIso8601String(),
      statement.summary.periodStart.toIso8601String(),
      statement.summary.periodEnd.toIso8601String(),
      statement.generatedBy,
      statement.generatedAt.toIso8601String(),
      null, // file_path - would be set when PDF is generated
      0, // email_sent
    ]);
  }

  /// Generate bulk statements for all customers
  Future<List<CustomerStatement>> generateBulkStatements({
    StatementGenerationOptions? options,
  }) async {
    options ??= StatementGenerationOptions.currentMonth();
    
    final customers = await getAllCustomerBalances();
    final statements = <CustomerStatement>[];

    for (final customer in customers) {
      if (!options.includeZeroBalanceCustomers && customer.currentBalance == 0) {
        continue;
      }

      try {
        final statement = await generateCustomerStatement(
          customerId: customer.customerId,
          customerName: customer.customerName,
          options: options,
        );
        statements.add(statement);
      } catch (e) {
        // Log error but continue with other customers
        print('Error generating statement for ${customer.customerName}: $e');
      }
    }

    // Send bulk notification
    await _notificationService.sendNotification(
      title: 'Bulk Statements Generated',
      message: '${statements.length} customer statements generated successfully',
      data: {
        'type': 'bulk_statements_generated',
        'count': statements.length.toString(),
      },
    );

    return statements;
  }

  /// Convert database row to CustomerPayment
  CustomerPayment _paymentFromRow(Map<String, dynamic> row) {
    return CustomerPayment(
      id: row['id'],
      customerId: row['customer_id'],
      invoiceId: row['invoice_id'],
      invoiceNumber: row['invoice_number'],
      amount: (row['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(row['payment_date']),
      method: PaymentMethod.values.firstWhere(
        (m) => m.name == row['method'],
        orElse: () => PaymentMethod.other,
      ),
      reference: row['reference'],
      notes: row['notes'],
      createdAt: DateTime.parse(row['created_at']),
    );
  }
}

/// Helper class for sorting transactions
class _TransactionEntry {
  final DateTime date;
  final String type;
  final dynamic data;

  _TransactionEntry({
    required this.date,
    required this.type,
    required this.data,
  });
}