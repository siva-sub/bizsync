import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'crdt_database_service.dart';
import 'crdt_models.dart';
import '../crdt/crdt_types.dart';
import '../crdt/hybrid_logical_clock.dart';
import '../crdt/vector_clock.dart';
import '../utils/uuid_generator.dart';
import '../config/feature_flags.dart';

/// Service for seeding the database with initial demo data
class DatabaseSeedingService {
  final CRDTDatabaseService _databaseService;
  
  DatabaseSeedingService(this._databaseService);
  
  /// Check if database has been seeded
  Future<bool> isDatabaseSeeded() async {
    try {
      final customers = await _databaseService.getAllCustomers();
      return customers.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Seed the database with initial data
  Future<void> seedDatabase() async {
    // Check if demo data is enabled via feature flag
    if (!FeatureFlags().isDemoDataEnabled) {
      if (kDebugMode) {
        print('Demo data is disabled via feature flag, skipping database seeding...');
      }
      return;
    }
    
    if (await isDatabaseSeeded()) {
      if (kDebugMode) {
        print('Database already seeded, skipping...');
      }
      return;
    }
    
    if (kDebugMode) {
      print('Seeding database with initial data...');
    }
    
    try {
      await _seedBusinessProfile();
      await _seedCustomers();
      await _seedTaxRates();
      await _seedEmployees();
      await _seedSampleInvoices();
      
      if (kDebugMode) {
        print('Database seeding completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Database seeding failed: $e');
      }
    }
  }
  
  /// Seed business profile
  Future<void> _seedBusinessProfile() async {
    final db = await _databaseService.database;
    
    await db.insert('business_profile', {
      'id': UuidGenerator.generateId(),
      'business_name': 'BizSync Solutions Pte Ltd',
      'owner_name': 'John Tan',
      'email': 'admin@bizsync.com.sg',
      'phone': '+65 6123 4567',
      'address': '123 Business Hub\nSingapore 123456',
      'tax_number': '202012345A',
      'currency': 'SGD',
      'timezone': 'Asia/Singapore',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Seed sample customers
  Future<void> _seedCustomers() async {
    final customers = [
      {
        'name': 'Acme Corporation Pte Ltd',
        'email': 'billing@acme.com.sg',
        'phone': '+65 6123 4567',
        'address': '123 Business Street\\nSingapore 123456',
        'uen': '200123456A',
      },
      {
        'name': 'Tech Solutions Pte Ltd',
        'email': 'accounts@techsolutions.sg',
        'phone': '+65 6789 0123',
        'address': '456 Innovation Drive\\nSingapore 654321',
        'uen': '201987654B',
      },
      {
        'name': 'Global Trading Co',
        'email': 'finance@globaltrading.com',
        'phone': '+65 6555 1234',
        'address': '789 Commerce Avenue\\nSingapore 987654',
        'uen': null,
      },
      {
        'name': 'Singapore Manufacturing Ltd',
        'email': 'procurement@sgmanufacturing.com.sg',
        'phone': '+65 6777 8888',
        'address': '321 Industrial Road\\nSingapore 456789',
        'uen': '199876543C',
      },
      {
        'name': 'Digital Services Hub',
        'email': 'admin@digitalhub.sg',
        'phone': '+65 6999 0000',
        'address': '654 Digital Way\\nSingapore 321654',
        'uen': '202112345D',
      },
    ];
    
    for (final customerData in customers) {
      final timestamp = HLCTimestamp.now(_databaseService.nodeId);
      final vectorClock = VectorClock(_databaseService.nodeId);
      
      final customer = CRDTCustomer(
        id: UuidGenerator.generateId(),
        nodeId: _databaseService.nodeId,
        createdAt: timestamp,
        updatedAt: timestamp,
        version: vectorClock,
        name: CRDTRegister(customerData['name'] as String, timestamp),
        email: CRDTRegister(customerData['email'] as String, timestamp),
        phone: CRDTRegister(customerData['phone'] as String, timestamp),
        address: CRDTRegister(customerData['address'] as String, timestamp),
        loyaltyPoints: CRDTCounter(0),
        isDeleted: false,
      );
      
      await _databaseService.upsertCustomer(customer);
    }
  }
  
  /// Seed tax rates
  Future<void> _seedTaxRates() async {
    final taxRates = [
      {
        'name': 'GST (Goods & Services Tax)',
        'rate': 8.0,
        'type': 'percentage',
        'is_active': true,
        'effective_from': DateTime(2023, 1, 1).millisecondsSinceEpoch,
        'effective_to': null,
      },
      {
        'name': 'GST (Previous Rate)',
        'rate': 7.0,
        'type': 'percentage',
        'is_active': false,
        'effective_from': DateTime(2020, 1, 1).millisecondsSinceEpoch,
        'effective_to': DateTime(2022, 12, 31).millisecondsSinceEpoch,
      },
      {
        'name': 'Zero Rated',
        'rate': 0.0,
        'type': 'percentage',
        'is_active': true,
        'effective_from': DateTime(2020, 1, 1).millisecondsSinceEpoch,
        'effective_to': null,
      },
    ];
    
    final db = await _databaseService.database;
    
    for (final taxRateData in taxRates) {
      final timestamp = HLCTimestamp.now(_databaseService.nodeId);
      final vectorClock = VectorClock(_databaseService.nodeId);
      
      await db.insert('tax_rates_crdt', {
        'id': UuidGenerator.generateId(),
        'node_id': _databaseService.nodeId,
        'created_at': timestamp.toString(),
        'updated_at': timestamp.toString(),
        'version': vectorClock.toString(),
        'is_deleted': false,
        'crdt_data': jsonEncode({
          'name': {'value': taxRateData['name'], 'timestamp': timestamp.toString()},
          'rate': {'value': taxRateData['rate'], 'timestamp': timestamp.toString()},
          'type': {'value': taxRateData['type'], 'timestamp': timestamp.toString()},
          'is_active': {'value': taxRateData['is_active'], 'timestamp': timestamp.toString()},
        }),
        'name': taxRateData['name'],
        'rate': taxRateData['rate'],
        'type': taxRateData['type'],
        'is_active': taxRateData['is_active'],
        'effective_from': taxRateData['effective_from'],
        'effective_to': taxRateData['effective_to'],
      });
    }
  }
  
  /// Seed employees (placeholder)
  Future<void> _seedEmployees() async {
    final employees = [
      {
        'name': 'John Tan',
        'email': 'john.tan@bizsync.com.sg',
        'phone': '+65 9123 4567',
        'position': 'Business Owner',
        'department': 'Management',
        'salary': 8000.00,
      },
      {
        'name': 'Sarah Lim',
        'email': 'sarah.lim@bizsync.com.sg',
        'phone': '+65 9234 5678',
        'position': 'Accounts Manager',
        'department': 'Finance',
        'salary': 5500.00,
      },
      {
        'name': 'Michael Wong',
        'email': 'michael.wong@bizsync.com.sg',
        'phone': '+65 9345 6789',
        'position': 'Sales Executive',
        'department': 'Sales',
        'salary': 4200.00,
      },
    ];
    
    // Note: This would require an employees table to be created first
    // For now, we'll just log the employee data
    if (kDebugMode) {
      print('Employee data prepared: ${employees.length} employees');
    }
  }
  
  /// Seed some sample invoices
  Future<void> _seedSampleInvoices() async {
    try {
      final customers = await _databaseService.getAllCustomers();
      if (customers.isEmpty) return;
      
      final now = DateTime.now();
      final invoices = [
        {
          'customer': customers[0],
          'invoice_number': 'INV-2024-001',
          'issue_date': now.subtract(const Duration(days: 30)),
          'due_date': now.subtract(const Duration(days: 0)), // Due today
          'status': 'sent',
          'items': [
            {'description': 'Web Development Services', 'quantity': 1, 'unit_price': 5000.00},
            {'description': 'Monthly Hosting', 'quantity': 12, 'unit_price': 50.00},
          ],
        },
        {
          'customer': customers[1],
          'invoice_number': 'INV-2024-002',
          'issue_date': now.subtract(const Duration(days: 15)),
          'due_date': now.add(const Duration(days: 15)), // Due in 15 days
          'status': 'sent',
          'items': [
            {'description': 'Software Consultation', 'quantity': 8, 'unit_price': 200.00},
            {'description': 'System Integration', 'quantity': 1, 'unit_price': 3000.00},
          ],
        },
        {
          'customer': customers[2],
          'invoice_number': 'INV-2024-003',
          'issue_date': now.subtract(const Duration(days: 5)),
          'due_date': now.add(const Duration(days: 25)), // Due in 25 days
          'status': 'draft',
          'items': [
            {'description': 'Data Analysis Services', 'quantity': 1, 'unit_price': 2500.00},
          ],
        },
      ];
      
      for (final invoiceData in invoices) {
        await _createSampleInvoice(invoiceData);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to seed sample invoices: $e');
      }
    }
  }
  
  /// Create a sample invoice
  Future<void> _createSampleInvoice(Map<String, dynamic> invoiceData) async {
    final db = await _databaseService.database;
    final customer = invoiceData['customer'] as CRDTCustomer;
    final items = invoiceData['items'] as List<Map<String, dynamic>>;
    
    // Calculate totals
    double subtotal = 0.0;
    for (final item in items) {
      subtotal += (item['quantity'] as int) * (item['unit_price'] as double);
    }
    
    final gstRate = 0.09; // 9% GST
    final gstAmount = subtotal * gstRate;
    final total = subtotal + gstAmount;
    
    final timestamp = HLCTimestamp.now(_databaseService.nodeId);
    final vectorClock = VectorClock(_databaseService.nodeId);
    
    // Create invoice
    final invoiceId = UuidGenerator.generateId();
    await db.insert('invoices_crdt', {
      'id': invoiceId,
      'node_id': _databaseService.nodeId,
      'created_at': timestamp.toString(),
      'updated_at': timestamp.toString(),
      'version': vectorClock.toString(),
      'is_deleted': false,
      'crdt_data': jsonEncode({
        'invoice_number': {'value': invoiceData['invoice_number'], 'timestamp': timestamp.toString()},
        'customer_id': {'value': customer.id, 'timestamp': timestamp.toString()},
        'issue_date': {'value': (invoiceData['issue_date'] as DateTime).millisecondsSinceEpoch, 'timestamp': timestamp.toString()},
        'due_date': {'value': (invoiceData['due_date'] as DateTime).millisecondsSinceEpoch, 'timestamp': timestamp.toString()},
        'status': {'value': invoiceData['status'], 'timestamp': timestamp.toString()},
        'currency': {'value': 'SGD', 'timestamp': timestamp.toString()},
        'subtotal': {'value': subtotal, 'timestamp': timestamp.toString()},
        'tax_amount': {'value': gstAmount, 'timestamp': timestamp.toString()},
        'total_amount': {'value': total, 'timestamp': timestamp.toString()},
      }),
      'invoice_number': invoiceData['invoice_number'],
      'customer_id': customer.id,
      'issue_date': (invoiceData['issue_date'] as DateTime).millisecondsSinceEpoch,
      'due_date': (invoiceData['due_date'] as DateTime).millisecondsSinceEpoch,
      'status': invoiceData['status'],
      'total_amount': total,
      'remaining_balance_cents': (total * 100).round(),
    });
    
    if (kDebugMode) {
      print('Created sample invoice: ${invoiceData['invoice_number']}');
    }
  }
  
  /// Clear all seeded data (for testing)
  Future<void> clearAllData() async {
    try {
      final db = await _databaseService.database;
      
      await db.delete('customers_crdt');
      await db.delete('invoices_crdt');
      await db.delete('tax_rates_crdt');
      await db.delete('business_profile');
      
      if (kDebugMode) {
        print('All seeded data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clear seeded data: $e');
      }
    }
  }
}