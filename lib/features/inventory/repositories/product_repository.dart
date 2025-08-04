import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/crdt_database_service.dart';
import '../../../presentation/providers/app_providers.dart';
import '../models/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts();
  Future<Product?> getProduct(String id);
  Future<void> createProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<List<Product>> searchProducts(String query);
}

class ProductRepositoryImpl implements ProductRepository {
  final CRDTDatabaseService _database;

  ProductRepositoryImpl(this._database);

  @override
  Future<List<Product>> getProducts() async {
    final db = await _database.database;
    final results = await db.query(
      'products',
      orderBy: 'name ASC',
    );
    return results.map((json) => Product.fromDatabase(json)).toList();
  }

  @override
  Future<Product?> getProduct(String id) async {
    final db = await _database.database;
    final results = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Product.fromDatabase(results.first);
  }

  @override
  Future<void> createProduct(Product product) async {
    final db = await _database.database;
    await db.insert('products', product.toDatabase());
  }

  @override
  Future<void> updateProduct(Product product) async {
    final db = await _database.database;
    await db.update(
      'products',
      product.toDatabase(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  @override
  Future<void> deleteProduct(String id) async {
    final db = await _database.database;
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    final db = await _database.database;
    final results = await db.query(
      'products',
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return results.map((json) => Product.fromDatabase(json)).toList();
  }

  Future<List<Product>> getProductsByCategory(String categoryId) async {
    final db = await _database.database;
    final results = await db.query(
      'products',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );
    return results.map((json) => Product.fromDatabase(json)).toList();
  }

  Future<List<Product>> getLowStockProducts({int threshold = 10}) async {
    final db = await _database.database;
    final results = await db.query(
      'products',
      where: 'stock_quantity > 0 AND stock_quantity < ?',
      whereArgs: [threshold],
      orderBy: 'stock_quantity ASC',
    );
    return results.map((json) => Product.fromDatabase(json)).toList();
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final database = ref.watch(crdtDatabaseServiceProvider);
  return ProductRepositoryImpl(database);
});
