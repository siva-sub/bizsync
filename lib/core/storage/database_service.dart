import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart' as app_exceptions;
import '../database/platform_database_factory.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();
  
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  
  Future<Database> get database async {
    if (_database == null) {
      _database = await _initDatabase();
      await _verifyTablesExist();
    }
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, AppConstants.databaseName);
      
      // Use platform-aware database factory
      return await PlatformDatabaseFactory.openDatabase(
        path,
        version: AppConstants.databaseVersion,
        password: AppConstants.encryptionKey,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );
    } catch (e) {
      // Get database info for better error reporting
      final dbInfo = await PlatformDatabaseFactory.getDatabaseInfo();
      throw app_exceptions.DatabaseException(
        'Failed to initialize database: $e\n'
        'Platform: ${dbInfo['platform']}\n'
        'Database type: ${dbInfo['database_type']}\n'
        'Encryption: ${dbInfo['encryption_available'] ? "enabled" : "disabled"}'
      );
    }
  }
  
  Future<void> _onCreate(Database db, int version) async {
    try {
      print('🔧 Creating database tables (version $version)...');
      
      // Create core business tables
      await _createBusinessTables(db);
      await _createUserTables(db);
      await _createSyncTables(db);
      
      print('✅ Database tables created successfully');
    } catch (e) {
      print('❌ Failed to create database tables: $e');
      rethrow;
    }
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _migrateToVersion(db, version);
    }
  }
  
  Future<void> _onOpen(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }
  
  Future<void> _createBusinessTables(Database db) async {
    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0
      )
    ''');
    
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        cost REAL,
        stock_quantity INTEGER DEFAULT 0,
        category_id TEXT,
        barcode TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0
      )
    ''');
    
    // Invoices table
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT NOT NULL,
        customer_email TEXT,
        customer_address TEXT,
        issue_date INTEGER NOT NULL,
        due_date INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        subtotal REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        currency TEXT DEFAULT 'SGD',
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        UNIQUE(invoice_number),
        CHECK(status IN ('draft', 'pending', 'approved', 'sent', 'viewed', 'partially_paid', 'paid', 'overdue', 'cancelled', 'disputed', 'voided', 'refunded')),
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');
    
    // Invoice items table
    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT,
        description TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        total_amount REAL NOT NULL,
        created_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
    
    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        color TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0
      )
    ''');
    
    // Vendors table
    await db.execute('''
      CREATE TABLE vendors (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        tax_number TEXT,
        payment_terms TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0
      )
    ''');
    
    // Employees table
    await db.execute('''
      CREATE TABLE employees (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        position TEXT NOT NULL,
        department TEXT,
        hire_date INTEGER NOT NULL,
        salary REAL,
        is_active BOOLEAN DEFAULT TRUE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0
      )
    ''');
    
    // Sales transactions table
    await db.execute('''
      CREATE TABLE sales_transactions (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        total_amount REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        payment_method TEXT,
        notes TEXT,
        transaction_date INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');
    
    // Sales items table
    await db.execute('''
      CREATE TABLE sales_items (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        total_amount REAL NOT NULL,
        created_at INTEGER NOT NULL,
        sync_status INTEGER DEFAULT 0,
        FOREIGN KEY (transaction_id) REFERENCES sales_transactions (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
    
    // Inventory adjustments table
    await db.execute('''
      CREATE TABLE inventory_adjustments (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        adjustment_type TEXT NOT NULL,
        quantity_change INTEGER NOT NULL,
        reason TEXT,
        created_at INTEGER NOT NULL,
        created_by TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
  }
  
  Future<void> _createUserTables(Database db) async {
    // User settings table
    await db.execute('''
      CREATE TABLE user_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        type TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    
    // Business profile table
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
        error_message TEXT
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
        public_key TEXT
      )
    ''');
  }
  
  Future<void> _migrateToVersion(Database db, int version) async {
    // Handle specific version migrations
    switch (version) {
      case 2:
        // Future migration example
        // await db.execute('ALTER TABLE customers ADD COLUMN loyalty_points INTEGER DEFAULT 0');
        break;
      // Add more migration cases as needed
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
    if (_database == null) return;
    
    try {
      // Check if customers table exists
      final tables = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='customers'"
      );
      
      if (tables.isEmpty) {
        print('⚠️  Customers table missing, creating it...');
        await _createBusinessTables(_database!);
        print('✅ Missing tables created');
      } else {
        print('✅ Required tables verified');
      }
    } catch (e) {
      print('❌ Error verifying tables: $e');
      // Force recreation if verification fails
      await _createBusinessTables(_database!);
    }
  }
  
  /// Force creation of missing tables
  Future<void> forceCreateTables() async {
    final db = await database;
    print('🔧 Force creating all required database tables...');
    
    try {
      await _createBusinessTables(db);
      await _createUserTables(db);
      await _createSyncTables(db);
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