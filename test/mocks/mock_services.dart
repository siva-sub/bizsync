/// Mock services for comprehensive testing
library mock_services;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:mockito/mockito.dart';
import 'package:bizsync/core/database/crdt_database_service.dart';
import 'package:bizsync/core/storage/database_service.dart';
import 'package:bizsync/features/notifications/services/enhanced_notification_service.dart';
import 'package:bizsync/services/profile_picture_service.dart';
import 'package:bizsync/features/sync/services/p2p_sync_service.dart';
import 'package:bizsync/features/tax/services/singapore_gst_service.dart';
import 'package:bizsync/features/sync/models/sync_models.dart';
import 'package:bizsync/core/crdt/hybrid_logical_clock.dart';
import 'package:bizsync/core/crdt/vector_clock.dart';
import 'package:bizsync/features/invoices/services/invoice_service.dart';
import 'package:bizsync/features/customers/repositories/customer_repository.dart';
import 'package:bizsync/features/inventory/repositories/product_repository.dart';
import 'package:bizsync/data/models/customer.dart';
import 'package:bizsync/features/inventory/models/product.dart';
import 'dart:typed_data';

/// Mock Database Service
class MockDatabaseService extends Mock {
  // Mock implementation that matches DatabaseService interface
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
class MockNotificationService extends Mock {
  // Mock implementation that matches EnhancedNotificationService interface
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
  
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    Map<String, dynamic>? data,
    List<dynamic>? actions,
    String? bigText,
    dynamic type,
    dynamic category,
    dynamic priority,
    dynamic channel,
    String? imageUrl,
    dynamic style,
    bool? persistent,
    String? groupKey,
    int? progress,
    int? maxProgress,
    bool? indeterminate,
  }) async {
    if (_shouldFailSending) {
      throw Exception('Mock notification failed');
    }
    
    _sentNotifications.add({
      'title': title,
      'body': body,
      'payload': payload,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledFor,
    String? payload,
    Map<String, dynamic>? data,
    List<dynamic>? actions,
    dynamic type,
    dynamic category,
    dynamic priority,
    dynamic channel,
    dynamic recurrenceRule,
  }) async {
    if (_shouldFailSending) {
      throw Exception('Mock scheduled notification failed');
    }
    
    _sentNotifications.add({
      'title': title,
      'body': body,
      'payload': payload,
      'data': data,
      'scheduledDate': scheduledFor.toIso8601String(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

/// Mock Profile Picture Service
class MockProfilePictureService extends Mock implements ProfilePictureService {
  String? _mockProfilePicturePath;
  Uint8List? _mockProfilePictureBytes;
  bool _shouldFailOperations = false;
  
  void setMockProfilePicture(String? path, Uint8List? bytes) {
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
  
  Future<Uint8List?> getProfilePictureBytes() async {
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
    _mockProfilePictureBytes = Uint8List.fromList(await imageFile.readAsBytes());
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
  
  Future<List<String>> discoverDevices() async {
    if (_shouldFailConnection) {
      throw Exception('Mock device discovery error');
    }
    return List.from(_discoveredDevices);
  }
  
  Future<P2PConnection> connectToDevice(DeviceInfo device, {TransportType? preferredTransport}) async {
    if (_shouldFailConnection) {
      throw Exception('Mock connection failed');
    }
    _isConnected = true;
    return P2PConnection(
      connectionId: 'mock-connection',
      remoteDevice: device,
      transport: preferredTransport ?? TransportType.bluetooth,
      state: ConnectionState.connected,
      connectedAt: DateTime.now(),
    );
  }
  
  Future<bool> syncData(List<Map<String, dynamic>> data) async {
    if (_shouldFailSync || !_isConnected) {
      return false;
    }
    
    _syncedData.addAll(data);
    return true;
  }
  
  Future<void> disconnect() async {
    _isConnected = false;
  }
}

/// Mock Singapore GST Service
class MockSingaporeGSTService extends Mock {
  // Mock implementation that matches SingaporeGstService interface
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
  
  Future<List<Customer>> getAllCustomers() async {
    if (_shouldThrowError) {
      throw Exception('Mock customer repository error');
    }
    return _customers.values.map((json) => Customer.fromJson(json)).toList();
  }
  
  Future<Customer?> getCustomer(String id) async {
    if (_shouldThrowError) {
      throw Exception('Mock customer repository error');
    }
    final json = _customers[id];
    return json != null ? Customer.fromJson(json) : null;
  }
  
  Future<void> createCustomer(Customer customer) async {
    if (_shouldThrowError) {
      throw Exception('Mock customer repository error');
    }
    
    _customers[customer.id] = customer.toJson();
  }
  
  Future<void> updateCustomer(Customer customer) async {
    if (_shouldThrowError) {
      throw Exception('Mock customer repository error');
    }
    
    if (_customers.containsKey(customer.id)) {
      _customers[customer.id] = customer.toJson();
    }
  }
  
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
  
  Future<List<Product>> getProducts() async {
    if (_shouldThrowError) {
      throw Exception('Mock product repository error');
    }
    return _products.values.map((json) => Product.fromJson(json)).toList();
  }
  
  Future<Product?> getProduct(String id) async {
    if (_shouldThrowError) {
      throw Exception('Mock product repository error');
    }
    final json = _products[id];
    return json != null ? Product.fromJson(json) : null;
  }
  
  Future<void> createProduct(Product product) async {
    if (_shouldThrowError) {
      throw Exception('Mock product repository error');
    }
    
    _products[product.id] = product.toJson();
  }
  
  Future<void> updateProduct(Product product) async {
    if (_shouldThrowError) {
      throw Exception('Mock product repository error');
    }
    
    if (_products.containsKey(product.id)) {
      _products[product.id] = product.toJson();
    }
  }
  
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
  
  String get nodeId => _nodeId;
  
  HLCTimestamp tick() {
    return HLCTimestamp(_mockTimestamp++, 0, _nodeId);
  }
  
  HLCTimestamp update(HLCTimestamp remoteTimestamp) {
    _mockTimestamp = remoteTimestamp.physicalTime + 1;
    return HLCTimestamp(_mockTimestamp, 0, _nodeId);
  }
  
  HLCTimestamp get current => HLCTimestamp(_mockTimestamp, 0, _nodeId);
  
  HLCTimestamp now() {
    return HLCTimestamp(_mockTimestamp++, 0, _nodeId);
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
  
  VectorClock update(VectorClock remoteClock) {
    // Simple mock implementation
    return this;
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
  
  Map<String, dynamic> toJson() {
    return _clock;
  }
}

/// Main function for testing
void main() {
  // This is a mock service library, not meant to be run directly
  // Individual tests will import the required mocks
}