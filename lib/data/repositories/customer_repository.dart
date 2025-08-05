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

  // Database seeding service provides initial data when database is empty
  // No static mock data needed - all data comes from CRDT database

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
      address: crdtCustomer.address.value.isEmpty
          ? null
          : crdtCustomer.address.value,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          crdtCustomer.createdAt.physicalTime),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          crdtCustomer.updatedAt.physicalTime),
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
      // Log error and return empty list for proper error handling
      print('Error getting customers from database: $e');
      throw Exception('Failed to retrieve customers: $e');
    }
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(String id) async {
    try {
      final dbService = await databaseService;
      final crdtCustomer = await dbService.getCustomer(id);
      return crdtCustomer != null ? _crdtToCustomer(crdtCustomer) : null;
    } catch (e) {
      // Log error and return null for proper error handling
      print('Error getting customer by ID $id: $e');
      return null;
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
      // Log error and throw exception for proper error handling
      print('Error searching customers with query "$query": $e');
      throw Exception('Failed to search customers: $e');
    }
  }

  /// Create new customer
  Future<Customer> createCustomer(Customer customer) async {
    try {
      // Generate new ID if not provided
      final customerId =
          customer.id.isEmpty ? UuidGenerator.generateId() : customer.id;
      final customerWithId = customer.copyWith(id: customerId);

      final crdtCustomer = await _customerToCrdt(customerWithId);
      final dbService = await databaseService;
      await dbService.upsertCustomer(crdtCustomer);

      return _crdtToCustomer(crdtCustomer);
    } catch (e) {
      // Log error and throw exception for proper error handling
      print('Error creating customer "${customer.name}": $e');
      throw Exception('Failed to create customer: $e');
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
        throw Exception('Customer with ID ${customer.id} not found');
      }
    } catch (e) {
      // Log error and throw exception for proper error handling
      print('Error updating customer "${customer.name}" (ID: ${customer.id}): $e');
      throw Exception('Failed to update customer: $e');
    }
  }

  /// Delete customer
  Future<void> deleteCustomer(String id) async {
    try {
      final dbService = await databaseService;
      await dbService.deleteCustomer(id);
    } catch (e) {
      // Log error and throw exception for proper error handling
      print('Error deleting customer with ID $id: $e');
      throw Exception('Failed to delete customer: $e');
    }
  }

  /// Get customers with GST registration
  Future<List<Customer>> getGstRegisteredCustomers() async {
    try {
      final allCustomers = await getAllCustomers();
      return allCustomers.where((customer) => customer.gstRegistered).toList();
    } catch (e) {
      // Log error and throw exception for proper error handling
      print('Error getting GST registered customers: $e');
      throw Exception('Failed to retrieve GST registered customers: $e');
    }
  }

  /// Get active customers
  Future<List<Customer>> getActiveCustomers() async {
    try {
      final allCustomers = await getAllCustomers();
      return allCustomers.where((customer) => customer.isActive).toList();
    } catch (e) {
      // Log error and throw exception for proper error handling
      print('Error getting active customers: $e');
      throw Exception('Failed to retrieve active customers: $e');
    }
  }
}
