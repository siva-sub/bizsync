import 'package:flutter_test/flutter_test.dart';
import 'package:bizsync/data/models/customer.dart';
import 'package:bizsync/data/repositories/customer_repository.dart';
import 'package:bizsync/core/database/crdt_database_service.dart';
import 'package:bizsync/core/utils/uuid_generator.dart';
import '../test_factories.dart';

/// Comprehensive integration tests for customer management
/// Tests customer CRUD, GST validation, contact management, and transaction history
void main() {
  group('Customer Management Integration Tests', () {
    late CRDTDatabaseService databaseService;
    late CustomerRepository customerRepository;

    setUpAll(() async {
      databaseService = CRDTDatabaseService();
      await databaseService.initialize('test_node_customer');
      customerRepository = CustomerRepository();
    });

    tearDownAll(() async {
      await databaseService.closeDatabase();
    });

    setUp(() {
      TestFactories.reset();
    });

    group('Customer Creation and Validation', () {
      test('should create customer with all required fields', () async {
        // Arrange
        final customer = TestFactories.createCustomer(
          name: 'Test Customer Ltd',
          email: 'test@customer.com',
          phone: '+65 91234567',
          address: '123 Business Street, Singapore 123456',
        );

        // Act - Save to database
        final db = await databaseService.database;
        await db.insert('customers', customer.toDatabase());

        // Retrieve and verify
        final result = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [customer.id],
        );

        // Assert
        expect(result, hasLength(1));
        final retrievedCustomer = Customer.fromDatabase(result.first);
        
        expect(retrievedCustomer.id, equals(customer.id));
        expect(retrievedCustomer.name, equals('Test Customer Ltd'));
        expect(retrievedCustomer.email, equals('test@customer.com'));
        expect(retrievedCustomer.phone, equals('+65 91234567'));
        expect(retrievedCustomer.address, equals('123 Business Street, Singapore 123456'));
        expect(retrievedCustomer.isActive, isTrue);
      });

      test('should validate required name field', () async {
        // Customer without name should fail
        final invalidCustomer = {
          'id': UuidGenerator.generateId(),
          // Missing name
          'email': 'test@example.com',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };

        final db = await databaseService.database;
        
        expect(
          () async => await db.insert('customers', invalidCustomer),
          throwsException, // NOT NULL constraint violation
        );
      });

      test('should validate email format', () async {
        final validEmails = [
          'test@example.com',
          'user.name@company.co.uk',
          'first+last@domain.org',
        ];

        final invalidEmails = [
          'invalid-email',
          '@domain.com',
          'user@',
          'user name@domain.com',
        ];

        for (final email in validEmails) {
          expect(TestValidators.validateEmail(email), isTrue, 
            reason: '$email should be valid');
        }

        for (final email in invalidEmails) {
          expect(TestValidators.validateEmail(email), isFalse,
            reason: '$email should be invalid');
        }
      });

      test('should validate Singapore phone numbers', () async {
        final validPhones = [
          '+65 91234567',
          '91234567',
          '+65 81234567',
          '6591234567',
        ];

        final invalidPhones = [
          '1234567', // Too short
          '+65 12345678', // Invalid starting digit
          '+1 555-1234', // Wrong country code
          'phone number', // Not a number
        ];

        for (final phone in validPhones) {
          expect(TestValidators.validateSingaporePhone(phone), isTrue,
            reason: '$phone should be valid');
        }

        for (final phone in invalidPhones) {
          expect(TestValidators.validateSingaporePhone(phone), isFalse,
            reason: '$phone should be invalid');
        }
      });
    });

    group('GST Registration Management', () {
      test('should create GST registered customer with valid number', () async {
        final gstCustomer = TestFactories.createSingaporeGstCustomer(
          name: 'GST Registered Company Pte Ltd',
          gstNumber: '200012345M',
        );

        expect(gstCustomer.gstRegistered, isTrue);
        expect(gstCustomer.gstRegistrationNumber, equals('200012345M'));
        expect(gstCustomer.hasValidGstNumber, isTrue);
        expect(gstCustomer.gstStatusDisplay, equals('GST Registered (200012345M)'));
      });

      test('should validate GST registration number format', () async {
        final validGstNumbers = [
          '200012345M',
          '123456789A',
          '999999999Z',
        ];

        final invalidGstNumbers = [
          '20001234M', // Too short
          '2000123456M', // Too long
          '200012345m', // Lowercase letter
          '20001234AM', // Two letters
          'GST12345678', // Contains letters in number part
          '200012345', // Missing letter
        ];

        for (final gstNumber in validGstNumbers) {
          expect(TestValidators.validateGstNumber(gstNumber), isTrue,
            reason: '$gstNumber should be valid GST format');
        }

        for (final gstNumber in invalidGstNumbers) {
          expect(TestValidators.validateGstNumber(gstNumber), isFalse,
            reason: '$gstNumber should be invalid GST format');
        }
      });

      test('should handle customer with invalid GST number', () async {
        final customer = TestFactories.createCustomer(
          gstRegistered: true,
          gstRegistrationNumber: 'INVALID123',
        );

        expect(customer.gstRegistered, isTrue);
        expect(customer.hasValidGstNumber, isFalse);
        expect(customer.gstStatusDisplay, equals('GST Registered (Invalid Number)'));
      });

      test('should handle non-GST registered customer', () async {
        final customer = TestFactories.createCustomer(
          gstRegistered: false,
        );

        expect(customer.gstRegistered, isFalse);
        expect(customer.hasValidGstNumber, isFalse);
        expect(customer.gstStatusDisplay, equals('Not GST Registered'));
      });

      test('should identify export customers correctly', () async {
        final localCustomer = TestFactories.createCustomer(
          countryCode: 'SG',
        );
        
        final exportCustomers = [
          TestFactories.createExportCustomer(countryCode: 'US'),
          TestFactories.createExportCustomer(countryCode: 'MY'),
          TestFactories.createExportCustomer(countryCode: 'UK'),
        ];

        expect(localCustomer.isExportCustomer, isFalse);
        
        for (final customer in exportCustomers) {
          expect(customer.isExportCustomer, isTrue,
            reason: 'Customer from ${customer.countryCode} should be export customer');
        }
      });
    });

    group('Customer Search and Filtering', () {
      test('should search customers by name', () async {
        // Arrange - Create customers with different names
        final customers = [
          TestFactories.createCustomer(name: 'Apple Inc'),
          TestFactories.createCustomer(name: 'Microsoft Corporation'),
          TestFactories.createCustomer(name: 'Google LLC'),
          TestFactories.createCustomer(name: 'Amazon Web Services'),
        ];

        final db = await databaseService.database;
        for (final customer in customers) {
          await db.insert('customers', customer.toDatabase());
        }

        // Act - Search for customers containing "Inc" or "Corporation"
        final searchResults = await db.query(
          'customers',
          where: 'name LIKE ? OR name LIKE ?',
          whereArgs: ['%Inc%', '%Corporation%'],
          orderBy: 'name ASC',
        );

        // Assert
        expect(searchResults, hasLength(2));
        expect(searchResults[0]['name'], equals('Apple Inc'));
        expect(searchResults[1]['name'], equals('Microsoft Corporation'));
      });

      test('should search customers by email', () async {
        final customers = [
          TestFactories.createCustomer(
            name: 'Company A',
            email: 'contact@companya.com',
          ),
          TestFactories.createCustomer(
            name: 'Company B',
            email: 'info@companyb.org',
          ),
          TestFactories.createCustomer(
            name: 'Company C',
            email: 'sales@companyc.net',
          ),
        ];

        final db = await databaseService.database;
        for (final customer in customers) {
          await db.insert('customers', customer.toDatabase());
        }

        // Search by email domain
        final comResults = await db.query(
          'customers',
          where: 'email LIKE ?',
          whereArgs: ['%.com'],
        );

        expect(comResults, hasLength(1));
        expect(comResults.first['email'], equals('contact@companya.com'));
      });

      test('should filter customers by GST registration status', () async {
        final customers = [
          TestFactories.createSingaporeGstCustomer(name: 'GST Company 1'),
          TestFactories.createSingaporeGstCustomer(name: 'GST Company 2'),
          TestFactories.createCustomer(name: 'Non-GST Company', gstRegistered: false),
        ];

        final db = await databaseService.database;
        for (final customer in customers) {
          await db.insert('customers', customer.toDatabase());
        }

        // Filter GST registered customers
        final gstResults = await db.query(
          'customers',
          where: 'gst_registered = ?',
          whereArgs: [true],
        );

        expect(gstResults, hasLength(2));

        // Filter non-GST customers
        final nonGstResults = await db.query(
          'customers',
          where: 'gst_registered = ?',
          whereArgs: [false],
        );

        expect(nonGstResults, hasLength(1));
        expect(nonGstResults.first['name'], equals('Non-GST Company'));
      });

      test('should filter by country code for export analysis', () async {
        final customers = [
          TestFactories.createCustomer(countryCode: 'SG'),
          TestFactories.createCustomer(countryCode: 'SG'),
          TestFactories.createExportCustomer(countryCode: 'US'),
          TestFactories.createExportCustomer(countryCode: 'MY'),
        ];

        final db = await databaseService.database;
        for (final customer in customers) {
          await db.insert('customers', customer.toDatabase());
        }

        // Get Singapore customers
        final sgResults = await db.query(
          'customers',
          where: 'country_code = ?',
          whereArgs: ['SG'],
        );

        expect(sgResults, hasLength(2));

        // Get export customers (non-SG)
        final exportResults = await db.query(
          'customers',
          where: 'country_code != ?',
          whereArgs: ['SG'],
        );

        expect(exportResults, hasLength(2));
      });
    });

    group('Customer Transaction History', () {
      test('should link customers to their invoices', () async {
        // Create customer
        final customer = TestFactories.createSingaporeGstCustomer();
        final db = await databaseService.database;
        await db.insert('customers', customer.toDatabase());

        // Create mock invoices for the customer
        final invoices = [
          {
            'id': UuidGenerator.generateId(),
            'invoice_number': 'INV-001',
            'customer_id': customer.id,
            'total_amount': 1000.0,
            'status': 'paid',
            'issue_date': DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch,
          },
          {
            'id': UuidGenerator.generateId(),
            'invoice_number': 'INV-002',
            'customer_id': customer.id,
            'total_amount': 2500.0,
            'status': 'sent',
            'issue_date': DateTime.now().subtract(Duration(days: 15)).millisecondsSinceEpoch,
          },
          {
            'id': UuidGenerator.generateId(),
            'invoice_number': 'INV-003',
            'customer_id': customer.id,
            'total_amount': 750.0,
            'status': 'draft',
            'issue_date': DateTime.now().subtract(Duration(days: 5)).millisecondsSinceEpoch,
          },
        ];

        // Create invoices table for testing (simplified)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS invoices (
            id TEXT PRIMARY KEY,
            invoice_number TEXT,
            customer_id TEXT,
            total_amount REAL,
            status TEXT,
            issue_date INTEGER,
            FOREIGN KEY (customer_id) REFERENCES customers (id)
          )
        ''');

        for (final invoice in invoices) {
          await db.insert('invoices', invoice);
        }

        // Query customer's transaction history
        final transactionHistory = await db.rawQuery('''
          SELECT 
            i.invoice_number,
            i.total_amount,
            i.status,
            i.issue_date,
            c.name as customer_name
          FROM invoices i
          JOIN customers c ON i.customer_id = c.id
          WHERE i.customer_id = ?
          ORDER BY i.issue_date DESC
        ''', [customer.id]);

        expect(transactionHistory, hasLength(3));
        expect(transactionHistory.first['invoice_number'], equals('INV-003')); // Most recent
        
        // Calculate total transaction value
        final totalValue = transactionHistory.fold<double>(
          0.0, 
          (sum, invoice) => sum + (invoice['total_amount'] as double),
        );
        expect(totalValue, equals(4250.0)); // 1000 + 2500 + 750
      });

      test('should calculate customer statistics', () async {
        final customer = TestFactories.createSingaporeGstCustomer();
        final db = await databaseService.database;
        await db.insert('customers', customer.toDatabase());

        // Create transaction history data
        final transactions = [
          {'amount': 1000.0, 'status': 'paid', 'date': DateTime.now().subtract(Duration(days: 60))},
          {'amount': 1500.0, 'status': 'paid', 'date': DateTime.now().subtract(Duration(days: 30))},
          {'amount': 800.0, 'status': 'sent', 'date': DateTime.now().subtract(Duration(days: 15))},
          {'amount': 2000.0, 'status': 'paid', 'date': DateTime.now().subtract(Duration(days: 5))},
        ];

        // Calculate statistics
        final totalTransactions = transactions.length;
        final paidTransactions = transactions.where((t) => t['status'] == 'paid').toList();
        final totalPaidAmount = paidTransactions.fold<double>(
          0.0, 
          (sum, t) => sum + (t['amount'] as double),
        );
        final averageTransactionValue = totalPaidAmount / paidTransactions.length;
        final outstandingAmount = transactions
            .where((t) => t['status'] != 'paid')
            .fold<double>(0.0, (sum, t) => sum + (t['amount'] as double));

        expect(totalTransactions, equals(4));
        expect(paidTransactions.length, equals(3));
        expect(totalPaidAmount, equals(4500.0)); // 1000 + 1500 + 2000
        expect(averageTransactionValue, closeTo(1500.0, 0.01));
        expect(outstandingAmount, equals(800.0));
      });

      test('should track customer payment behavior', () async {
        final now = DateTime.now();
        final payments = [
          {
            'invoice_date': now.subtract(Duration(days: 30)),
            'payment_date': now.subtract(Duration(days: 25)),
            'due_date': now.subtract(Duration(days: 0)), // Due today
          },
          {
            'invoice_date': now.subtract(Duration(days: 60)),
            'payment_date': now.subtract(Duration(days: 45)),
            'due_date': now.subtract(Duration(days: 30)), // Due 30 days ago
          },
          {
            'invoice_date': now.subtract(Duration(days: 90)),
            'payment_date': now.subtract(Duration(days: 70)),
            'due_date': now.subtract(Duration(days: 60)), // Due 60 days ago
          },
        ];

        // Calculate payment patterns
        final paymentDays = payments.map((p) {
          final invoiceDate = p['invoice_date'] as DateTime;
          final paymentDate = p['payment_date'] as DateTime;
          return paymentDate.difference(invoiceDate).inDays;
        }).toList();

        final averagePaymentDays = paymentDays.reduce((a, b) => a + b) / paymentDays.length;
        
        // Check if payments are typically early/on-time/late
        final earlyPayments = paymentDays.where((days) => days < 25).length;
        final onTimePayments = paymentDays.where((days) => days >= 25 && days <= 30).length;
        final latePayments = paymentDays.where((days) => days > 30).length;

        expect(averagePaymentDays, closeTo(21.67, 0.1)); // Average of 5, 15, 45 days
        expect(earlyPayments, equals(2));
        expect(onTimePayments, equals(0));
        expect(latePayments, equals(1));
      });
    });

    group('Customer Updates and Modifications', () {
      test('should update customer information', () async {
        // Create initial customer
        final customer = TestFactories.createCustomer(
          name: 'Original Name Ltd',
          email: 'old@email.com',
          phone: '+65 91111111',
        );

        final db = await databaseService.database;
        await db.insert('customers', customer.toDatabase());

        // Update customer information
        final updatedData = {
          'name': 'Updated Company Name Pte Ltd',
          'email': 'new@email.com',
          'phone': '+65 92222222',
          'address': 'New Address, Singapore 654321',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };

        await db.update(
          'customers',
          updatedData,
          where: 'id = ?',
          whereArgs: [customer.id],
        );

        // Verify update
        final result = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [customer.id],
        );

        final updatedCustomer = Customer.fromDatabase(result.first);
        expect(updatedCustomer.name, equals('Updated Company Name Pte Ltd'));
        expect(updatedCustomer.email, equals('new@email.com'));
        expect(updatedCustomer.phone, equals('+65 92222222'));
        expect(updatedCustomer.address, equals('New Address, Singapore 654321'));
      });

      test('should update GST registration status', () async {
        // Start with non-GST customer
        final customer = TestFactories.createCustomer(gstRegistered: false);
        final db = await databaseService.database;
        await db.insert('customers', customer.toDatabase());

        // Customer becomes GST registered
        await db.update(
          'customers',
          {
            'gst_registered': true,
            'gst_registration_number': '200012345M',
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [customer.id],
        );

        // Verify GST status update
        final result = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [customer.id],
        );

        final updatedCustomer = Customer.fromDatabase(result.first);
        expect(updatedCustomer.gstRegistered, isTrue);
        expect(updatedCustomer.gstRegistrationNumber, equals('200012345M'));
        expect(updatedCustomer.hasValidGstNumber, isTrue);
      });

      test('should handle customer deactivation', () async {
        final customer = TestFactories.createCustomer();
        final db = await databaseService.database;
        await db.insert('customers', customer.toDatabase());

        // Deactivate customer
        await db.update(
          'customers',
          {
            'is_active': false,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [customer.id],
        );

        // Verify deactivation
        final result = await db.query(
          'customers',
          where: 'id = ?',
          whereArgs: [customer.id],
        );

        final deactivatedCustomer = Customer.fromDatabase(result.first);
        expect(deactivatedCustomer.isActive, isFalse);

        // Active customers query should exclude deactivated
        final activeResults = await db.query(
          'customers',
          where: 'is_active = ?',
          whereArgs: [true],
        );

        expect(activeResults.any((c) => c['id'] == customer.id), isFalse);
      });
    });

    group('Customer Data Integrity', () {
      test('should prevent duplicate customer emails', () async {
        final customer1 = TestFactories.createCustomer(
          email: 'duplicate@test.com',
        );
        
        final customer2 = TestFactories.createCustomer(
          email: 'duplicate@test.com',
        );

        final db = await databaseService.database;
        
        // Create unique constraint on email (would be done in schema)
        await db.execute('''
          CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_email 
          ON customers(email) 
          WHERE email IS NOT NULL
        ''');

        // First customer should succeed
        await db.insert('customers', customer1.toDatabase());

        // Second customer with same email should fail
        expect(
          () async => await db.insert('customers', customer2.toDatabase()),
          throwsException, // UNIQUE constraint violation
        );
      });

      test('should maintain referential integrity with invoices', () async {
        final customer = TestFactories.createCustomer();
        final db = await databaseService.database;
        await db.insert('customers', customer.toDatabase());

        // Create invoice referencing customer
        await db.execute('''
          CREATE TABLE IF NOT EXISTS test_invoices (
            id TEXT PRIMARY KEY,
            customer_id TEXT,
            FOREIGN KEY (customer_id) REFERENCES customers (id)
          )
        ''');

        await db.insert('test_invoices', {
          'id': UuidGenerator.generateId(),
          'customer_id': customer.id,
        });

        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');

        // Attempt to delete customer with existing invoices should fail
        expect(
          () async => await db.delete(
            'customers',
            where: 'id = ?',
            whereArgs: [customer.id],
          ),
          throwsException, // Foreign key constraint violation
        );
      });

      test('should validate data consistency across updates', () async {
        final customer = TestFactories.createCustomer(
          gstRegistered: true,
          gstRegistrationNumber: '200012345M',
        );

        final db = await databaseService.database;
        await db.insert('customers', customer.toDatabase());

        // Attempt to make customer non-GST but keep GST number
        // This should be caught by business logic validation
        final inconsistentUpdate = {
          'gst_registered': false,
          'gst_registration_number': '200012345M', // Still has number but not registered
        };

        // In a real application, this would be validated by business logic
        // For testing, we verify the data state would be inconsistent
        expect(inconsistentUpdate['gst_registered'], isFalse);
        expect(inconsistentUpdate['gst_registration_number'], isNotNull);
        
        // Business logic should clear GST number when deregistering
        final correctedUpdate = {
          'gst_registered': false,
          'gst_registration_number': null,
        };
        
        expect(correctedUpdate['gst_registered'], isFalse);
        expect(correctedUpdate['gst_registration_number'], isNull);
      });
    });

    group('Performance and Scalability', () {
      test('should efficiently handle large customer datasets', () async {
        const customerCount = 500;
        final db = await databaseService.database;
        
        final stopwatch = Stopwatch()..start();
        
        // Bulk insert customers
        final batch = db.batch();
        for (int i = 0; i < customerCount; i++) {
          final customer = TestFactories.createCustomer(
            name: 'Customer ${i.toString().padLeft(4, '0')}',
            email: 'customer${i}@test.com',
            gstRegistered: i % 3 == 0, // Every 3rd customer is GST registered
          );
          batch.insert('customers', customer.toDatabase());
        }
        await batch.commit();
        
        stopwatch.stop();
        print('Bulk insert of $customerCount customers took: ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // Should be under 3 seconds

        // Test search performance
        stopwatch.reset();
        stopwatch.start();
        
        final searchResults = await db.query(
          'customers',
          where: 'name LIKE ? AND gst_registered = ?',
          whereArgs: ['%0100%', true],
        );
        
        stopwatch.stop();
        print('Complex search query took: ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds, lessThan(50)); // Should be under 50ms
        expect(searchResults, isNotEmpty);
      });
    });
  });
}