class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final double? cost;
  final int stockQuantity;
  final String? categoryId;
  final String? barcode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  
  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.cost,
    this.stockQuantity = 0,
    this.categoryId,
    this.barcode,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 0,
  });
  
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      cost: (json['cost'] as num?)?.toDouble(),
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      categoryId: json['category_id'] as String?,
      barcode: json['barcode'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      syncStatus: json['sync_status'] as int? ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'stock_quantity': stockQuantity,
      'category_id': categoryId,
      'barcode': barcode,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    };
  }
  
  factory Product.fromDatabase(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num?)?.toDouble(),
      stockQuantity: map['stock_quantity'] as int? ?? 0,
      categoryId: map['category_id'] as String?,
      barcode: map['barcode'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      syncStatus: map['sync_status'] as int? ?? 0,
    );
  }
  
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'cost': cost,
      'stock_quantity': stockQuantity,
      'category_id': categoryId,
      'barcode': barcode,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'sync_status': syncStatus,
    };
  }
  
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? cost,
    int? stockQuantity,
    String? categoryId,
    String? barcode,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      categoryId: categoryId ?? this.categoryId,
      barcode: barcode ?? this.barcode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
  
  /// Calculate profit margin percentage
  double get profitMarginPercentage {
    if (cost == null || cost == 0) return 0.0;
    return ((price - cost!) / cost!) * 100;
  }
  
  /// Calculate profit amount
  double get profitAmount {
    if (cost == null) return price;
    return price - cost!;
  }
  
  /// Check if product is in stock
  bool get isInStock => stockQuantity > 0;
  
  /// Check if product is low stock (less than 10 units)
  bool get isLowStock => stockQuantity > 0 && stockQuantity < 10;
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          price == other.price &&
          barcode == other.barcode;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      price.hashCode ^
      barcode.hashCode;
  
  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $price, stock: $stockQuantity)';
  }
}