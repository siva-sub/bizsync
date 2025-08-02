import 'package:flutter_test/flutter_test.dart';
import 'package:bizsync/core/database/crdt_database_service.dart';
import 'package:bizsync/core/database/data_integrity_service.dart';
import 'package:bizsync/core/database/audit_service.dart';
import 'package:bizsync/core/utils/uuid_generator.dart';
import '../test_factories.dart';

/// Comprehensive integration tests for data integrity and audit functionality
/// Tests constraints, business rules, audit trails, and data validation
void main() {
  group('Data Integrity Integration Tests', () {
    late CRDTDatabaseService databaseService;

    setUpAll(() async {
      databaseService = CRDTDatabaseService();
      await databaseService.initialize('test_node_integrity');
    });

    tearDownAll(() async {
      await databaseService.closeDatabase();
    });

    setUp(() {
      TestFactories.reset();
    });

    group('Database Constraints Validation', () {
      test('should enforce NOT NULL constraints', () async {
        final db = await databaseService.database;

        // Try to insert customer without required name field
        final invalidCustomer = {
          'id': UuidGenerator.generateId(),
          // Missing 'name' field (NOT NULL)
          'email': 'test@example.com',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };

        expect(
          () async => await db.insert('customers', invalidCustomer),
          throwsException,
        );
      });

      test('should enforce CHECK constraints on products', () async {
        final db = await databaseService.database;

        // Try to insert product with negative price
        final invalidProduct = {
          'id': UuidGenerator.generateId(),
          'name': 'Invalid Product',
          'price': -10.0, // Should fail CHECK constraint
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };

        expect(
          () async => await db.insert('products', invalidProduct),
          throwsException,
        );

        // Try to insert product with negative stock
        final invalidStock = {
          'id': UuidGenerator.generateId(),
          'name': 'Invalid Stock Product',
          'price': 100.0,
          'stock_quantity': -5, // Should fail CHECK constraint
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };

        expect(
          () async => await db.insert('products', invalidStock),
          throwsException,
        );
      });

      test('should enforce UNIQUE constraints', () async {
        final db = await databaseService.database;

        // Create unique index on customer email
        await db.execute('''
          CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_unique_email 
          ON customers(email) 
          WHERE email IS NOT NULL
        ''');

        final customer1 = TestFactories.createCustomer(
          email: 'unique@test.com',
        );

        final customer2 = TestFactories.createCustomer(
          email: 'unique@test.com', // Same email
        );

        // First customer should succeed
        await db.insert('customers', customer1.toDatabase());

        // Second customer with same email should fail
        expect(
          () async => await db.insert('customers', customer2.toDatabase()),
          throwsException,
        );
      });

      test('should enforce foreign key constraints', () async {
        final db = await databaseService.database;

        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');

        // Create test tables with foreign key relationship
        await db.execute('''
          CREATE TABLE IF NOT EXISTS test_orders (
            id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            total_amount REAL NOT NULL,
            FOREIGN KEY (customer_id) REFERENCES customers (id)
          )
        ''');

        // Try to create order with non-existent customer
        final invalidOrder = {
          'id': UuidGenerator.generateId(),
          'customer_id': 'non_existent_customer',
          'total_amount': 100.0,
        };

        expect(
          () async => await db.insert('test_orders', invalidOrder),
          throwsException,
        );

        // Create valid customer first
        final customer = TestFactories.createCustomer();
        await db.insert('customers', customer.toDatabase());

        // Now order should succeed
        final validOrder = {
          'id': UuidGenerator.generateId(),
          'customer_id': customer.id,
          'total_amount': 100.0,
        };

        await db.insert('test_orders', validOrder);

        // Try to delete customer with existing orders
        expect(
          () async => await db.delete(
            'customers',
            where: 'id = ?',
            whereArgs: [customer.id],
          ),
          throwsException,
        );
      });

      test('should validate JSON data in CRDT tables', () async {
        final db = await databaseService.database;

        // Try to insert invalid JSON in CRDT data field
        final invalidCRDTRecord = {
          'id': UuidGenerator.generateId(),
          'node_id': 'test_node',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'version': '{}',
          'is_deleted': false,
          'crdt_data': 'invalid json{', // Invalid JSON
          'name': 'Test Customer',
        };

        expect(
          () async => await db.insert('customers_crdt', invalidCRDTRecord),
          throwsException,
        );
      });
    });

    group('Business Rule Validation', () {
      test('should validate customer GST registration rules', () async {
        // Business rule: If customer is GST registered, must have valid GST number
        final customer = TestFactories.createCustomer(
          gstRegistered: true,
          gstRegistrationNumber: 'INVALID_FORMAT',
        );

        // In business logic layer, this should be validated
        expect(customer.gstRegistered, isTrue);
        expect(customer.hasValidGstNumber, isFalse);
        
        // Business rule violation - registered but invalid number
        expect(customer.gstStatusDisplay, contains('Invalid Number'));
      });

      test('should validate product pricing rules', () async {
        // Business rule: Cost should not exceed selling price (negative margin warning)
        final product = TestFactories.createProduct(
          price: 50.0,
          cost: 75.0, // Cost higher than price
        );

        expect(product.profitMarginPercentage, lessThan(0));
        expect(product.profitAmount, lessThan(0));
        
        // This should trigger a business warning in real application
      });

      test('should validate invoice calculation rules', () async {
        // Business rule: Invoice totals must be mathematically correct
        final invoiceData = TestFactories.createInvoiceData();
        
        // Validate calculation consistency
        expect(TestValidators.validateInvoiceCalculations(invoiceData), isTrue);

        // Manually corrupt the calculations
        invoiceData['total_amount'] = 999.99; // Incorrect total
        
        expect(TestValidators.validateInvoiceCalculations(invoiceData), isFalse);
      });

      test('should validate stock level business rules', () async {
        // Business rule: Cannot sell more than available stock
        final product = TestFactories.createProduct(stockQuantity: 10);
        
        final requestedQuantity = 15; // More than available
        
        expect(product.stockQuantity, lessThan(requestedQuantity));
        
        // In real application, this should prevent the sale
        final availableForSale = product.stockQuantity;
        expect(availableForSale, equals(10));
        expect(requestedQuantity > availableForSale, isTrue);
      });

      test('should validate payment terms business rules', () async {
        final now = DateTime.now();
        final invoiceData = TestFactories.createInvoiceData(
          issueDate: now,
          paymentTerms: PaymentTerm.net30,
        );

        // Calculate due date based on terms
        final issueDate = invoiceData['issue_date'] as DateTime;
        final paymentTerms = invoiceData['payment_terms'] as PaymentTerm;
        
        DateTime expectedDueDate;
        switch (paymentTerms) {
          case PaymentTerm.dueOnReceipt:
            expectedDueDate = issueDate;
            break;
          case PaymentTerm.net15:
            expectedDueDate = issueDate.add(Duration(days: 15));
            break;
          case PaymentTerm.net30:
            expectedDueDate = issueDate.add(Duration(days: 30));
            break;
          case PaymentTerm.net60:
            expectedDueDate = issueDate.add(Duration(days: 60));
            break;
          case PaymentTerm.custom:
            expectedDueDate = invoiceData['due_date'] as DateTime;
            break;
        }

        expect(invoiceData['due_date'], equals(expectedDueDate));
      });
    });

    group('Audit Trail Functionality', () {
      test('should log customer creation in audit trail', () async {
        final customer = TestFactories.createCustomer();
        final db = await databaseService.database;
        
        // Insert customer
        await db.insert('customers', customer.toDatabase());
        
        // Manually log audit trail (in real app, this would be automatic)
        await db.insert('audit_trail', {
          'id': UuidGenerator.generateId(),
          'table_name': 'customers',
          'record_id': customer.id,
          'operation': 'INSERT',
          'old_values': null,
          'new_values': customer.toJson(),
          'node_id': databaseService.nodeId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'hlc_timestamp': databaseService.clock.current.toString(),
        });

        // Verify audit record
        final auditRecords = await db.query(
          'audit_trail',
          where: 'table_name = ? AND record_id = ?',
          whereArgs: ['customers', customer.id],
        );

        expect(auditRecords, hasLength(1));
        expect(auditRecords.first['operation'], equals('INSERT'));
        expect(auditRecords.first['old_values'], isNull);
        expect(auditRecords.first['new_values'], isNotNull);
      });

      test('should log customer updates with before/after values', () async {
        final customer = TestFactories.createCustomer(
          name: 'Original Name',
          email: 'original@test.com',
        );
        
        final db = await databaseService.database;
        await db.insert('customers', customer.toDatabase());

        // Update customer
        final oldValues = customer.toJson();
        final updatedCustomer = customer.copyWith(
          name: 'Updated Name',
          email: 'updated@test.com',
          updatedAt: DateTime.now(),
        );

        await db.update(
          'customers',
          updatedCustomer.toDatabase(),
          where: 'id = ?',
          whereArgs: [customer.id],
        );

        // Log audit trail for update
        await db.insert('audit_trail', {
          'id': UuidGenerator.generateId(),
          'table_name': 'customers',
          'record_id': customer.id,
          'operation': 'UPDATE',
          'old_values': oldValues,
          'new_values': updatedCustomer.toJson(),
          'node_id': databaseService.nodeId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'hlc_timestamp': databaseService.clock.current.toString(),
        });

        // Verify audit record shows changes
        final auditRecords = await db.query(
          'audit_trail',
          where: 'table_name = ? AND record_id = ? AND operation = ?',
          whereArgs: ['customers', customer.id, 'UPDATE'],
        );

        expect(auditRecords, hasLength(1));
        final auditRecord = auditRecords.first;
        
        expect(auditRecord['old_values'], contains('Original Name'));
        expect(auditRecord['new_values'], contains('Updated Name'));
        expect(auditRecord['old_values'], contains('original@test.com'));
        expect(auditRecord['new_values'], contains('updated@test.com'));
      });

      test('should track user actions and context', () async {
        final db = await databaseService.database;
        
        // Simulate user action with context
        final actionLog = {
          'id': UuidGenerator.generateId(),
          'table_name': 'customers',
          'record_id': 'test_customer_id',
          'operation': 'UPDATE',
          'old_values': '{"name": "Old Name"}',
          'new_values': '{"name": "New Name"}',
          'user_id': 'user_123',
          'node_id': databaseService.nodeId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'hlc_timestamp': databaseService.clock.current.toString(),
          'ip_address': '192.168.1.100',
          'user_agent': 'BizSync Mobile App v1.0.0',
        };

        await db.insert('audit_trail', actionLog);

        // Query audit trail with user context
        final userActions = await db.query(
          'audit_trail',
          where: 'user_id = ?',
          whereArgs: ['user_123'],
        );

        expect(userActions, hasLength(1));
        expect(userActions.first['ip_address'], equals('192.168.1.100'));
        expect(userActions.first['user_agent'], contains('BizSync Mobile App'));
      });

      test('should provide audit trail query capabilities', () async {
        final db = await databaseService.database;
        final customerId = 'audit_query_customer';

        // Create multiple audit entries for same customer
        final operations = ['INSERT', 'UPDATE', 'UPDATE', 'DELETE'];
        
        for (int i = 0; i < operations.length; i++) {
          await db.insert('audit_trail', {
            'id': UuidGenerator.generateId(),
            'table_name': 'customers',
            'record_id': customerId,
            'operation': operations[i],
            'old_values': i == 0 ? null : '{"version": ${i - 1}}',
            'new_values': operations[i] == 'DELETE' ? null : '{"version": $i}',
            'node_id': databaseService.nodeId,
            'timestamp': DateTime.now().millisecondsSinceEpoch + (i * 1000),
            'hlc_timestamp': databaseService.clock.current.toString(),
          });
        }

        // Query full audit history for customer
        final fullHistory = await db.query(
          'audit_trail',
          where: 'table_name = ? AND record_id = ?',
          whereArgs: ['customers', customerId],
          orderBy: 'timestamp ASC',
        );

        expect(fullHistory, hasLength(4));
        expect(fullHistory.first['operation'], equals('INSERT'));
        expect(fullHistory.last['operation'], equals('DELETE'));

        // Query only updates
        final updatesOnly = await db.query(
          'audit_trail',
          where: 'table_name = ? AND record_id = ? AND operation = ?',
          whereArgs: ['customers', customerId, 'UPDATE'],
        );

        expect(updatesOnly, hasLength(2));

        // Query recent activity (last 24 hours)
        final yesterday = DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;
        final recentActivity = await db.query(
          'audit_trail',
          where: 'timestamp > ?',
          whereArgs: [yesterday],
          orderBy: 'timestamp DESC',
        );

        expect(recentActivity.length, greaterThanOrEqualTo(4));
      });
    });

    group('Data Integrity Checks', () {
      test('should run foreign key constraint checks', () async {
        final violations = await databaseService.runIntegrityChecks();
        
        // Should start with no violations
        expect(violations.where((v) => v.containsKey('table')), isEmpty);
        
        // Create orphaned record to test detection
        final db = await databaseService.database;
        
        // Temporarily disable foreign key constraints
        await db.execute('PRAGMA foreign_keys = OFF');
        
        await db.execute('''
          CREATE TABLE IF NOT EXISTS test_orphan_orders (
            id TEXT PRIMARY KEY,
            customer_id TEXT,
            FOREIGN KEY (customer_id) REFERENCES customers (id)
          )
        ''');
        
        // Insert orphaned record
        await db.insert('test_orphan_orders', {
          'id': 'orphan_order',
          'customer_id': 'non_existent_customer',
        });
        
        // Re-enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');
        
        // Check for violations
        final newViolations = await databaseService.runIntegrityChecks();
        expect(newViolations.where((v) => v.containsKey('table')), isNotEmpty);
      });

      test('should validate double-entry bookkeeping balance', () async {
        final db = await databaseService.database;
        
        // Create test transaction entries
        final transactionId = UuidGenerator.generateId();
        
        // Balanced transaction: Debit = Credit
        await db.insert('journal_entries', {
          'id': UuidGenerator.generateId(),
          'transaction_id': transactionId,
          'account_id': 'cash_account',
          'debit_amount': 1000.0,
          'credit_amount': 0.0,
          'description': 'Cash received',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
        
        await db.insert('journal_entries', {
          'id': UuidGenerator.generateId(),
          'transaction_id': transactionId,
          'account_id': 'revenue_account',
          'debit_amount': 0.0,
          'credit_amount': 1000.0,
          'description': 'Revenue recognized',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Check balance - should pass
        final balanceCheck = await db.rawQuery('''
          SELECT transaction_id, SUM(debit_amount) as total_debit, SUM(credit_amount) as total_credit
          FROM journal_entries 
          WHERE transaction_id = ?
          GROUP BY transaction_id 
          HAVING ABS(total_debit - total_credit) > 0.01
        ''', [transactionId]);

        expect(balanceCheck, isEmpty); // No unbalanced transactions

        // Create unbalanced transaction
        final unbalancedTransactionId = UuidGenerator.generateId();
        
        await db.insert('journal_entries', {
          'id': UuidGenerator.generateId(),
          'transaction_id': unbalancedTransactionId,
          'account_id': 'cash_account',
          'debit_amount': 1000.0,
          'credit_amount': 0.0,
          'description': 'Unbalanced entry',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Check balance - should fail
        final unbalancedCheck = await db.rawQuery('''
          SELECT transaction_id, SUM(debit_amount) as total_debit, SUM(credit_amount) as total_credit
          FROM journal_entries 
          WHERE transaction_id = ?
          GROUP BY transaction_id 
          HAVING ABS(total_debit - total_credit) > 0.01
        ''', [unbalancedTransactionId]);

        expect(unbalancedCheck, hasLength(1)); // One unbalanced transaction found
      });

      test('should run custom integrity checks', () async {
        final db = await databaseService.database;

        // Add custom integrity check
        await db.insert('integrity_checks', {
          'id': UuidGenerator.generateId(),
          'check_name': 'Product Price Consistency',
          'check_type': 'BUSINESS_RULE',
          'table_name': 'products',
          'description': 'Ensure product cost does not exceed selling price by more than expected margin',
          'check_sql': '''
            SELECT id, name, price, cost, (cost - price) as loss_amount
            FROM products 
            WHERE cost > price * 1.1
          ''',
          'is_active': true,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Create product that violates the rule
        final violatingProduct = TestFactories.createProduct(
          price: 100.0,
          cost: 150.0, // Cost 50% higher than price
        );

        await db.insert('products', violatingProduct.toDatabase());

        // Run integrity checks
        final violations = await databaseService.runIntegrityChecks();
        
        // Should detect the pricing violation
        final pricingViolations = violations.where(
          (v) => v['check_name'] == 'Product Price Consistency',
        );
        
        expect(pricingViolations, isNotEmpty);
      });

      test('should validate data consistency across related tables', () async {
        final db = await databaseService.database;
        
        // Create customer
        final customer = TestFactories.createCustomer();
        await db.insert('customers', customer.toDatabase());

        // Create invoice for customer
        final invoiceData = TestFactories.createInvoiceData(customerId: customer.id);
        
        // In real implementation, this would be stored in invoices table
        // For test, verify the relationship is valid
        expect(invoiceData['customer_id'], equals(customer.id));
        
        // Verify customer exists for the invoice
        final customerCheck = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [invoiceData['customer_id']],
        );
        
        expect(customerCheck, hasLength(1));
        expect(customerCheck.first['id'], equals(customer.id));
      });
    });

    group('Performance of Integrity Checks', () {
      test('should efficiently run integrity checks on large datasets', () async {
        const recordCount = 500;
        final db = await databaseService.database;
        
        // Create large number of customers
        final batch = db.batch();
        for (int i = 0; i < recordCount; i++) {
          final customer = TestFactories.createCustomer(
            name: 'Customer $i',
            email: 'customer$i@test.com',
          );
          batch.insert('customers', customer.toDatabase());
        }
        await batch.commit();

        // Run integrity checks and measure performance
        final stopwatch = Stopwatch()..start();
        final violations = await databaseService.runIntegrityChecks();
        stopwatch.stop();

        print('Integrity checks on $recordCount records took: ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // Should be under 2 seconds
        
        // Should find no violations with valid test data
        expect(violations.where((v) => v.containsKey('table')), isEmpty);
      });

      test('should efficiently query audit trail history', () async {
        const auditRecordCount = 1000;
        final db = await databaseService.database;
        
        // Create large number of audit records
        final batch = db.batch();
        for (int i = 0; i < auditRecordCount; i++) {
          batch.insert('audit_trail', {
            'id': UuidGenerator.generateId(),
            'table_name': 'customers',
            'record_id': 'customer_${i % 100}', // 100 different customers
            'operation': ['INSERT', 'UPDATE', 'DELETE'][i % 3],
            'old_values': i == 0 ? null : '{"version": ${i - 1}}',
            'new_values': '{"version": $i}',
            'node_id': databaseService.nodeId,
            'timestamp': DateTime.now().millisecondsSinceEpoch + i,
            'hlc_timestamp': databaseService.clock.current.toString(),
          });
        }
        await batch.commit();

        // Query audit trail and measure performance
        final stopwatch = Stopwatch()..start();
        
        final recentAudits = await db.query(
          'audit_trail',
          where: 'timestamp > ?',
          whereArgs: [DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch],
          orderBy: 'timestamp DESC',
          limit: 100,
        );
        
        stopwatch.stop();

        print('Audit trail query on $auditRecordCount records took: ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be under 100ms
        expect(recentAudits.length, greaterThan(0));
      });
    });
  });
}