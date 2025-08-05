import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart' as app_exceptions;
import 'platform_database_factory.dart';
import '../crdt/hybrid_logical_clock.dart';
import '../crdt/vector_clock.dart';
import 'transaction_manager.dart';
import 'crdt_models.dart';
import '../utils/uuid_generator.dart';

/// Enhanced database service with CRDT support and conflict resolution
class CRDTDatabaseService {
  static Database? _database;
  static final CRDTDatabaseService _instance = CRDTDatabaseService._internal();

  late HybridLogicalClock _clock;
  late TransactionManager _transactionManager;
  late String _nodeId;

  factory CRDTDatabaseService() => _instance;
  CRDTDatabaseService._internal();

  /// Initialize the database service
  Future<void> initialize([String? nodeId]) async {
    try {
      _nodeId = nodeId ?? await _generateNodeId();
      _clock = HybridLogicalClock(_nodeId);
      _database ??= await _initDatabase();
      _transactionManager = TransactionManager(_database!, _clock);

      // Verify tables exist
      await _verifyTablesExist();

      print('✅ CRDT Database initialized successfully with node ID: $_nodeId');
    } catch (e) {
      print('❌ Failed to initialize CRDT database: $e');
      throw app_exceptions.DatabaseException(
          'CRDT Database initialization failed: $e');
    }
  }

  Future<Database> get database async {
    if (_database == null) {
      await initialize();
    }
    return _database!;
  }

  HybridLogicalClock get clock => _clock;
  TransactionManager get transactionManager => _transactionManager;
  String get nodeId => _nodeId;

  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, AppConstants.databaseName);

      debugPrint('🔧 Initializing CRDT database at: $path');

      // Test connectivity first
      final isReachable = await PlatformDatabaseFactory.testDatabaseConnectivity(path + '.test');
      if (!isReachable) {
        debugPrint('⚠️ Database connectivity test failed, proceeding with caution');
      }

      // Use robust platform-aware database factory with automatic PRAGMA handling
      final database = await PlatformDatabaseFactory.openDatabase(
        path,
        version: AppConstants.databaseVersion,
        // Password ignored - encryption disabled for compatibility
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        // onOpen is handled by the PlatformDatabaseFactory with safe PRAGMA commands
      );

      debugPrint('✅ CRDT database initialized successfully');
      return database;
      
    } catch (e) {
      debugPrint('❌ CRDT database initialization failed: $e');
      
      // Enhanced error reporting with platform information
      final dbInfo = await PlatformDatabaseFactory.getDatabaseInfo();
      final errorDetails = '''
CRDT Database Initialization Failed:
- Error: $e
- Platform: ${dbInfo['platform']} (${dbInfo['is_mobile'] ? 'Mobile' : 'Desktop'})
- Database Factory: ${dbInfo['database_factory']}
- WAL Mode Supported: ${dbInfo['wal_mode_supported']}
- Initialization Status: ${dbInfo['initialization_status']}
- Encryption Status: ${dbInfo['encryption_status']}
      ''';
      
      debugPrint(errorDetails);
      
      throw app_exceptions.DatabaseException(
          'Failed to initialize CRDT database: $e\n$errorDetails');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create core business tables with CRDT support
    await _createCRDTBusinessTables(db);
    await _createUserTables(db);
    await _createSyncTables(db);
    await _createAuditTables(db);
    await _createDoubleEntryTables(db);
    await _createIntegrityTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _migrateToVersion(db, version);
    }
  }

  // _onOpen method removed - PRAGMA commands now handled by PlatformDatabaseFactory
  // This ensures cross-platform compatibility and proper error handling

  Future<void> _createCRDTBusinessTables(Database db) async {
    // Create both CRDT and legacy table formats for compatibility

    // Legacy customers table for backward compatibility
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        is_active BOOLEAN DEFAULT TRUE,
        gst_registered BOOLEAN DEFAULT FALSE,
        uen TEXT,
        gst_registration_number TEXT,
        country_code TEXT DEFAULT 'SG',
        billing_address TEXT,
        shipping_address TEXT
      )
    ''');

    // Customers CRDT table
    await db.execute('''
      CREATE TABLE customers_crdt (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version TEXT NOT NULL,
        is_deleted BOOLEAN DEFAULT FALSE,
        crdt_data TEXT NOT NULL,
        -- Indexed fields for queries
        name TEXT,
        email TEXT,
        phone TEXT,
        loyalty_points INTEGER DEFAULT 0,
        is_active BOOLEAN DEFAULT TRUE,
        gst_registered BOOLEAN DEFAULT FALSE,
        uen TEXT,
        gst_registration_number TEXT,
        country_code TEXT DEFAULT 'SG',
        billing_address TEXT,
        shipping_address TEXT,
        -- Constraints
        UNIQUE(id),
        CHECK(json_valid(crdt_data))
      )
    ''');

    // Invoices CRDT table
    await db.execute('''
      CREATE TABLE invoices_crdt (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version TEXT NOT NULL,
        is_deleted BOOLEAN DEFAULT FALSE,
        crdt_data TEXT NOT NULL,
        -- Indexed fields for queries
        invoice_number TEXT,
        customer_id TEXT,
        issue_date INTEGER,
        due_date INTEGER,
        status TEXT,
        total_amount REAL,
        remaining_balance_cents INTEGER,
        -- Constraints
        UNIQUE(id),
        UNIQUE(invoice_number),
        CHECK(json_valid(crdt_data)),
        CHECK(status IN ('draft', 'sent', 'paid', 'cancelled')),
        FOREIGN KEY (customer_id) REFERENCES customers_crdt (id) DEFERRABLE INITIALLY DEFERRED
      )
    ''');

    // Accounting Transactions CRDT table
    await db.execute('''
      CREATE TABLE transactions_crdt (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version TEXT NOT NULL,
        is_deleted BOOLEAN DEFAULT FALSE,
        crdt_data TEXT NOT NULL,
        -- Indexed fields for queries
        transaction_number TEXT,
        transaction_date INTEGER,
        description TEXT,
        status TEXT,
        total_debit REAL,
        total_credit REAL,
        is_balanced BOOLEAN,
        -- Constraints
        UNIQUE(id),
        UNIQUE(transaction_number),
        CHECK(json_valid(crdt_data)),
        CHECK(status IN ('draft', 'posted', 'reversed')),
        CHECK(ABS(total_debit - total_credit) < 0.01 OR status = 'draft')
      )
    ''');

    // Tax Rates CRDT table
    await db.execute('''
      CREATE TABLE tax_rates_crdt (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version TEXT NOT NULL,
        is_deleted BOOLEAN DEFAULT FALSE,
        crdt_data TEXT NOT NULL,
        -- Indexed fields for queries
        name TEXT,
        rate REAL,
        type TEXT,
        is_active BOOLEAN,
        effective_from INTEGER,
        effective_to INTEGER,
        -- Constraints
        UNIQUE(id),
        CHECK(json_valid(crdt_data)),
        CHECK(type IN ('percentage', 'fixed')),
        CHECK(rate >= 0)
      )
    ''');

    // Products CRDT table
    await db.execute('''
      CREATE TABLE products_crdt (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version TEXT NOT NULL,
        is_deleted BOOLEAN DEFAULT FALSE,
        crdt_data TEXT NOT NULL,
        -- Indexed fields for queries
        name TEXT,
        description TEXT,
        price REAL,
        cost REAL,
        stock_quantity INTEGER DEFAULT 0,
        min_stock_level INTEGER DEFAULT 5,
        lead_time_days INTEGER DEFAULT 7,
        category_id TEXT,
        category TEXT,
        barcode TEXT,
        -- Constraints
        UNIQUE(id),
        CHECK(json_valid(crdt_data)),
        CHECK(price >= 0),
        CHECK(cost >= 0 OR cost IS NULL),
        CHECK(stock_quantity >= 0)
      )
    ''');

    // Legacy products table for backward compatibility
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        cost REAL,
        stock_quantity INTEGER DEFAULT 0,
        min_stock_level INTEGER DEFAULT 5,
        lead_time_days INTEGER DEFAULT 7,
        category_id TEXT,
        category TEXT,
        barcode TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        -- Constraints
        CHECK(price >= 0),
        CHECK(cost >= 0 OR cost IS NULL),
        CHECK(stock_quantity >= 0)
      )
    ''');

    // Sync metadata table
    await db.execute('''
      CREATE TABLE sync_metadata (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        node_id TEXT NOT NULL,
        last_sync_vector TEXT NOT NULL,
        last_sync_timestamp TEXT NOT NULL,
        sync_status TEXT DEFAULT 'pending',
        conflict_resolution TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        -- Constraints
        UNIQUE(table_name, record_id, node_id),
        CHECK(sync_status IN ('pending', 'synced', 'conflict', 'failed')),
        CHECK(json_valid(last_sync_vector))
      )
    ''');

    // Create indexes for performance
    await _createCRDTIndexes(db);
  }

  Future<void> _createCRDTIndexes(Database db) async {
    // Customer indexes
    await db.execute(
        'CREATE INDEX idx_customers_name ON customers_crdt(name) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_customers_email ON customers_crdt(email) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_customers_updated ON customers_crdt(updated_at)');
    await db
        .execute('CREATE INDEX idx_customers_node ON customers_crdt(node_id)');
    await db.execute(
        'CREATE INDEX idx_customers_gst_registered ON customers_crdt(gst_registered) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_customers_country_code ON customers_crdt(country_code) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_customers_is_active ON customers_crdt(is_active) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_customers_uen ON customers_crdt(uen) WHERE is_deleted = FALSE AND uen IS NOT NULL');

    // Invoice indexes
    await db.execute(
        'CREATE INDEX idx_invoices_number ON invoices_crdt(invoice_number) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_invoices_customer ON invoices_crdt(customer_id) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_invoices_status ON invoices_crdt(status) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_invoices_issue_date ON invoices_crdt(issue_date) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_invoices_updated ON invoices_crdt(updated_at)');

    // Transaction indexes
    await db.execute(
        'CREATE INDEX idx_transactions_number ON transactions_crdt(transaction_number) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_transactions_date ON transactions_crdt(transaction_date) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_transactions_status ON transactions_crdt(status) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_transactions_updated ON transactions_crdt(updated_at)');

    // Tax rate indexes
    await db.execute(
        'CREATE INDEX idx_tax_rates_name ON tax_rates_crdt(name) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_tax_rates_active ON tax_rates_crdt(is_active) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_tax_rates_effective ON tax_rates_crdt(effective_from, effective_to) WHERE is_deleted = FALSE');

    // Product indexes
    await db.execute(
        'CREATE INDEX idx_products_name ON products_crdt(name) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_products_category ON products_crdt(category_id) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_products_barcode ON products_crdt(barcode) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_products_stock ON products_crdt(stock_quantity) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX idx_products_updated ON products_crdt(updated_at)');
    await db
        .execute('CREATE INDEX idx_products_node ON products_crdt(node_id)');

    // Legacy products table indexes
    await db.execute('CREATE INDEX idx_products_legacy_name ON products(name)');
    await db.execute(
        'CREATE INDEX idx_products_legacy_category ON products(category_id)');
    await db.execute(
        'CREATE INDEX idx_products_legacy_barcode ON products(barcode)');
    await db.execute(
        'CREATE INDEX idx_products_legacy_stock ON products(stock_quantity)');

    // Sync metadata indexes
    await db.execute(
        'CREATE INDEX idx_sync_metadata_table_record ON sync_metadata(table_name, record_id)');
    await db.execute(
        'CREATE INDEX idx_sync_metadata_status ON sync_metadata(sync_status)');
    await db.execute(
        'CREATE INDEX idx_sync_metadata_timestamp ON sync_metadata(last_sync_timestamp)');
  }

  Future<void> _createUserTables(Database db) async {
    // User settings table (unchanged)
    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        type TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Business profile table (unchanged)
    await db.execute('''
      CREATE TABLE business_profile (
        id TEXT PRIMARY KEY,
        business_name TEXT NOT NULL,
        owner_name TEXT,
        email TEXT,
        phone TEXT,
        address TEXT,
        tax_number TEXT,
        currency TEXT DEFAULT 'USD',
        timezone TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createSyncTables(Database db) async {
    // P2P sync log table
    await db.execute('''
      CREATE TABLE sync_log (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT,
        vector_clock TEXT,
        hlc_timestamp TEXT
      )
    ''');

    // Device registry table
    await db.execute('''
      CREATE TABLE device_registry (
        id TEXT PRIMARY KEY,
        device_name TEXT NOT NULL,
        device_type TEXT NOT NULL,
        last_seen INTEGER NOT NULL,
        is_trusted BOOLEAN DEFAULT FALSE,
        public_key TEXT,
        vector_clock TEXT
      )
    ''');

    // Conflict resolution log
    await db.execute('''
      CREATE TABLE conflict_resolution_log (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        conflict_type TEXT NOT NULL,
        local_version TEXT NOT NULL,
        remote_version TEXT NOT NULL,
        resolution_strategy TEXT NOT NULL,
        resolved_version TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        details TEXT
      )
    ''');
  }

  Future<void> _createAuditTables(Database db) async {
    // Audit trail table
    await db.execute('''
      CREATE TABLE audit_trail (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        old_values TEXT,
        new_values TEXT,
        user_id TEXT,
        node_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        hlc_timestamp TEXT NOT NULL,
        transaction_id TEXT,
        ip_address TEXT,
        user_agent TEXT,
        -- Constraints
        CHECK(operation IN ('INSERT', 'UPDATE', 'DELETE')),
        CHECK(json_valid(old_values) OR old_values IS NULL),
        CHECK(json_valid(new_values) OR new_values IS NULL)
      )
    ''');

    // Transaction log table
    await db.execute('''
      CREATE TABLE transaction_log (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        node_id TEXT NOT NULL,
        event TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        metadata TEXT,
        -- Constraints
        CHECK(json_valid(metadata) OR metadata IS NULL)
      )
    ''');

    // Operation log table
    await db.execute('''
      CREATE TABLE operation_log (
        id TEXT PRIMARY KEY,
        operation_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        event TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        error_message TEXT
      )
    ''');
  }

  Future<void> _createDoubleEntryTables(Database db) async {
    // Chart of accounts
    await db.execute('''
      CREATE TABLE chart_of_accounts (
        id TEXT PRIMARY KEY,
        account_code TEXT NOT NULL,
        account_name TEXT NOT NULL,
        account_type TEXT NOT NULL,
        parent_account_id TEXT,
        is_active BOOLEAN DEFAULT TRUE,
        balance_type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        -- Constraints
        UNIQUE(account_code),
        CHECK(account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
        CHECK(balance_type IN ('DEBIT', 'CREDIT')),
        FOREIGN KEY (parent_account_id) REFERENCES chart_of_accounts (id)
      )
    ''');

    // Journal entries
    await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        debit_amount REAL DEFAULT 0,
        credit_amount REAL DEFAULT 0,
        description TEXT,
        reference TEXT,
        created_at INTEGER NOT NULL,
        -- Constraints
        CHECK((debit_amount > 0 AND credit_amount = 0) OR (credit_amount > 0 AND debit_amount = 0)),
        FOREIGN KEY (transaction_id) REFERENCES transactions_crdt (id),
        FOREIGN KEY (account_id) REFERENCES chart_of_accounts (id)
      )
    ''');

    // Account balances (materialized view for performance)
    await db.execute('''
      CREATE TABLE account_balances (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        balance REAL NOT NULL,
        last_updated INTEGER NOT NULL,
        -- Constraints
        UNIQUE(account_id),
        FOREIGN KEY (account_id) REFERENCES chart_of_accounts (id)
      )
    ''');
  }

  Future<void> _createIntegrityTables(Database db) async {
    // Data integrity checks
    await db.execute('''
      CREATE TABLE integrity_checks (
        id TEXT PRIMARY KEY,
        check_name TEXT NOT NULL,
        check_type TEXT NOT NULL,
        table_name TEXT NOT NULL,
        description TEXT,
        check_sql TEXT NOT NULL,
        is_active BOOLEAN DEFAULT TRUE,
        created_at INTEGER NOT NULL,
        -- Constraints
        CHECK(check_type IN ('CONSTRAINT', 'BUSINESS_RULE', 'BALANCE', 'FOREIGN_KEY'))
      )
    ''');

    // Integrity violations log
    await db.execute('''
      CREATE TABLE integrity_violations (
        id TEXT PRIMARY KEY,
        check_id TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        violation_type TEXT NOT NULL,
        violation_details TEXT,
        resolved BOOLEAN DEFAULT FALSE,
        timestamp INTEGER NOT NULL,
        -- Constraints
        FOREIGN KEY (check_id) REFERENCES integrity_checks (id)
      )
    ''');
  }

  /// Insert or update a CRDT customer
  Future<void> upsertCustomer(CRDTCustomer customer) async {
    final db = await database;

    await _transactionManager.runInTransaction((transaction) async {
      // Check for existing customer
      final existing = await db.query(
        'customers_crdt',
        where: 'id = ?',
        whereArgs: [customer.id],
      );

      if (existing.isNotEmpty) {
        // Merge with existing
        final existingCustomer = CRDTCustomer.fromCRDTJson(
          jsonDecode(existing.first['crdt_data'] as String),
        );
        existingCustomer.mergeWith(customer);
        customer = existingCustomer;
      }

      // Upsert the customer
      await db.insert(
        'customers_crdt',
        {
          'id': customer.id,
          'node_id': customer.nodeId,
          'created_at': customer.createdAt.toString(),
          'updated_at': customer.updatedAt.toString(),
          'version': customer.version.toString(),
          'is_deleted': customer.isDeleted,
          'crdt_data': jsonEncode(customer.toCRDTJson()),
          'name': customer.name.value,
          'email': customer.email.value,
          'phone': customer.phone.value,
          'loyalty_points': customer.loyaltyPoints.value,
          // Add new fields with safe access
          'is_active': true, // Default for CRDT customers
          'gst_registered': false, // Default 
          'uen': null,
          'gst_registration_number': null,
          'country_code': 'SG', // Default
          'billing_address': null,
          'shipping_address': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Update sync metadata
      await _updateSyncMetadata('customers_crdt', customer.id, customer);

      // Log audit trail
      await _logAuditTrail(
        'customers_crdt',
        customer.id,
        existing.isEmpty ? 'INSERT' : 'UPDATE',
        existing.isEmpty ? null : existing.first,
        customer.toJson(),
      );
    });
  }

  /// Get customer by ID
  Future<CRDTCustomer?> getCustomer(String id) async {
    final db = await database;

    final result = await db.query(
      'customers_crdt',
      where: 'id = ? AND is_deleted = FALSE',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;

    return CRDTCustomer.fromCRDTJson(
      jsonDecode(result.first['crdt_data'] as String),
    );
  }

  /// Get all customers
  Future<List<CRDTCustomer>> getAllCustomers() async {
    final db = await database;

    final result = await db.query(
      'customers_crdt',
      where: 'is_deleted = FALSE',
      orderBy: 'name ASC',
    );

    return result
        .map((row) => CRDTCustomer.fromCRDTJson(
              jsonDecode(row['crdt_data'] as String),
            ))
        .toList();
  }

  /// Generic CRDT entity operations

  /// Insert or update any CRDT entity
  Future<void> upsertEntity(String tableName, dynamic entity) async {
    if (tableName == 'customers') {
      await upsertCustomer(entity as CRDTCustomer);
    } else if (tableName == 'invoices') {
      await upsertInvoice(entity);
    } else if (tableName == 'invoice_items') {
      await upsertInvoiceItem(entity);
    } else if (tableName == 'invoice_payments') {
      await upsertInvoicePayment(entity);
    } else if (tableName == 'invoice_workflow') {
      await upsertInvoiceWorkflow(entity);
    } else {
      throw Exception('Unsupported entity table: $tableName');
    }
  }

  /// Get any CRDT entity by ID
  Future<dynamic> getEntity(String tableName, String id) async {
    if (tableName == 'customers') {
      return await getCustomer(id);
    } else if (tableName == 'invoices') {
      return await getInvoice(id);
    } else if (tableName == 'invoice_items') {
      return await getInvoiceItem(id);
    } else if (tableName == 'invoice_payments') {
      return await getInvoicePayment(id);
    } else if (tableName == 'invoice_workflow') {
      return await getInvoiceWorkflow(id);
    } else {
      throw Exception('Unsupported entity table: $tableName');
    }
  }

  /// Query entities with filters
  Future<List<dynamic>> queryEntities(
      String tableName, Map<String, dynamic> filters) async {
    if (tableName == 'customers') {
      return await queryCustomers(filters);
    } else if (tableName == 'invoices') {
      return await queryInvoices(filters);
    } else if (tableName == 'invoice_items') {
      return await queryInvoiceItems(filters);
    } else if (tableName == 'invoice_payments') {
      return await queryInvoicePayments(filters);
    } else if (tableName == 'invoice_workflow') {
      return await queryInvoiceWorkflow(filters);
    } else {
      throw Exception('Unsupported entity table: $tableName');
    }
  }

  /// Delete entity (soft delete)
  Future<void> deleteEntity(String tableName, String id) async {
    if (tableName == 'customers') {
      await deleteCustomer(id);
    } else if (tableName == 'invoices') {
      await deleteInvoice(id);
    } else if (tableName == 'invoice_items') {
      await deleteInvoiceItem(id);
    } else if (tableName == 'invoice_payments') {
      await deleteInvoicePayment(id);
    } else if (tableName == 'invoice_workflow') {
      await deleteInvoiceWorkflow(id);
    } else {
      throw Exception('Unsupported entity table: $tableName');
    }
  }

  /// Invoice operations
  Future<void> upsertInvoice(dynamic invoice) async {
    final db = await database;

    await _transactionManager.runInTransaction((transaction) async {
      await db.insert(
        'invoices_crdt',
        {
          'id': invoice.id,
          'node_id': invoice.nodeId,
          'created_at': invoice.createdAt.toString(),
          'updated_at': invoice.updatedAt.toString(),
          'version': invoice.version.toString(),
          'is_deleted': invoice.isDeleted,
          'crdt_data': jsonEncode(invoice.toCRDTJson()),
          'invoice_number': invoice.invoiceNumber?.value,
          'customer_id': invoice.customerId?.value,
          'status': invoice.status?.value?.value,
          'total_amount': invoice.totalAmount?.value,
          'remaining_balance_cents': (invoice.remainingBalance * 100).round(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<dynamic> getInvoice(String id) async {
    final db = await database;

    final result = await db.query(
      'invoices_crdt',
      where: 'id = ? AND is_deleted = FALSE',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;

    // Return the raw data for now - would need proper deserialization
    return result.first;
  }

  Future<List<dynamic>> queryInvoices(Map<String, dynamic> filters) async {
    final db = await database;

    String whereClause = 'is_deleted = FALSE';
    List<dynamic> whereArgs = [];

    // Build where clause from filters
    if (filters.containsKey('customer_id')) {
      whereClause += ' AND customer_id = ?';
      whereArgs.add(filters['customer_id']);
    }

    if (filters.containsKey('status_in')) {
      final statuses = filters['status_in'] as List;
      final placeholders = statuses.map((_) => '?').join(',');
      whereClause += ' AND status IN ($placeholders)';
      whereArgs.addAll(statuses);
    }

    final result = await db.query(
      'invoices_crdt',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'updated_at DESC',
    );

    return result;
  }

  Future<void> deleteInvoice(String id) async {
    final db = await database;

    await db.update(
      'invoices_crdt',
      {'is_deleted': true, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Invoice item operations
  Future<void> upsertInvoiceItem(dynamic item) async {
    // Placeholder - would implement similar to invoice
  }

  Future<dynamic> getInvoiceItem(String id) async {
    // Placeholder
    return null;
  }

  Future<List<dynamic>> queryInvoiceItems(Map<String, dynamic> filters) async {
    // Placeholder
    return [];
  }

  Future<void> deleteInvoiceItem(String id) async {
    // Placeholder
  }

  /// Invoice payment operations
  Future<void> upsertInvoicePayment(dynamic payment) async {
    // Placeholder
  }

  Future<dynamic> getInvoicePayment(String id) async {
    // Placeholder
    return null;
  }

  Future<List<dynamic>> queryInvoicePayments(
      Map<String, dynamic> filters) async {
    // Placeholder
    return [];
  }

  Future<void> deleteInvoicePayment(String id) async {
    // Placeholder
  }

  /// Invoice workflow operations
  Future<void> upsertInvoiceWorkflow(dynamic workflow) async {
    // Placeholder
  }

  Future<dynamic> getInvoiceWorkflow(String id) async {
    // Placeholder
    return null;
  }

  Future<List<dynamic>> queryInvoiceWorkflow(
      Map<String, dynamic> filters) async {
    // Placeholder
    return [];
  }

  Future<void> deleteInvoiceWorkflow(String id) async {
    // Placeholder
  }

  /// Customer query operations
  Future<List<CRDTCustomer>> queryCustomers(
      Map<String, dynamic> filters) async {
    final db = await database;

    String whereClause = 'is_deleted = FALSE';
    List<dynamic> whereArgs = [];

    // Build where clause from filters
    if (filters.containsKey('search_text')) {
      whereClause += ' AND (name LIKE ? OR email LIKE ?)';
      final searchTerm = '%${filters['search_text']}%';
      whereArgs.addAll([searchTerm, searchTerm]);
    }

    final result = await db.query(
      'customers_crdt',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    return result
        .map((row) => CRDTCustomer.fromCRDTJson(
              jsonDecode(row['crdt_data'] as String),
            ))
        .toList();
  }

  /// Delete customer (soft delete)
  Future<void> deleteCustomer(String id) async {
    final db = await database;

    await db.update(
      'customers_crdt',
      {'is_deleted': true, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update sync metadata
  Future<void> _updateSyncMetadata(
      String tableName, String recordId, CRDTModel model) async {
    final db = await database;

    await db.insert(
      'sync_metadata',
      {
        'id': UuidGenerator.generateId(),
        'table_name': tableName,
        'record_id': recordId,
        'node_id': model.nodeId,
        'last_sync_vector': model.version.toString(),
        'last_sync_timestamp': model.updatedAt.toString(),
        'sync_status': 'pending',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Log audit trail
  Future<void> _logAuditTrail(
    String tableName,
    String recordId,
    String operation,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic> newValues,
  ) async {
    final db = await database;

    try {
      await db.insert('audit_trail', {
        'id': UuidGenerator.generateId(),
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation,
        'old_values': oldValues != null ? jsonEncode(oldValues) : null,
        'new_values': jsonEncode(newValues),
        'node_id': _nodeId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'hlc_timestamp': _clock.current.toString(),
      });
    } catch (e) {
      // Don't fail the main operation due to audit logging issues
      print('Failed to log audit trail: $e');
    }
  }

  /// Run integrity checks
  Future<List<Map<String, dynamic>>> runIntegrityChecks() async {
    final db = await database;
    final violations = <Map<String, dynamic>>[];

    // Check foreign key constraints
    final fkViolations = await db.rawQuery('PRAGMA foreign_key_check');
    violations.addAll(fkViolations);

    // Check double-entry bookkeeping balance
    final balanceCheck = await db.rawQuery('''
      SELECT transaction_id, SUM(debit_amount) as total_debit, SUM(credit_amount) as total_credit
      FROM journal_entries 
      GROUP BY transaction_id 
      HAVING ABS(total_debit - total_credit) > 0.01
    ''');
    violations.addAll(balanceCheck);

    // Custom integrity checks
    final customChecks = await db.query(
      'integrity_checks',
      where: 'is_active = TRUE',
    );

    for (final check in customChecks) {
      try {
        final results = await db.rawQuery(check['check_sql'] as String);
        if (results.isNotEmpty) {
          violations.addAll(results.map((r) => {
                ...r,
                'check_name': check['check_name'],
                'check_type': check['check_type'],
              }));
        }
      } catch (e) {
        print('Failed to run integrity check ${check['check_name']}: $e');
      }
    }

    return violations;
  }

  Future<String> _generateNodeId() async {
    // Generate a unique node ID based on device characteristics
    return '${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _migrateToVersion(Database db, int version) async {
    print('🔄 CRDT Database: Migrating to version $version...');
    
    // Handle specific version migrations
    switch (version) {
      case 2:
        await _migrateToVersion2(db);
        break;
    }
    
    print('✅ CRDT Migration to version $version completed');
  }

  Future<void> _migrateToVersion2(Database db) async {
    print('🔄 CRDT: Adding missing columns to customers tables...');
    
    try {
      // Add missing columns to legacy customers table
      await db.execute('ALTER TABLE customers ADD COLUMN is_active BOOLEAN DEFAULT TRUE');
      await db.execute('ALTER TABLE customers ADD COLUMN gst_registered BOOLEAN DEFAULT FALSE');
      await db.execute('ALTER TABLE customers ADD COLUMN uen TEXT');
      await db.execute('ALTER TABLE customers ADD COLUMN gst_registration_number TEXT');
      await db.execute('ALTER TABLE customers ADD COLUMN country_code TEXT DEFAULT \'SG\'');
      await db.execute('ALTER TABLE customers ADD COLUMN billing_address TEXT');
      await db.execute('ALTER TABLE customers ADD COLUMN shipping_address TEXT');
      
      print('✅ CRDT: Added missing columns to legacy customers table');
    } catch (e) {
      print('⚠️  CRDT: Error adding columns to legacy customers (may already exist): $e');
    }
    
    try {
      // Add missing columns to CRDT customers table
      await db.execute('ALTER TABLE customers_crdt ADD COLUMN is_active BOOLEAN DEFAULT TRUE');
      await db.execute('ALTER TABLE customers_crdt ADD COLUMN gst_registered BOOLEAN DEFAULT FALSE');
      await db.execute('ALTER TABLE customers_crdt ADD COLUMN uen TEXT');
      await db.execute('ALTER TABLE customers_crdt ADD COLUMN gst_registration_number TEXT');
      await db.execute('ALTER TABLE customers_crdt ADD COLUMN country_code TEXT DEFAULT \'SG\'');
      await db.execute('ALTER TABLE customers_crdt ADD COLUMN billing_address TEXT');
      await db.execute('ALTER TABLE customers_crdt ADD COLUMN shipping_address TEXT');
      
      print('✅ CRDT: Added missing columns to CRDT customers table');
    } catch (e) {
      print('⚠️  CRDT: Error adding columns to CRDT customers (may already exist): $e');
    }
    
    // Create indexes for the new columns
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_gst_registered ON customers_crdt(gst_registered) WHERE is_deleted = FALSE');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_country_code ON customers_crdt(country_code) WHERE is_deleted = FALSE');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_is_active ON customers_crdt(is_active) WHERE is_deleted = FALSE');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_uen ON customers_crdt(uen) WHERE is_deleted = FALSE AND uen IS NOT NULL');
      
      print('✅ CRDT: Created indexes for new customer columns');
    } catch (e) {
      print('⚠️  CRDT: Error creating indexes: $e');
    }
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Verify that required tables exist, create them if missing
  Future<void> _verifyTablesExist() async {
    final db = await database;

    // Check if required tables exist
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('customers', 'customers_crdt', 'products', 'products_crdt')");

    final existingTables = tables.map((row) => row['name'] as String).toSet();

    if (!existingTables.contains('customers')) {
      print('⚠️  Creating missing customers table');
      await _createMissingCustomersTable(db);
    }

    if (!existingTables.contains('customers_crdt')) {
      print('⚠️  Creating missing customers_crdt table');
      await _createMissingCRDTCustomersTable(db);
    }

    if (!existingTables.contains('products')) {
      print('⚠️  Creating missing products table');
      await _createMissingProductsTable(db);
    }

    if (!existingTables.contains('products_crdt')) {
      print('⚠️  Creating missing products_crdt table');
      await _createMissingCRDTProductsTable(db);
    }

    print('✅ All required tables verified/created');
  }

  /// Create missing customers table
  Future<void> _createMissingCustomersTable(Database db) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        is_active BOOLEAN DEFAULT TRUE,
        gst_registered BOOLEAN DEFAULT FALSE,
        uen TEXT,
        gst_registration_number TEXT,
        country_code TEXT DEFAULT 'SG',
        billing_address TEXT,
        shipping_address TEXT
      )
    ''');
  }

  /// Create missing CRDT customers table
  Future<void> _createMissingCRDTCustomersTable(Database db) async {
    await db.execute('''
      CREATE TABLE customers_crdt (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version TEXT NOT NULL,
        is_deleted BOOLEAN DEFAULT FALSE,
        crdt_data TEXT NOT NULL,
        -- Indexed fields for queries
        name TEXT,
        email TEXT,
        phone TEXT,
        loyalty_points INTEGER DEFAULT 0,
        is_active BOOLEAN DEFAULT TRUE,
        gst_registered BOOLEAN DEFAULT FALSE,
        uen TEXT,
        gst_registration_number TEXT,
        country_code TEXT DEFAULT 'SG',
        billing_address TEXT,
        shipping_address TEXT,
        -- Constraints
        UNIQUE(id),
        CHECK(json_valid(crdt_data))
      )
    ''');

    // Create indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers_crdt(name) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_email ON customers_crdt(email) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_updated ON customers_crdt(updated_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_node ON customers_crdt(node_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_gst_registered ON customers_crdt(gst_registered) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_country_code ON customers_crdt(country_code) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_is_active ON customers_crdt(is_active) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_uen ON customers_crdt(uen) WHERE is_deleted = FALSE AND uen IS NOT NULL');
  }

  /// Create missing products table
  Future<void> _createMissingProductsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        cost REAL,
        stock_quantity INTEGER DEFAULT 0,
        min_stock_level INTEGER DEFAULT 5,
        lead_time_days INTEGER DEFAULT 7,
        category_id TEXT,
        category TEXT,
        barcode TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        -- Constraints
        CHECK(price >= 0),
        CHECK(cost >= 0 OR cost IS NULL),
        CHECK(stock_quantity >= 0)
      )
    ''');

    // Create indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_legacy_name ON products(name)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_legacy_category ON products(category_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_legacy_barcode ON products(barcode)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_legacy_stock ON products(stock_quantity)');
  }

  /// Create missing CRDT products table
  Future<void> _createMissingCRDTProductsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products_crdt (
        id TEXT PRIMARY KEY,
        node_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        version TEXT NOT NULL,
        is_deleted BOOLEAN DEFAULT FALSE,
        crdt_data TEXT NOT NULL,
        -- Indexed fields for queries
        name TEXT,
        description TEXT,
        price REAL,
        cost REAL,
        stock_quantity INTEGER DEFAULT 0,
        min_stock_level INTEGER DEFAULT 5,
        lead_time_days INTEGER DEFAULT 7,
        category_id TEXT,
        category TEXT,
        barcode TEXT,
        -- Constraints
        UNIQUE(id),
        CHECK(json_valid(crdt_data)),
        CHECK(price >= 0),
        CHECK(cost >= 0 OR cost IS NULL),
        CHECK(stock_quantity >= 0)
      )
    ''');

    // Create indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_name ON products_crdt(name) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_category ON products_crdt(category_id) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products_crdt(barcode) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_stock ON products_crdt(stock_quantity) WHERE is_deleted = FALSE');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_updated ON products_crdt(updated_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_node ON products_crdt(node_id)');
  }

  /// Force creation of all required tables
  Future<void> forceCreateTables() async {
    final db = await database;
    print('🔧 Force creating all required database tables...');

    try {
      await _createCRDTBusinessTables(db);
      await _createUserTables(db);
      await _createSyncTables(db);
      await _createAuditTables(db);
      await _createDoubleEntryTables(db);
      await _createIntegrityTables(db);

      // Force create products tables if missing
      await _createMissingProductsTable(db);
      await _createMissingCRDTProductsTable(db);

      print('✅ All tables force-created successfully');
    } catch (e) {
      print('❌ Error force-creating tables: $e');
      throw e;
    }
  }

  Future<void> deleteDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, AppConstants.databaseName);

    if (await File(path).exists()) {
      await File(path).delete();
    }

    if (_database != null) {
      _database = null;
    }
  }
}
