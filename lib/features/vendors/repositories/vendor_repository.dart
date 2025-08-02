import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/crdt_database_service.dart';
import '../../../presentation/providers/app_providers.dart';
import '../models/vendor.dart';

abstract class VendorRepository {
  Future<List<Vendor>> getVendors();
  Future<Vendor?> getVendor(String id);
  Future<void> createVendor(Vendor vendor);
  Future<void> updateVendor(Vendor vendor);
  Future<void> deleteVendor(String id);
  Future<List<Vendor>> searchVendors(String query);
}

class VendorRepositoryImpl implements VendorRepository {
  final CRDTDatabaseService _database;

  VendorRepositoryImpl(this._database);

  @override
  Future<List<Vendor>> getVendors() async {
    final db = await _database.database;
    final results = await db.query(
      'vendors',
      orderBy: 'name ASC',
    );
    return results.map((json) => Vendor.fromDatabase(json)).toList();
  }

  @override
  Future<Vendor?> getVendor(String id) async {
    final db = await _database.database;
    final results = await db.query(
      'vendors',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Vendor.fromDatabase(results.first);
  }

  @override
  Future<void> createVendor(Vendor vendor) async {
    final db = await _database.database;
    await db.insert('vendors', vendor.toDatabase());
  }

  @override
  Future<void> updateVendor(Vendor vendor) async {
    final db = await _database.database;
    await db.update(
      'vendors',
      vendor.toDatabase(),
      where: 'id = ?',
      whereArgs: [vendor.id],
    );
  }

  @override
  Future<void> deleteVendor(String id) async {
    final db = await _database.database;
    await db.delete(
      'vendors',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Vendor>> searchVendors(String query) async {
    final db = await _database.database;
    final results = await db.query(
      'vendors',
      where: 'name LIKE ? OR email LIKE ? OR contact_person LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return results.map((json) => Vendor.fromDatabase(json)).toList();
  }

  Future<List<Vendor>> getActiveVendors() async {
    final db = await _database.database;
    final results = await db.query(
      'vendors',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return results.map((json) => Vendor.fromDatabase(json)).toList();
  }

  Future<List<Vendor>> getVendorsByCountry(String countryCode) async {
    final db = await _database.database;
    final results = await db.query(
      'vendors',
      where: 'country_code = ?',
      whereArgs: [countryCode],
      orderBy: 'name ASC',
    );
    return results.map((json) => Vendor.fromDatabase(json)).toList();
  }
}

final vendorRepositoryProvider = Provider<VendorRepository>((ref) {
  final database = ref.watch(crdtDatabaseServiceProvider);
  return VendorRepositoryImpl(database);
});