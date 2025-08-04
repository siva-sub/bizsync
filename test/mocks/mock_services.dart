/// Mock services for comprehensive testing
library mock_services;

import 'dart:async';
import 'dart:io';
import 'package:mockito/mockito.dart';
import 'package:bizsync/core/database/crdt_database_service.dart';
import 'package:bizsync/core/database/database_service.dart';
import 'package:bizsync/features/notifications/services/enhanced_notification_service.dart';
import 'package:bizsync/services/profile_picture_service.dart';
import 'package:bizsync/features/sync/services/p2p_sync_service.dart';
import 'package:bizsync/features/tax/services/singapore_gst_service.dart';
import 'package:bizsync/features/invoices/services/invoice_service.dart';
import 'package:bizsync/features/customers/repositories/customer_repository.dart';
import 'package:bizsync/features/inventory/repositories/product_repository.dart';
import 'package:bizsync/core/crdt/hybrid_logical_clock.dart';
import 'package:bizsync/core/crdt/vector_clock.dart';

/// Mock Database Service
class MockDatabaseService extends Mock implements DatabaseService {
  final Map<String, List<Map<String, dynamic>>> _mockTables = {};
  bool _isConnected = true;
  bool _shouldThrowError = false;
  
  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }
  
  void setConnectionStatus(bool connected) {
    _isConnected = connected;
  }
  
  void addMockData(String table, List<Map<String, dynamic>> data) {
    _mockTables[table] = data;
  }
  
  void clearMockData() {
    _mockTables.clear();
  }
  
  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (_shouldThrowError) {
      throw Exception('Mock database error');
    }
    
    if (!_isConnected) {
      throw Exception('Database not connected');
    }
    
    return _mockTables[table] ?? [];
  }
  
  @override
  Future<int> insert(String table, Map<String, dynamic> values) async {
    if (_shouldThrowError) {
      throw Exception('Mock database error');
    }
    
    if (!_isConnected) {
      throw Exception('Database not connected');
    }
    
    _mockTables[table] ??= [];
    _mockTables[table]!.add(values);
    return _mockTables[table]!.length;
  }
  
  @override
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (_shouldThrowError) {
      throw Exception('Mock database error');
    }
    
    if (!_isConnected) {
      throw Exception('Database not connected');
    }
    
    return 1; // Mock successful update
  }
  
  @override
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (_shouldThrowError) {
      throw Exception('Mock database error');
    }
    
    if (!_isConnected) {
      throw Exception('Database not connected');
    }
    
    return 1; // Mock successful delete
  }
}

/// Mock CRDT Database Service
class MockCRDTDatabaseService extends Mock implements CRDTDatabaseService {
  final Map<String, Map<String, dynamic>> _crdtData = {};
  final List<Map<String, dynamic>> _operations = [];
  bool _shouldSimulateConflict = false;
  bool _shouldThrowError = false;
  
  void setShouldSimulateConflict(bool simulate) {
    _shouldSimulateConflict = simulate;
  }
  
  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }
  
  void addMockCRDTData(String entityId, Map<String, dynamic> data) {
    _crdtData[entityId] = data;
  }
  
  List<Map<String, dynamic>> getMockOperations() {
    return List.from(_operations);
  }
  
  void clearMockData() {
    _crdtData.clear();
    _operations.clear();
  }
  
  @override
  Future<void> applyOperation(Map<String, dynamic> operation) async {
    if (_shouldThrowError) {
      throw Exception('Mock CRDT operation error');
    }
    
    _operations.add(operation);
    
    if (_shouldSimulateConflict) {
      throw Exception('CRDT conflict detected');
    }
  }
  
  @override
  Future<Map<String, dynamic>?> getEntity(String entityType, String entityId) async {
    if (_shouldThrowError) {
      throw Exception('Mock CRDT query error');
    }
    
    return _crdtData[entityId];
  }
  
  @override
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    if (_shouldThrowError) {
      throw Exception('Mock CRDT pending operations error');
    }
    
    return List.from(_operations);
  }
}

/// Mock Notification Service
class MockNotificationService extends Mock implements EnhancedNotificationService {
  final List<Map<String, dynamic>> _sentNotifications = [];
  bool _shouldFailSending = false;
  
  void setShouldFailSending(bool shouldFail) {
    _shouldFailSending = shouldFail;
  }
  
  List<Map<String, dynamic>> getSentNotifications() {
    return List.from(_sentNotifications);
  }
  
  void clearSentNotifications() {
    _sentNotifications.clear();
  }
  
  @override
  Future<bool> showNotification({
    required String title,
    required String body,
    String? payload,
    Map<String, dynamic>? data,
  }) async {
    if (_shouldFailSending) {
      return false;
    }
    
    _sentNotifications.add({
      'title': title,
      'body': body,
      'payload': payload,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    return true;
  }
  
  @override
  Future<bool> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    Map<String, dynamic>? data,
  }) async {
    if (_shouldFailSending) {
      return false;
    }
    
    _sentNotifications.add({
      'title': title,
      'body': body,
      'payload': payload,
      'data': data,
      'scheduledDate': scheduledDate.toIso8601String(),
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    return true;
  }
}

/// Mock Profile Picture Service
class MockProfilePictureService extends Mock implements ProfilePictureService {
  String? _mockProfilePicturePath;
  List<int>? _mockProfilePictureBytes;
  bool _shouldFailOperations = false;
  
  void setMockProfilePicture(String? path, List<int>? bytes) {
    _mockProfilePicturePath = path;
    _mockProfilePictureBytes = bytes;
  }
  
  void setShouldFailOperations(bool shouldFail) {
    _shouldFailOperations = shouldFail;
  }
  
  @override
  Future<String?> getProfilePicturePath() async {
    if (_shouldFailOperations) {
      throw Exception('Mock profile picture service error');
    }
    return _mockProfilePicturePath;
  }
  
  @override
  Future<List<int>?> getProfilePictureBytes() async {
    if (_shouldFailOperations) {
      throw Exception('Mock profile picture service error');
    }
    return _mockProfilePictureBytes;
  }
  
  @override
  Future<bool> saveProfilePicture(File imageFile) async {
    if (_shouldFailOperations) {
      return false;
    }
    
    _mockProfilePicturePath = imageFile.path;
    _mockProfilePictureBytes = await imageFile.readAsBytes();
    return true;
  }
  
  @override
  Future<bool> deleteProfilePicture() async {
    if (_shouldFailOperations) {
      return false;
    }
    
    _mockProfilePicturePath = null;
    _mockProfilePictureBytes = null;
    return true;
  }
}

/// Mock P2P Sync Service
class MockP2PSyncService extends Mock implements P2PSyncService {
  final List<String> _discoveredDevices = [];
  final List<Map<String, dynamic>> _syncedData = [];
  bool _isConnected = false;
  bool _shouldFailConnection = false;
  bool _shouldFailSync = false;
  
  void addDiscoveredDevice(String deviceId) {
    _discoveredDevices.add(deviceId);
  }
  
  void setConnectionStatus(bool connected) {
    _isConnected = connected;
  }
  
  void setShouldFailConnection(bool shouldFail) {
    _shouldFailConnection = shouldFail;
  }
  
  void setShouldFailSync(bool shouldFail) {
    _shouldFailSync = shouldFail;
  }
  
  List<String> getDiscoveredDevices() {
    return List.from(_discoveredDevices);
  }
  
  List<Map<String, dynamic>> getSyncedData() {
    return List.from(_syncedData);
  }
  
  @override
  Future<List<String>> discoverDevices() async {
    if (_shouldFailConnection) {
      throw Exception('Mock device discovery error');
    }
    return List.from(_discoveredDevices);
  }
  
  @override
  Future<bool> connectToDevice(String deviceId) async {
    if (_shouldFailConnection) {
      return false;
    }
    _isConnected = true;
    return true;
  }
  
  @override
  Future<bool> syncData(List<Map<String, dynamic>> data) async {
    if (_shouldFailSync || !_isConnected) {
      return false;
    }
    
    _syncedData.addAll(data);
    return true;
  }
  
  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }
}

/// Mock Singapore GST Service
class MockSingaporeGSTService extends Mock implements SingaporeGSTService {
  double _mockGSTRate = 0.09; // 9% current rate
  bool _shouldThrowError = false;
  final Map<DateTime, double> _historicalRates = {
    DateTime(2020, 1, 1): 0.07,
    DateTime(2022, 1, 1): 0.08,
    DateTime(2024, 1, 1): 0.09,
  };
  
  void setMockGSTRate(double rate) {
    _mockGSTRate = rate;
  }
  
  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }
  
  @override
  Future<double> getGSTRate({DateTime? date}) async {
    if (_shouldThrowError) {
      throw Exception('Mock GST service error');
    }
    
    if (date != null) {
      for (final entry in _historicalRates.entries) {
        if (date.isAfter(entry.key)) {
          return entry.value;
        }
      }
    }
    
    return _mockGSTRate;
  }
  
  @override
  Future<Map<String, dynamic>> calculateGST({
    required double amount,
    required bool isGSTRegistered,
    required bool customerIsGSTRegistered,
    required String customerCountry,
    DateTime? calculationDate,
  }) async {
    if (_shouldThrowError) {
      throw Exception('Mock GST calculation error');
    }
    
    final gstRate = await getGSTRate(date: calculationDate);
    double gstAmount = 0.0;
    
    // Simplified GST calculation logic for testing
    if (isGSTRegistered && customerCountry == 'SG') {
      gstAmount = amount * gstRate;
    }
    
    return {
      'amount': amount,
      'gst_rate': gstRate,
      'gst_amount': gstAmount,
      'total_amount': amount + gstAmount,
      'is_export': customerCountry != 'SG',
      'calculation_date': (calculationDate ?? DateTime.now()).toIso8601String(),
    };
  }
}

/// Mock Customer Repository
class MockCustomerRepository extends Mock implements CustomerRepository {
  final Map<String, Map<String, dynamic>> _customers = {};
  bool _shouldThrowError = false;
  
  void addMockCustomer(String id, Map<String, dynamic> customer) {
    _customers[id] = customer;
  }
  
  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }
  
  void clearMockData() {
    _customers.clear();
  }
  
  @override
  Future<List<Map<String, dynamic>>> getAllCustomers() async {
    if (_shouldThrowError) {
      throw Exception('Mock customer repository error');
    }
    return _customers.values.toList();
  }
  
  @override
  Future<Map<String, dynamic>?> getCustomerById(String id) async {
    if (_shouldThrowError) {
      throw Exception('Mock customer repository error');
    }
    return _customers[id];
  }
  
  @override
  Future<String> createCustomer(Map<String, dynamic> customer) async {
    if (_shouldThrowError) {
      throw Exception('Mock customer repository error');
    }
    
    final id = customer['id'] as String;
    _customers[id] = customer;
    return id;
  }
  
  @override
  Future<void> updateCustomer(String id, Map<String, dynamic> customer) async {
    if (_shouldThrowError) {
      throw Exception('Mock customer repository error');
    }
    
    if (_customers.containsKey(id)) {
      _customers[id] = customer;
    }
  }
  
  @override
  Future<void> deleteCustomer(String id) async {
    if (_shouldThrowError) {
      throw Exception('Mock customer repository error');
    }
    
    _customers.remove(id);
  }
}

/// Mock Product Repository
class MockProductRepository extends Mock implements ProductRepository {
  final Map<String, Map<String, dynamic>> _products = {};
  bool _shouldThrowError = false;
  
  void addMockProduct(String id, Map<String, dynamic> product) {
    _products[id] = product;
  }
  
  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }
  
  void clearMockData() {
    _products.clear();
  }
  
  @override
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    if (_shouldThrowError) {
      throw Exception('Mock product repository error');
    }
    return _products.values.toList();
  }
  
  @override
  Future<Map<String, dynamic>?> getProductById(String id) async {
    if (_shouldThrowError) {
      throw Exception('Mock product repository error');
    }
    return _products[id];
  }
  
  @override
  Future<String> createProduct(Map<String, dynamic> product) async {
    if (_shouldThrowError) {
      throw Exception('Mock product repository error');
    }
    
    final id = product['id'] as String;
    _products[id] = product;
    return id;
  }
  
  @override
  Future<void> updateProduct(String id, Map<String, dynamic> product) async {
    if (_shouldThrowError) {
      throw Exception('Mock product repository error');
    }
    
    if (_products.containsKey(id)) {
      _products[id] = product;
    }
  }
  
  @override
  Future<void> deleteProduct(String id) async {
    if (_shouldThrowError) {
      throw Exception('Mock product repository error');
    }
    
    _products.remove(id);
  }
}

/// Mock Hybrid Logical Clock
class MockHybridLogicalClock extends Mock implements HybridLogicalClock {
  int _mockTimestamp = 1000000;
  final String _nodeId;
  
  MockHybridLogicalClock(this._nodeId);
  
  void setMockTimestamp(int timestamp) {
    _mockTimestamp = timestamp;
  }
  
  @override
  String get nodeId => _nodeId;
  
  @override
  int now() {
    return _mockTimestamp++;
  }
  
  @override
  int update(int receivedTime) {
    _mockTimestamp = receivedTime + 1;
    return _mockTimestamp;
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'node_id': _nodeId,
      'timestamp': _mockTimestamp,
    };
  }
}

/// Mock Vector Clock
class MockVectorClock extends Mock implements VectorClock {
  final Map<String, int> _clock = {};
  
  void setMockClock(Map<String, int> clock) {
    _clock.clear();
    _clock.addAll(clock);
  }
  
  @override
  void increment(String nodeId) {
    _clock[nodeId] = (_clock[nodeId] ?? 0) + 1;
  }
  
  @override
  void update(String nodeId, int timestamp) {
    _clock[nodeId] = timestamp;
  }
  
  @override
  bool happensBefore(VectorClock other) {
    // Simplified comparison for testing
    return false;
  }
  
  @override
  bool isConcurrent(VectorClock other) {
    // Simplified comparison for testing
    return true;
  }
  
  @override
  Map<String, int> toMap() {
    return Map.from(_clock);
  }
  
  @override
  String toJson() {
    return _clock.toString();
  }
}