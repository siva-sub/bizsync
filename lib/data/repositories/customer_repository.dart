import '../models/customer.dart';
import '../../core/database/crdt_database_service.dart';
import '../../core/database/crdt_models.dart';
import '../../core/crdt/crdt_types.dart';
import '../../core/crdt/hybrid_logical_clock.dart';
import '../../core/crdt/vector_clock.dart';
import '../../core/utils/uuid_generator.dart';

/// Repository for customer-related database operations
class CustomerRepository {
  CRDTDatabaseService? _databaseService;
  
  CustomerRepository();

  /// Get database service, initializing if needed
  Future<CRDTDatabaseService> get databaseService async {
    if (_databaseService == null) {
      _databaseService = CRDTDatabaseService();
      await _databaseService!.initialize();
    }
    return _databaseService!;
  }

  // Mock data for demo purposes - this will be replaced with database seeding
  static final List<Customer> _mockCustomers = [
    Customer(
      id: '1',
      name: 'Acme Corporation Pte Ltd',
      email: 'billing@acme.com.sg',
      phone: '+65 6123 4567',
      address: '123 Business Street\nSingapore 123456',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      gstRegistered: true,
      uen: '200123456A',
    ),
    Customer(
      id: '2',
      name: 'Tech Solutions Pte Ltd',
      email: 'accounts@techsolutions.sg',
      phone: '+65 6789 0123',
      address: '456 Innovation Drive\nSingapore 654321',
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      gstRegistered: true,
      uen: '201987654B',
    ),
    Customer(
      id: '3',
      name: 'Global Trading Co',
      email: 'finance@globaltrading.com',
      phone: '+65 6555 1234',
      address: '789 Commerce Avenue\nSingapore 987654',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      gstRegistered: false,
    ),
    Customer(
      id: '4',
      name: 'Singapore Manufacturing Ltd',
      email: 'procurement@sgmanufacturing.com.sg',
      phone: '+65 6777 8888',
      address: '321 Industrial Road\nSingapore 456789',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      updatedAt: DateTime.now(),
      gstRegistered: true,
      uen: '199876543C',
    ),
    Customer(
      id: '5',
      name: 'Digital Services Hub',
      email: 'admin@digitalhub.sg',
      phone: '+65 6999 0000',
      address: '654 Digital Way\nSingapore 321654',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now(),
      gstRegistered: true,
      uen: '202112345D',
    ),
  ];

  /// Convert Customer to CRDTCustomer
  Future<CRDTCustomer> _customerToCrdt(Customer customer) async {
    final dbService = await databaseService;
    final timestamp = HLCTimestamp.now(dbService.nodeId);
    final vectorClock = VectorClock(dbService.nodeId);
    
    return CRDTCustomer(
      id: customer.id,
      nodeId: dbService.nodeId,
      createdAt: timestamp,
      updatedAt: timestamp,
      version: vectorClock,
      name: CRDTRegister(customer.name, timestamp),
      email: CRDTRegister(customer.email ?? '', timestamp),
      phone: CRDTRegister(customer.phone ?? '', timestamp),
      address: CRDTRegister(customer.address ?? '', timestamp),
      loyaltyPoints: CRDTCounter(0),
      isDeleted: false,
    );
  }
  
  /// Convert CRDTCustomer to Customer
  Customer _crdtToCustomer(CRDTCustomer crdtCustomer) {
    return Customer(
      id: crdtCustomer.id,
      name: crdtCustomer.name.value,
      email: crdtCustomer.email.value.isEmpty ? null : crdtCustomer.email.value,
      phone: crdtCustomer.phone.value.isEmpty ? null : crdtCustomer.phone.value,
      address: crdtCustomer.address.value.isEmpty ? null : crdtCustomer.address.value,
      createdAt: DateTime.fromMillisecondsSinceEpoch(crdtCustomer.createdAt.physicalTime),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(crdtCustomer.updatedAt.physicalTime),
      isActive: !crdtCustomer.isDeleted,
      gstRegistered: false, // This should be added to CRDT model eventually
    );
  }

  /// Get all customers
  Future<List<Customer>> getAllCustomers() async {
    try {
      final dbService = await databaseService;
      final crdtCustomers = await dbService.getAllCustomers();
      return crdtCustomers.map((crdt) => _crdtToCustomer(crdt)).toList();
    } catch (e) {
      // Fallback to mock data if database fails
      return List.from(_mockCustomers);
    }
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(String id) async {
    try {
      final dbService = await databaseService;
      final crdtCustomer = await dbService.getCustomer(id);
      return crdtCustomer != null ? _crdtToCustomer(crdtCustomer) : null;
    } catch (e) {
      // Fallback to mock data
      try {
        return _mockCustomers.firstWhere((customer) => customer.id == id);
      } catch (e) {
        return null;
      }
    }
  }

  /// Search customers by query
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final dbService = await databaseService;
      final crdtCustomers = await dbService.queryCustomers({
        'search_text': query.isEmpty ? null : query,
      });
      return crdtCustomers.map((crdt) => _crdtToCustomer(crdt)).toList();
    } catch (e) {
      // Fallback to mock data
      if (query.isEmpty) {
        return List.from(_mockCustomers);
      }
      
      final lowercaseQuery = query.toLowerCase();
      return _mockCustomers.where((customer) {
        return customer.name.toLowerCase().contains(lowercaseQuery) ||
               (customer.email?.toLowerCase().contains(lowercaseQuery) ?? false) ||
               (customer.phone?.toLowerCase().contains(lowercaseQuery) ?? false) ||
               (customer.uen?.toLowerCase().contains(lowercaseQuery) ?? false);
      }).toList();
    }
  }

  /// Create new customer
  Future<Customer> createCustomer(Customer customer) async {
    try {
      // Generate new ID if not provided
      final customerId = customer.id.isEmpty ? UuidGenerator.generateId() : customer.id;
      final customerWithId = customer.copyWith(id: customerId);
      
      final crdtCustomer = await _customerToCrdt(customerWithId);
      final dbService = await databaseService;
      await dbService.upsertCustomer(crdtCustomer);
      
      return _crdtToCustomer(crdtCustomer);
    } catch (e) {
      // Fallback to mock data
      _mockCustomers.add(customer);
      return customer;
    }
  }

  /// Update existing customer
  Future<Customer> updateCustomer(Customer customer) async {
    try {
      final dbService = await databaseService;
      final existingCrdt = await dbService.getCustomer(customer.id);
      if (existingCrdt != null) {
        // Update the CRDT fields
        final timestamp = HLCTimestamp.now(dbService.nodeId);
        existingCrdt.name.setValue(customer.name, timestamp);
        existingCrdt.email.setValue(customer.email ?? '', timestamp);
        existingCrdt.phone.setValue(customer.phone ?? '', timestamp);
        existingCrdt.address.setValue(customer.address ?? '', timestamp);
        existingCrdt.updatedAt = timestamp;
        
        await dbService.upsertCustomer(existingCrdt);
        return _crdtToCustomer(existingCrdt);
      } else {
        throw Exception('Customer not found');
      }
    } catch (e) {
      // Fallback to mock data
      final index = _mockCustomers.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        _mockCustomers[index] = customer;
        return customer;
      }
      throw Exception('Customer not found');
    }
  }

  /// Delete customer
  Future<void> deleteCustomer(String id) async {
    try {
      final dbService = await databaseService;
      await dbService.deleteCustomer(id);
    } catch (e) {
      // Fallback to mock data
      _mockCustomers.removeWhere((customer) => customer.id == id);
    }
  }

  /// Get customers with GST registration
  Future<List<Customer>> getGstRegisteredCustomers() async {
    try {
      final allCustomers = await getAllCustomers();
      return allCustomers.where((customer) => customer.gstRegistered).toList();
    } catch (e) {
      return _mockCustomers.where((customer) => customer.gstRegistered).toList();
    }
  }

  /// Get active customers
  Future<List<Customer>> getActiveCustomers() async {
    try {
      final allCustomers = await getAllCustomers();
      return allCustomers.where((customer) => customer.isActive).toList();
    } catch (e) {
      return _mockCustomers.where((customer) => customer.isActive).toList();
    }
  }
}