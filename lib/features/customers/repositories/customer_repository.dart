import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/customer.dart';
import '../../../core/database/crdt_database_service.dart';
import '../../../presentation/providers/app_providers.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getCustomers();
  Future<List<Customer>> getAllCustomers();
  Future<Customer?> getCustomer(String id);
  Future<void> createCustomer(Customer customer);
  Future<void> updateCustomer(Customer customer);
  Future<void> deleteCustomer(String id);
  Future<List<Customer>> searchCustomers(String query);
}

class CustomerRepositoryImpl implements CustomerRepository {
  final CRDTDatabaseService _database;

  CustomerRepositoryImpl(this._database);

  @override
  Future<List<Customer>> getCustomers() async {
    final db = await _database.database;
    final results = await db.query(
      'customers',
      orderBy: 'name ASC',
    );
    return results.map((json) => Customer.fromJson(json)).toList();
  }

  @override
  Future<List<Customer>> getAllCustomers() async {
    return await getCustomers(); // Same implementation
  }

  @override
  Future<Customer?> getCustomer(String id) async {
    final db = await _database.database;
    final results = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Customer.fromJson(results.first);
  }

  @override
  Future<void> createCustomer(Customer customer) async {
    final db = await _database.database;
    await db.insert('customers', customer.toJson());
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    final db = await _database.database;
    await db.update(
      'customers',
      customer.toJson(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  @override
  Future<void> deleteCustomer(String id) async {
    final db = await _database.database;
    await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    final db = await _database.database;
    final results = await db.query(
      'customers',
      where: 'name LIKE ? OR email LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return results.map((json) => Customer.fromJson(json)).toList();
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final database = ref.watch(crdtDatabaseServiceProvider);
  return CustomerRepositoryImpl(database);
});