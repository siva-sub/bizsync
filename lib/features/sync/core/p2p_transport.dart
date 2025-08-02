import 'dart:async';
import 'dart:typed_data';
import '../models/sync_models.dart';

/// Abstract base class for P2P transport implementations
abstract class P2PTransport {
  /// Transport type identifier
  TransportType get transportType;

  /// Check if this transport is available on the current platform
  Future<bool> isAvailable();

  /// Initialize the transport
  Future<void> initialize();

  /// Dispose of resources
  Future<void> dispose();

  /// Start advertising this device for discovery
  Future<void> startAdvertising({
    required DeviceInfo deviceInfo,
    Map<String, dynamic>? metadata,
  });

  /// Stop advertising
  Future<void> stopAdvertising();

  /// Start discovering nearby devices
  Stream<DeviceInfo> startDiscovery({
    Duration? timeout,
    Map<String, dynamic>? filters,
  });

  /// Stop discovery
  Future<void> stopDiscovery();

  /// Connect to a discovered device
  Future<P2PConnection> connect(DeviceInfo device);

  /// Accept an incoming connection
  Future<P2PConnection> acceptConnection(String connectionId);

  /// Reject an incoming connection
  Future<void> rejectConnection(String connectionId);

  /// Disconnect from a device
  Future<void> disconnect(String connectionId);

  /// Send data to a connected device
  Future<void> sendData(String connectionId, Uint8List data);

  /// Receive data from connected devices
  Stream<P2PDataPacket> receiveData();

  /// Get connection status
  Stream<P2PConnection> connectionStateChanges();

  /// Get list of active connections
  List<P2PConnection> getActiveConnections();

  /// Get connection by ID
  P2PConnection? getConnection(String connectionId);

  /// Check if connected to a specific device
  bool isConnectedTo(String deviceId);

  /// Get transport-specific settings
  Map<String, dynamic> getSettings();

  /// Update transport-specific settings
  Future<void> updateSettings(Map<String, dynamic> settings);
}

/// Data packet received from P2P transport
class P2PDataPacket {
  final String connectionId;
  final String senderId;
  final Uint8List data;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const P2PDataPacket({
    required this.connectionId,
    required this.senderId,
    required this.data,
    required this.timestamp,
    this.metadata = const {},
  });
}

/// Connection events
enum P2PConnectionEvent {
  connectionRequested,
  connectionEstablished,
  connectionLost,
  connectionError,
  dataReceived,
  discoveryStarted,
  discoveryCompleted,
  deviceFound,
  deviceLost,
}

/// P2P transport factory for creating transport instances
class P2PTransportFactory {
  static final Map<TransportType, P2PTransport Function()> _transportCreators = {};

  /// Register a transport creator
  static void registerTransport(TransportType type, P2PTransport Function() creator) {
    _transportCreators[type] = creator;
  }

  /// Create a transport instance
  static P2PTransport? createTransport(TransportType type) {
    final creator = _transportCreators[type];
    return creator?.call();
  }

  /// Get all available transports
  static Future<List<TransportType>> getAvailableTransports() async {
    final available = <TransportType>[];
    for (final entry in _transportCreators.entries) {
      final transport = entry.value();
      if (await transport.isAvailable()) {
        available.add(entry.key);
      }
      await transport.dispose();
    }
    return available;
  }
}

/// Transport capabilities and requirements
class TransportCapabilities {
  final bool supportsEncryption;
  final bool supportsCompression;
  final bool supportsBackground;
  final bool requiresPermissions;
  final int maxDataSize;
  final int maxConnections;
  final Duration connectionTimeout;
  final List<String> requiredPermissions;
  final Map<String, dynamic> platformRequirements;

  const TransportCapabilities({
    required this.supportsEncryption,
    required this.supportsCompression,
    required this.supportsBackground,
    required this.requiresPermissions,
    required this.maxDataSize,
    required this.maxConnections,
    required this.connectionTimeout,
    this.requiredPermissions = const [],
    this.platformRequirements = const {},
  });
}

/// Transport metrics for monitoring
class TransportMetrics {
  final String transportId;
  final TransportType type;
  final int activeConnections;
  final int totalConnections;
  final int successfulConnections;
  final int failedConnections;
  final int bytesTransmitted;
  final int bytesReceived;
  final Duration averageLatency;
  final DateTime lastActivity;
  final Map<String, dynamic> customMetrics;

  const TransportMetrics({
    required this.transportId,
    required this.type,
    required this.activeConnections,
    required this.totalConnections,
    required this.successfulConnections,
    required this.failedConnections,
    required this.bytesTransmitted,
    required this.bytesReceived,
    required this.averageLatency,
    required this.lastActivity,
    this.customMetrics = const {},
  });
}