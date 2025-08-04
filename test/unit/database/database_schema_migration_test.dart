/// Database schema migration tests
library database_schema_migration_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../test_config.dart';

void main() {
  group('Database Schema Migration Tests', () {
    late Database database;
    
    setUpAll(() async {
      await TestConfig.initialize();
    });
    
    setUp(() async {
      await TestConfig.reset();
      database = await TestDatabaseConfig.getInMemoryDatabase();
    });
    
    tearDown(() async {
      await database.close();
    });
    
    group('Initial Schema Creation', () {
      test('should create all required tables', () async {
        // Test that all tables exist
        final tables = await database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        );
        
        final tableNames = tables.map((table) => table['name'] as String).toSet();
        
        expect(tableNames, contains('customers'));
        expect(tableNames, contains('products'));
        expect(tableNames, contains('invoices'));
        expect(tableNames, contains('invoice_line_items'));
        expect(tableNames, contains('crdt_operations'));
      });
      
      test('should create customers table with correct schema', () async {
        final result = await database.rawQuery("PRAGMA table_info(customers)");
        
        final columnNames = result.map((col) => col['name'] as String).toSet();
        
        expect(columnNames, contains('id'));
        expect(columnNames, contains('name'));
        expect(columnNames, contains('email'));
        expect(columnNames, contains('phone'));
        expect(columnNames, contains('address'));
        expect(columnNames, contains('gst_registered'));
        expect(columnNames, contains('gst_registration_number'));
        expect(columnNames, contains('country_code'));
        expect(columnNames, contains('billing_address'));
        expect(columnNames, contains('shipping_address'));
        expect(columnNames, contains('created_at'));
        expect(columnNames, contains('updated_at'));
        
        // Verify primary key
        final primaryKeyCol = result.firstWhere((col) => col['name'] == 'id');
        expect(primaryKeyCol['pk'], equals(1));
        
        // Verify NOT NULL constraints
        final nameCol = result.firstWhere((col) => col['name'] == 'name');
        expect(nameCol['notnull'], equals(1));
      });
      
      test('should create products table with correct schema', () async {
        final result = await database.rawQuery("PRAGMA table_info(products)");
        
        final columnNames = result.map((col) => col['name'] as String).toSet();
        
        expect(columnNames, contains('id'));
        expect(columnNames, contains('name'));
        expect(columnNames, contains('description'));
        expect(columnNames, contains('price'));
        expect(columnNames, contains('cost'));
        expect(columnNames, contains('stock_quantity'));
        expect(columnNames, contains('min_stock_level'));
        expect(columnNames, contains('category_id'));
        expect(columnNames, contains('category'));
        expect(columnNames, contains('barcode'));
        expect(columnNames, contains('created_at'));
        expect(columnNames, contains('updated_at'));
        
        // Verify primary key
        final primaryKeyCol = result.firstWhere((col) => col['name'] == 'id');
        expect(primaryKeyCol['pk'], equals(1));
        
        // Verify NOT NULL constraints
        final nameCol = result.firstWhere((col) => col['name'] == 'name');
        expect(nameCol['notnull'], equals(1));
        
        final priceCol = result.firstWhere((col) => col['name'] == 'price');
        expect(priceCol['notnull'], equals(1));
      });
      
      test('should create invoices table with correct schema', () async {
        final result = await database.rawQuery("PRAGMA table_info(invoices)");
        
        final columnNames = result.map((col) => col['name'] as String).toSet();
        
        expect(columnNames, contains('id'));
        expect(columnNames, contains('invoice_number'));
        expect(columnNames, contains('customer_id'));
        expect(columnNames, contains('customer_name'));
        expect(columnNames, contains('customer_email'));
        expect(columnNames, contains('customer_gst_registered'));
        expect(columnNames, contains('customer_country_code'));
        expect(columnNames, contains('issue_date'));
        expect(columnNames, contains('due_date'));
        expect(columnNames, contains('payment_terms'));
        expect(columnNames, contains('status'));
        expect(columnNames, contains('subtotal'));
        expect(columnNames, contains('discount_amount'));
        expect(columnNames, contains('tax_amount'));
        expect(columnNames, contains('total_amount'));
        expect(columnNames, contains('currency'));
        expect(columnNames, contains('notes'));
        expect(columnNames, contains('created_at'));
        expect(columnNames, contains('updated_at'));
        
        // Verify required NOT NULL fields
        final requiredFields = ['id', 'invoice_number', 'customer_id', 'customer_name', 
                               'issue_date', 'due_date', 'payment_terms', 'status',
                               'subtotal', 'tax_amount', 'total_amount', 'created_at', 'updated_at'];
        
        for (final field in requiredFields) {
          final col = result.firstWhere((col) => col['name'] == field);
          expect(col['notnull'], equals(1), reason: '$field should be NOT NULL');
        }
      });
      
      test('should create invoice_line_items table with foreign key constraint', () async {
        final result = await database.rawQuery("PRAGMA table_info(invoice_line_items)");
        
        final columnNames = result.map((col) => col['name'] as String).toSet();
        
        expect(columnNames, contains('id'));
        expect(columnNames, contains('invoice_id'));
        expect(columnNames, contains('product_id'));
        expect(columnNames, contains('product_name'));
        expect(columnNames, contains('description'));
        expect(columnNames, contains('quantity'));
        expect(columnNames, contains('unit_price'));
        expect(columnNames, contains('discount_amount'));
        expect(columnNames, contains('tax_rate'));
        expect(columnNames, contains('line_total'));
        
        // Check foreign key constraints
        final foreignKeys = await database.rawQuery("PRAGMA foreign_key_list(invoice_line_items)");
        expect(foreignKeys.isNotEmpty, isTrue);
        
        final invoiceForeignKey = foreignKeys.firstWhere(
          (fk) => fk['from'] == 'invoice_id' && fk['table'] == 'invoices',
        );
        expect(invoiceForeignKey['to'], equals('id'));
      });
      
      test('should create crdt_operations table with correct schema', () async {
        final result = await database.rawQuery("PRAGMA table_info(crdt_operations)");
        
        final columnNames = result.map((col) => col['name'] as String).toSet();
        
        expect(columnNames, contains('id'));
        expect(columnNames, contains('entity_type'));
        expect(columnNames, contains('entity_id'));
        expect(columnNames, contains('operation_type'));
        expect(columnNames, contains('operation_data'));
        expect(columnNames, contains('timestamp'));
        expect(columnNames, contains('node_id'));
        expect(columnNames, contains('vector_clock'));
        expect(columnNames, contains('applied'));
        
        // Verify required NOT NULL fields
        final requiredFields = ['id', 'entity_type', 'entity_id', 'operation_type', 
                               'operation_data', 'timestamp', 'node_id', 'vector_clock'];
        
        for (final field in requiredFields) {
          final col = result.firstWhere((col) => col['name'] == field);
          expect(col['notnull'], equals(1), reason: '$field should be NOT NULL');
        }
      });
    });
    
    group('Schema Migration Scenarios', () {
      test('should handle adding new column to existing table', () async {
        // Simulate adding a new column
        await database.execute('ALTER TABLE customers ADD COLUMN notes TEXT');
        
        final result = await database.rawQuery("PRAGMA table_info(customers)");
        final columnNames = result.map((col) => col['name'] as String).toSet();
        
        expect(columnNames, contains('notes'));
      });
      
      test('should handle adding new table', () async {
        // Simulate adding a new table
        await database.execute('''
          CREATE TABLE vendors (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT,
            phone TEXT,
            address TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        
        final tables = await database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='vendors'"
        );
        
        expect(tables.isNotEmpty, isTrue);
      });
      
      test('should handle creating indexes for performance', () async {
        // Create indexes that would be added in migrations
        await database.execute('CREATE INDEX idx_customers_email ON customers(email)');
        await database.execute('CREATE INDEX idx_products_category ON products(category_id)');
        await database.execute('CREATE INDEX idx_invoices_customer ON invoices(customer_id)');
        await database.execute('CREATE INDEX idx_invoices_status ON invoices(status)');
        await database.execute('CREATE INDEX idx_crdt_operations_entity ON crdt_operations(entity_type, entity_id)');
        
        // Verify indexes were created
        final indexes = await database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'"
        );
        
        final indexNames = indexes.map((idx) => idx['name'] as String).toSet();
        
        expect(indexNames, contains('idx_customers_email'));
        expect(indexNames, contains('idx_products_category'));
        expect(indexNames, contains('idx_invoices_customer'));
        expect(indexNames, contains('idx_invoices_status'));
        expect(indexNames, contains('idx_crdt_operations_entity'));
      });
    });
    
    group('Data Integrity Tests', () {
      test('should enforce NOT NULL constraints', () async {
        expect(
          () => database.insert('customers', {'id': null, 'name': 'Test'}),
          throwsA(isA<DatabaseException>()),
        );
        
        expect(
          () => database.insert('customers', {'id': 'test-id', 'name': null}),
          throwsA(isA<DatabaseException>()),
        );
      });
      
      test('should enforce foreign key constraints', () async {
        // Enable foreign key constraints
        await database.execute('PRAGMA foreign_keys = ON');
        
        // Try to insert line item with non-existent invoice
        expect(
          () => database.insert('invoice_line_items', {
            'id': 'test-line-item',
            'invoice_id': 'non-existent-invoice',
            'product_name': 'Test Product',
            'quantity': 1.0,
            'unit_price': 100.0,
            'line_total': 100.0,
          }),
          throwsA(isA<DatabaseException>()),
        );
      });
      
      test('should handle UNIQUE constraints', () async {
        // Add UNIQUE constraint to invoice_number
        await database.execute('CREATE UNIQUE INDEX idx_invoice_number_unique ON invoices(invoice_number)');
        
        // Insert first invoice
        await database.insert('invoices', {
          'id': 'invoice-1',
          'invoice_number': 'INV-001',
          'customer_id': 'customer-1',
          'customer_name': 'Test Customer',
          'issue_date': DateTime.now().toIso8601String(),
          'due_date': DateTime.now().add(Duration(days: 30)).toIso8601String(),
          'payment_terms': 'net30',
          'status': 'draft',
          'subtotal': 100.0,
          'tax_amount': 9.0,
          'total_amount': 109.0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        // Try to insert duplicate invoice number
        expect(
          () => database.insert('invoices', {
            'id': 'invoice-2',
            'invoice_number': 'INV-001', // Duplicate
            'customer_id': 'customer-2',
            'customer_name': 'Another Customer',
            'issue_date': DateTime.now().toIso8601String(),
            'due_date': DateTime.now().add(Duration(days: 30)).toIso8601String(),
            'payment_terms': 'net30',
            'status': 'draft',
            'subtotal': 200.0,
            'tax_amount': 18.0,
            'total_amount': 218.0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }),
          throwsA(isA<DatabaseException>()),
        );
      });
    });
    
    group('Performance Tests', () {
      test('should execute queries within acceptable time limits', () async {
        // Insert test data
        for (int i = 0; i < TestConstants.mediumDatasetSize; i++) {
          await database.insert('customers', {
            'id': 'customer-$i',
            'name': 'Customer $i',
            'email': 'customer$i@test.com',
            'phone': '+65 9123456$i',
            'address': 'Address $i',
            'gst_registered': i % 2 == 0 ? 1 : 0,
            'country_code': 'SG',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
        
        // Test query performance
        final result = await TestPerformanceUtils.performanceTest(
          'Customer query with 100 records',
          () async {
            await database.query('customers', limit: 50);
          },
          TestConstants.maxDatabaseQueryTime,
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
      
      test('should handle complex joins efficiently', () async {
        // Insert test customers
        for (int i = 0; i < 10; i++) {
          await database.insert('customers', {
            'id': 'customer-$i',
            'name': 'Customer $i',
            'email': 'customer$i@test.com',
            'phone': '+65 9123456$i',
            'address': 'Address $i',
            'gst_registered': 1,
            'country_code': 'SG',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
        
        // Insert test invoices
        for (int i = 0; i < 50; i++) {
          await database.insert('invoices', {
            'id': 'invoice-$i',
            'invoice_number': 'INV-${i.toString().padLeft(3, '0')}',
            'customer_id': 'customer-${i % 10}',
            'customer_name': 'Customer ${i % 10}',
            'issue_date': DateTime.now().toIso8601String(),
            'due_date': DateTime.now().add(Duration(days: 30)).toIso8601String(),
            'payment_terms': 'net30',
            'status': 'draft',
            'subtotal': 100.0 * (i + 1),
            'tax_amount': 9.0 * (i + 1),
            'total_amount': 109.0 * (i + 1),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
        
        // Test complex join query performance
        final result = await TestPerformanceUtils.performanceTest(
          'Complex join query',
          () async {
            await database.rawQuery('''
              SELECT c.name as customer_name, i.invoice_number, i.total_amount
              FROM customers c
              JOIN invoices i ON c.id = i.customer_id
              WHERE c.gst_registered = 1
              ORDER BY i.total_amount DESC
              LIMIT 20
            ''');
          },
          TestConstants.maxDatabaseQueryTime * 2, // Allow more time for complex queries
        );
        
        expect(result.passed, isTrue, reason: result.message);
      });
    });
    
    group('CRDT Operations Schema Tests', () {
      test('should support CRDT operations storage', () async {
        final operation = {
          'id': 'op-1',
          'entity_type': 'customer',
          'entity_id': 'customer-1',
          'operation_type': 'update',
          'operation_data': '{"name": "Updated Customer"}',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'node_id': 'node-1',
          'vector_clock': '{"node-1": 1, "node-2": 0}',
          'applied': 0,
        };
        
        await database.insert('crdt_operations', operation);
        
        final result = await database.query('crdt_operations', where: 'id = ?', whereArgs: ['op-1']);
        
        expect(result.isNotEmpty, isTrue);
        expect(result.first['entity_type'], equals('customer'));
        expect(result.first['operation_type'], equals('update'));
      });
      
      test('should support querying pending CRDT operations', () async {
        // Insert multiple operations
        for (int i = 0; i < 5; i++) {
          await database.insert('crdt_operations', {
            'id': 'op-$i',
            'entity_type': 'product',
            'entity_id': 'product-$i',
            'operation_type': 'create',
            'operation_data': '{"name": "Product $i"}',
            'timestamp': DateTime.now().millisecondsSinceEpoch + i,
            'node_id': 'node-1',
            'vector_clock': '{"node-1": $i}',
            'applied': i % 2, // Some applied, some pending
          });
        }
        
        final pendingOps = await database.query(
          'crdt_operations',
          where: 'applied = ?',
          whereArgs: [0],
          orderBy: 'timestamp ASC',
        );
        
        expect(pendingOps.length, equals(3)); // 0, 2, 4
      });
    });
  });
}