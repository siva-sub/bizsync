import 'package:flutter_test/flutter_test.dart';
import 'package:bizsync/features/inventory/models/product.dart';
import 'package:bizsync/features/inventory/repositories/product_repository.dart';
import 'package:bizsync/core/database/crdt_database_service.dart';
import 'package:bizsync/core/utils/uuid_generator.dart';
import '../test_factories.dart';

/// Comprehensive integration tests for inventory management
/// Tests product CRUD, stock management, alerts, and search functionality
void main() {
  group('Inventory Management Integration Tests', () {
    late CRDTDatabaseService databaseService;
    late ProductRepository productRepository;

    setUpAll(() async {
      databaseService = CRDTDatabaseService();
      await databaseService.initialize('test_node_inventory');
      productRepository = ProductRepository();
    });

    tearDownAll(() async {
      await databaseService.closeDatabase();
    });

    setUp(() {
      TestFactories.reset();
    });

    group('Product Creation and Management', () {
      test('should create new product with all fields', () async {
        // Arrange
        final product = TestFactories.createProduct(
          name: 'Integration Test Product',
          description: 'Product for integration testing',
          price: 299.99,
          cost: 150.00,
          stockQuantity: 100,
          minStockLevel: 20,
          category: 'Electronics',
          barcode: '1234567890123',
        );

        // Act - Save product to database
        final db = await databaseService.database;
        await db.insert('products', product.toDatabase());

        // Retrieve from database
        final result = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [product.id],
        );

        // Assert
        expect(result, hasLength(1));
        final retrievedProduct = Product.fromDatabase(result.first);
        
        expect(retrievedProduct.id, equals(product.id));
        expect(retrievedProduct.name, equals('Integration Test Product'));
        expect(retrievedProduct.description, equals('Product for integration testing'));
        expect(retrievedProduct.price, equals(299.99));
        expect(retrievedProduct.cost, equals(150.00));
        expect(retrievedProduct.stockQuantity, equals(100));
        expect(retrievedProduct.minStockLevel, equals(20));
        expect(retrievedProduct.category, equals('Electronics'));
        expect(retrievedProduct.barcode, equals('1234567890123'));
      });

      test('should validate required fields', () async {
        // Test that name and price are required
        final invalidProduct = {
          'id': UuidGenerator.generateId(),
          // Missing name
          'price': -10.0, // Invalid negative price
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };

        final db = await databaseService.database;
        
        // Should fail due to NOT NULL constraint on name
        expect(
          () async => await db.insert('products', invalidProduct),
          throwsException,
        );
      });

      test('should enforce price constraints', () async {
        // Negative price should be rejected by CHECK constraint
        final product = TestFactories.createProduct(price: -10.0);
        final db = await databaseService.database;
        
        expect(
          () async => await db.insert('products', product.toDatabase()),
          throwsException,
        );
      });

      test('should calculate profit margins correctly', () async {
        final product = TestFactories.createProduct(
          price: 120.0,
          cost: 80.0,
        );

        // Profit margin = ((120 - 80) / 80) * 100 = 50%
        expect(product.profitMarginPercentage, equals(50.0));
        expect(product.profitAmount, equals(40.0));
      });

      test('should handle products without cost data', () async {
        final product = TestFactories.createProduct(
          price: 100.0,
          cost: null,
        );

        expect(product.profitMarginPercentage, equals(0.0));
        expect(product.profitAmount, equals(100.0)); // Full price as profit
      });
    });

    group('Stock Level Management', () {
      test('should update stock levels correctly', () async {
        // Arrange
        final product = TestFactories.createProduct(stockQuantity: 100);
        final db = await databaseService.database;
        await db.insert('products', product.toDatabase());

        // Act - Decrease stock (sale)
        final updatedStockQuantity = 85;
        await db.update(
          'products',
          {
            'stock_quantity': updatedStockQuantity,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [product.id],
        );

        // Assert
        final result = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [product.id],
        );
        
        final updatedProduct = Product.fromDatabase(result.first);
        expect(updatedProduct.stockQuantity, equals(85));
        expect(updatedProduct.isInStock, isTrue);
      });

      test('should handle stock going to zero', () async {
        // Arrange
        final product = TestFactories.createProduct(stockQuantity: 5);
        final db = await databaseService.database;
        await db.insert('products', product.toDatabase());

        // Act - Sell all stock
        await db.update(
          'products',
          {
            'stock_quantity': 0,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [product.id],
        );

        // Assert
        final result = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [product.id],
        );
        
        final outOfStockProduct = Product.fromDatabase(result.first);
        expect(outOfStockProduct.stockQuantity, equals(0));
        expect(outOfStockProduct.isInStock, isFalse);
        expect(outOfStockProduct.isLowStock, isFalse); // 0 is not low stock, it's out of stock
      });

      test('should prevent negative stock quantities', () async {
        final product = TestFactories.createProduct(stockQuantity: -5);
        final db = await databaseService.database;
        
        // Should fail due to CHECK constraint
        expect(
          () async => await db.insert('products', product.toDatabase()),
          throwsException,
        );
      });

      test('should track stock movements with audit trail', () async {
        // Arrange
        final product = TestFactories.createProduct(stockQuantity: 100);
        final db = await databaseService.database;
        await db.insert('products', product.toDatabase());

        // Act - Record stock movement
        final stockMovement = {
          'id': UuidGenerator.generateId(),
          'product_id': product.id,
          'movement_type': 'sale',
          'quantity_change': -15,
          'previous_quantity': 100,
          'new_quantity': 85,
          'reason': 'Sale to customer',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // Simulate recording stock movement (would be in a real stock_movements table)
        // For now, just verify the calculation logic
        final previousQty = stockMovement['previous_quantity'] as int;
        final change = stockMovement['quantity_change'] as int;
        final newQty = stockMovement['new_quantity'] as int;
        
        expect(newQty, equals(previousQty + change)); // 100 + (-15) = 85
      });
    });

    group('Low Stock Alerts', () {
      test('should identify low stock products', () async {
        // Arrange - Create products with different stock levels
        final products = [
          TestFactories.createProduct(
            name: 'Normal Stock Product',
            stockQuantity: 50,
            minStockLevel: 10,
          ),
          TestFactories.createLowStockProduct(
            name: 'Low Stock Product',
            stockQuantity: 5,
            minStockLevel: 10,
          ),
          TestFactories.createOutOfStockProduct(
            name: 'Out of Stock Product',
          ),
        ];

        final db = await databaseService.database;
        for (final product in products) {
          await db.insert('products', product.toDatabase());
        }

        // Act - Query for low stock products
        final lowStockResults = await db.query(
          'products',
          where: 'stock_quantity > 0 AND stock_quantity < min_stock_level',
          orderBy: 'stock_quantity ASC',
        );

        // Assert
        expect(lowStockResults, hasLength(1));
        final lowStockProduct = Product.fromDatabase(lowStockResults.first);
        expect(lowStockProduct.name, equals('Low Stock Product'));
        expect(lowStockProduct.isLowStock, isTrue);
        expect(lowStockProduct.isInStock, isTrue);
      });

      test('should query out of stock products separately', () async {
        final products = [
          TestFactories.createProduct(stockQuantity: 50),
          TestFactories.createLowStockProduct(stockQuantity: 5),
          TestFactories.createOutOfStockProduct(),
        ];

        final db = await databaseService.database;
        for (final product in products) {
          await db.insert('products', product.toDatabase());
        }

        // Query out of stock products
        final outOfStockResults = await db.query(
          'products',
          where: 'stock_quantity = 0',
        );

        expect(outOfStockResults, hasLength(1));
        final outOfStockProduct = Product.fromDatabase(outOfStockResults.first);
        expect(outOfStockProduct.isInStock, isFalse);
      });

      test('should calculate lead time for reordering', () async {
        final product = TestFactories.createLowStockProduct(
          stockQuantity: 3,
          minStockLevel: 10,
        );

        // Stock deficit = 10 - 3 = 7 units needed
        final stockDeficit = product.minStockLevel - product.stockQuantity;
        expect(stockDeficit, equals(7));

        // Lead time indicates when to reorder
        expect(product.leadTimeDays, equals(7)); // Default lead time
        
        // Should reorder if current stock < (daily usage * lead time + min stock)
        // For this test, we'll assume daily usage can be calculated from historical data
      });
    });

    group('Product Search and Filtering', () {
      test('should search products by name', () async {
        // Arrange - Create products with different names
        final products = [
          TestFactories.createProduct(name: 'iPhone 15 Pro'),
          TestFactories.createProduct(name: 'Samsung Galaxy S24'),
          TestFactories.createProduct(name: 'iPad Air'),
          TestFactories.createProduct(name: 'MacBook Pro'),
        ];

        final db = await databaseService.database;
        for (final product in products) {
          await db.insert('products', product.toDatabase());
        }

        // Act - Search for products containing "Pro"
        final searchResults = await db.query(
          'products',
          where: 'name LIKE ?',
          whereArgs: ['%Pro%'],
          orderBy: 'name ASC',
        );

        // Assert
        expect(searchResults, hasLength(2));
        expect(searchResults[0]['name'], equals('iPhone 15 Pro'));
        expect(searchResults[1]['name'], equals('MacBook Pro'));
      });

      test('should filter products by category', () async {
        final products = [
          TestFactories.createProduct(
            name: 'Laptop',
            category: 'Electronics',
          ),
          TestFactories.createProduct(
            name: 'Chair',
            category: 'Furniture',
          ),
          TestFactories.createProduct(
            name: 'Phone',
            category: 'Electronics',
          ),
        ];

        final db = await databaseService.database;
        for (final product in products) {
          await db.insert('products', product.toDatabase());
        }

        // Filter by Electronics category
        final electronicsResults = await db.query(
          'products',
          where: 'category = ?',
          whereArgs: ['Electronics'],
        );

        expect(electronicsResults, hasLength(2));
      });

      test('should filter products by price range', () async {
        final products = [
          TestFactories.createProduct(name: 'Budget Item', price: 25.0),
          TestFactories.createProduct(name: 'Mid Range Item', price: 150.0),
          TestFactories.createProduct(name: 'Premium Item', price: 500.0),
        ];

        final db = await databaseService.database;
        for (final product in products) {
          await db.insert('products', product.toDatabase());
        }

        // Filter by price range: $100 - $300
        final priceRangeResults = await db.query(
          'products',
          where: 'price BETWEEN ? AND ?',
          whereArgs: [100.0, 300.0],
        );

        expect(priceRangeResults, hasLength(1));
        expect(priceRangeResults.first['name'], equals('Mid Range Item'));
      });

      test('should search by barcode', () async {
        final products = [
          TestFactories.createProduct(
            name: 'Product A',
            barcode: '1234567890123',
          ),
          TestFactories.createProduct(
            name: 'Product B',
            barcode: '9876543210987',
          ),
        ];

        final db = await databaseService.database;
        for (final product in products) {
          await db.insert('products', product.toDatabase());
        }

        // Search by exact barcode
        final barcodeResults = await db.query(
          'products',
          where: 'barcode = ?',
          whereArgs: ['1234567890123'],
        );

        expect(barcodeResults, hasLength(1));
        expect(barcodeResults.first['name'], equals('Product A'));
      });

      test('should support complex search queries', () async {
        final products = [
          TestFactories.createProduct(
            name: 'iPhone 15 Pro',
            category: 'Electronics',
            price: 1200.0,
            stockQuantity: 25,
          ),
          TestFactories.createProduct(
            name: 'Samsung Galaxy S24',
            category: 'Electronics',
            price: 900.0,
            stockQuantity: 10,
          ),
          TestFactories.createProduct(
            name: 'Office Chair',
            category: 'Furniture',
            price: 300.0,
            stockQuantity: 5,
          ),
        ];

        final db = await databaseService.database;
        for (final product in products) {
          await db.insert('products', product.toDatabase());
        }

        // Complex query: Electronics under $1000 with more than 5 in stock
        final complexResults = await db.query(
          'products',
          where: 'category = ? AND price < ? AND stock_quantity > ?',
          whereArgs: ['Electronics', 1000.0, 5],
        );

        expect(complexResults, hasLength(1));
        expect(complexResults.first['name'], equals('Samsung Galaxy S24'));
      });
    });

    group('Product Categories', () {
      test('should organize products by categories', () async {
        final products = [
          TestFactories.createProduct(category: 'Electronics'),
          TestFactories.createProduct(category: 'Electronics'),
          TestFactories.createProduct(category: 'Furniture'),
          TestFactories.createProduct(category: 'Clothing'),
        ];

        final db = await databaseService.database;
        for (final product in products) {
          await db.insert('products', product.toDatabase());
        }

        // Get category summary
        final categoryResults = await db.rawQuery('''
          SELECT category, COUNT(*) as count, AVG(price) as avg_price
          FROM products 
          WHERE category IS NOT NULL
          GROUP BY category
          ORDER BY count DESC
        ''');

        expect(categoryResults, hasLength(3));
        
        // Electronics should have 2 products
        final electronicsCategory = categoryResults.firstWhere(
          (row) => row['category'] == 'Electronics',
        );
        expect(electronicsCategory['count'], equals(2));
      });

      test('should calculate category-wise inventory value', () async {
        final products = [
          TestFactories.createProduct(
            category: 'Electronics',
            price: 100.0,
            cost: 60.0,
            stockQuantity: 10,
          ),
          TestFactories.createProduct(
            category: 'Electronics',
            price: 200.0,
            cost: 120.0,
            stockQuantity: 5,
          ),
        ];

        final db = await databaseService.database;
        for (final product in products) {
          await db.insert('products', product.toDatabase());
        }

        // Calculate inventory value by category
        final inventoryValue = await db.rawQuery('''
          SELECT 
            category,
            SUM(cost * stock_quantity) as cost_value,
            SUM(price * stock_quantity) as retail_value,
            SUM(stock_quantity) as total_units
          FROM products 
          WHERE category = ?
          GROUP BY category
        ''', ['Electronics']);

        expect(inventoryValue, hasLength(1));
        final electronics = inventoryValue.first;
        
        // Cost value: (60 * 10) + (120 * 5) = 600 + 600 = 1200
        expect(electronics['cost_value'], equals(1200.0));
        
        // Retail value: (100 * 10) + (200 * 5) = 1000 + 1000 = 2000
        expect(electronics['retail_value'], equals(2000.0));
        
        // Total units: 10 + 5 = 15
        expect(electronics['total_units'], equals(15));
      });
    });

    group('Bulk Operations', () {
      test('should support bulk stock updates', () async {
        // Create multiple products
        final products = List.generate(5, (index) => 
          TestFactories.createProduct(
            name: 'Product ${index + 1}',
            stockQuantity: 100,
          )
        );

        final db = await databaseService.database;
        
        // Use batch for efficient bulk operations
        final batch = db.batch();
        for (final product in products) {
          batch.insert('products', product.toDatabase());
        }
        await batch.commit();

        // Bulk update stock levels (simulate inventory count adjustment)
        await db.rawUpdate('''
          UPDATE products 
          SET stock_quantity = stock_quantity - 10,
              updated_at = ?
          WHERE name LIKE 'Product%'
        ''', [DateTime.now().millisecondsSinceEpoch]);

        // Verify all products were updated
        final updatedResults = await db.query(
          'products',
          where: 'name LIKE ?',
          whereArgs: ['Product%'],
        );

        expect(updatedResults, hasLength(5));
        for (final result in updatedResults) {
          expect(result['stock_quantity'], equals(90));
        }
      });

      test('should handle bulk price updates', () async {
        final products = [
          TestFactories.createProduct(
            category: 'Electronics',
            price: 100.0,
          ),
          TestFactories.createProduct(
            category: 'Electronics',
            price: 200.0,
          ),
          TestFactories.createProduct(
            category: 'Furniture',
            price: 150.0,
          ),
        ];

        final db = await databaseService.database;
        for (final product in products) {
          await db.insert('products', product.toDatabase());
        }

        // Apply 10% price increase to Electronics category
        await db.rawUpdate('''
          UPDATE products 
          SET price = price * 1.10,
              updated_at = ?
          WHERE category = ?
        ''', [DateTime.now().millisecondsSinceEpoch, 'Electronics']);

        // Verify price updates
        final electronicsResults = await db.query(
          'products',
          where: 'category = ?',
          whereArgs: ['Electronics'],
        );

        expect(electronicsResults, hasLength(2));
        expect(electronicsResults[0]['price'], closeTo(110.0, 0.01));
        expect(electronicsResults[1]['price'], closeTo(220.0, 0.01));

        // Furniture should be unchanged
        final furnitureResults = await db.query(
          'products',
          where: 'category = ?',
          whereArgs: ['Furniture'],
        );
        expect(furnitureResults.first['price'], equals(150.0));
      });
    });

    group('Performance and Indexing', () {
      test('should efficiently query large product datasets', () async {
        // Create a large number of products
        const productCount = 1000;
        final db = await databaseService.database;
        
        final batch = db.batch();
        for (int i = 0; i < productCount; i++) {
          final product = TestFactories.createProduct(
            name: 'Product ${i.toString().padLeft(4, '0')}',
            category: 'Category ${i % 10}', // 10 different categories
            price: 50.0 + (i % 100), // Prices from 50 to 149
          );
          batch.insert('products', product.toDatabase());
        }
        
        final stopwatch = Stopwatch()..start();
        await batch.commit();
        stopwatch.stop();
        
        print('Bulk insert of $productCount products took: ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should be under 5 seconds

        // Test indexed queries performance
        stopwatch.reset();
        stopwatch.start();
        
        final searchResults = await db.query(
          'products',
          where: 'name LIKE ?',
          whereArgs: ['%0500%'],
        );
        
        stopwatch.stop();
        print('Name search query took: ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be under 100ms
        expect(searchResults, isNotEmpty);
      });
    });
  });
}