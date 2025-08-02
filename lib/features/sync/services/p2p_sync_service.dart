import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../core/p2p_transport.dart';
import '../communication/bluetooth_transport.dart';
import '../communication/wifi_direct_transport.dart';
import '../communication/mdns_transport.dart';
import '../security/encryption_service.dart';
import '../security/device_authentication.dart';
import '../engine/crdt_sync_engine.dart';
import '../models/sync_models.dart';

/// Comprehensive P2P synchronization service
class P2PSyncService {
  static const Duration _sessionTimeout = Duration(minutes: 30);
  static const Duration _discoveryTimeout = Duration(seconds: 60);
  static const String _keyDeviceInfo = 'device_info';
  
  final EncryptionService _encryptionService;
  final DeviceAuthenticationService _authService;
  final CRDTSyncEngine _syncEngine;
  
  final Map<TransportType, P2PTransport> _transports = {};
  final StreamController<DeviceInfo> _discoveryController = StreamController<DeviceInfo>.broadcast();
  final StreamController<P2PConnection> _connectionController = StreamController<P2PConnection>.broadcast();
  final StreamController<SyncSession> _sessionController = StreamController<SyncSession>.broadcast();
  
  final Map<String, SyncSession> _activeSessions = {};
  final Map<String, Timer> _sessionTimers = {};
  final Map<String, StreamSubscription> _connectionSubscriptions = {};
  
  DeviceInfo? _localDeviceInfo;
  bool _isInitialized = false;
  bool _isDiscovering = false;
  bool _isAdvertising = false;

  P2PSyncService()
      : _encryptionService = EncryptionService(),
        _authService = DeviceAuthenticationService(EncryptionService()),
        _syncEngine = CRDTSyncEngine(EncryptionService());

  /// Initialize the P2P sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize core services
    await _authService.initialize();
    await _syncEngine.initialize(_authService.deviceId);
    
    // Load device info
    await _loadDeviceInfo();
    
    // Register and initialize transports
    await _initializeTransports();
    
    // Set up message handling
    _setupMessageHandling();
    
    _isInitialized = true;
    debugPrint('P2P sync service initialized');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopDiscovery();
    await stopAdvertising();
    
    // Cancel all session timers
    for (final timer in _sessionTimers.values) {
      timer.cancel();
    }
    _sessionTimers.clear();
    
    // Cancel connection subscriptions
    for (final subscription in _connectionSubscriptions.values) {
      await subscription.cancel();
    }
    _connectionSubscriptions.clear();
    
    // Dispose transports
    for (final transport in _transports.values) {
      await transport.dispose();
    }
    _transports.clear();
    
    // Dispose core services
    await _syncEngine.dispose();
    await _authService.dispose();
    
    await _discoveryController.close();
    await _connectionController.close();
    await _sessionController.close();
    
    _isInitialized = false;
    debugPrint('P2P sync service disposed');
  }

  /// Get local device information
  DeviceInfo get localDeviceInfo => _localDeviceInfo!;

  /// Stream of discovered devices
  Stream<DeviceInfo> get discoveredDevices => _discoveryController.stream;

  /// Stream of connection state changes
  Stream<P2PConnection> get connectionStateChanges => _connectionController.stream;

  /// Stream of sync session updates
  Stream<SyncSession> get syncSessionUpdates => _sessionController.stream;

  /// Stream of sync progress updates
  Stream<SyncProgress> get syncProgressUpdates => _syncEngine.progressUpdates;

  /// Get available transport types
  Future<List<TransportType>> getAvailableTransports() async {
    final available = <TransportType>[];
    
    for (final entry in _transports.entries) {
      if (await entry.value.isAvailable()) {
        available.add(entry.key);
      }
    }
    
    return available;
  }

  /// Start device discovery
  Future<void> startDiscovery({
    List<TransportType>? transportTypes,
    Duration? timeout,
  }) async {
    if (_isDiscovering) return;
    
    _isDiscovering = true;
    final useTransports = transportTypes ?? _transports.keys.toList();
    final discoveryTimeout = timeout ?? _discoveryTimeout;
    
    debugPrint('Starting device discovery with transports: $useTransports');
    
    // Start discovery on each transport
    for (final transportType in useTransports) {
      final transport = _transports[transportType];
      if (transport != null && await transport.isAvailable()) {
        _startTransportDiscovery(transport, discoveryTimeout);
      }
    }
    
    // Auto-stop discovery after timeout
    Timer(discoveryTimeout, () {
      if (_isDiscovering) {
        stopDiscovery();
      }
    });
  }

  /// Stop device discovery
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;
    
    _isDiscovering = false;
    
    // Stop discovery on all transports
    for (final transport in _transports.values) {
      try {
        await transport.stopDiscovery();
      } catch (e) {
        debugPrint('Error stopping discovery on transport: $e');
      }
    }
    
    debugPrint('Stopped device discovery');
  }

  /// Start advertising this device
  Future<void> startAdvertising({
    List<TransportType>? transportTypes,
    Map<String, dynamic>? metadata,
  }) async {
    if (_isAdvertising) return;
    
    _isAdvertising = true;
    final useTransports = transportTypes ?? _transports.keys.toList();
    
    debugPrint('Starting device advertising with transports: $useTransports');
    
    // Start advertising on each transport
    for (final transportType in useTransports) {
      final transport = _transports[transportType];
      if (transport != null && await transport.isAvailable()) {
        try {
          await transport.startAdvertising(
            deviceInfo: _localDeviceInfo!,
            metadata: metadata,
          );
        } catch (e) {
          debugPrint('Error starting advertising on $transportType: $e');
        }
      }
    }
  }

  /// Stop advertising this device
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    
    _isAdvertising = false;
    
    // Stop advertising on all transports
    for (final transport in _transports.values) {
      try {
        await transport.stopAdvertising();
      } catch (e) {
        debugPrint('Error stopping advertising on transport: $e');
      }
    }
    
    debugPrint('Stopped device advertising');
  }

  /// Connect to a discovered device
  Future<P2PConnection> connectToDevice(
    DeviceInfo device,
    {TransportType? preferredTransport}
  ) async {
    // Check if device is paired
    if (!await _authService.isDevicePaired(device.deviceId)) {
      throw Exception('Device not paired: ${device.deviceName}');
    }
    
    // Select transport
    final transportType = preferredTransport ?? 
        device.supportedTransports.map(_parseTransportType).first;
    
    final transport = _transports[transportType];
    if (transport == null) {
      throw Exception('Transport not available: $transportType');
    }
    
    try {
      // Establish connection
      final connection = await transport.connect(device);
      
      // Set up connection monitoring
      _setupConnectionMonitoring(connection);
      
      _connectionController.add(connection);
      
      debugPrint('Connected to device: ${device.deviceName} via $transportType');
      return connection;
      
    } catch (e) {
      debugPrint('Failed to connect to device: $e');
      rethrow;
    }
  }

  /// Disconnect from a device
  Future<void> disconnectFromDevice(String deviceId) async {
    for (final transport in _transports.values) {
      final connections = transport.getActiveConnections();
      final connection = connections
          .where((conn) => conn.remoteDevice.deviceId == deviceId)
          .firstOrNull;
      
      if (connection != null) {
        await transport.disconnect(connection.connectionId);
        break;
      }
    }
  }

  /// Start a sync session with one or more devices
  Future<SyncSession> startSyncSession(
    List<String> deviceIds,
    SyncConfiguration configuration,
  ) async {
    // Verify all devices are connected
    final connections = _getActiveConnections();
    for (final deviceId in deviceIds) {
      final isConnected = connections.any((conn) => 
          conn.remoteDevice.deviceId == deviceId &&
          conn.state == ConnectionState.connected
      );
      
      if (!isConnected) {
        throw Exception('Device not connected: $deviceId');
      }
    }
    
    // Start sync session in engine
    final session = await _syncEngine.startSyncSession(deviceIds, configuration);
    
    // Track session
    _activeSessions[session.sessionId] = session;
    _setSessionTimeout(session.sessionId);
    
    // Notify participants
    await _notifySessionParticipants(session);
    
    _sessionController.add(session);
    
    debugPrint('Started sync session: ${session.sessionId} with ${deviceIds.length} devices');
    return session;
  }

  /// Cancel an active sync session
  Future<void> cancelSyncSession(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) return;
    
    // Cancel session timer
    _sessionTimers[sessionId]?.cancel();
    _sessionTimers.remove(sessionId);
    
    // Update session state
    final cancelledSession = SyncSession(
      sessionId: session.sessionId,
      participantDeviceIds: session.participantDeviceIds,
      state: SyncSessionState.cancelled,
      startedAt: session.startedAt,
      completedAt: DateTime.now(),
      configuration: session.configuration,
      progress: session.progress,
      conflicts: session.conflicts,
    );
    
    _activeSessions[sessionId] = cancelledSession;
    _sessionController.add(cancelledSession);
    
    // Notify participants
    await _notifySessionCancellation(cancelledSession);
    
    debugPrint('Cancelled sync session: $sessionId');
  }

  /// Get list of active connections
  List<P2PConnection> getActiveConnections() {
    return _getActiveConnections();
  }

  /// Get sync statistics
  SyncStatistics getSyncStatistics() {
    return _syncEngine.getSyncStatistics();
  }

  /// Apply local operation for synchronization
  Future<void> applyLocalOperation(CRDTOperation operation) async {
    await _syncEngine.applyLocalOperation(operation);
  }

  /// Get paired devices
  Future<List<PairedDevice>> getPairedDevices() async {
    return await _authService.getPairedDevices();
  }

  /// Initiate device pairing with QR code
  Future<DevicePairing> initiatePairingWithQR(String remoteDeviceId) async {
    return await _authService.initiatePairingWithQR(
      remoteDeviceId,
      PairingMethod.qrCode,
    );
  }

  /// Initiate device pairing with PIN
  Future<DevicePairing> initiatePairingWithPIN(String remoteDeviceId) async {
    return await _authService.initiatePairingWithPIN(remoteDeviceId);
  }

  /// Process scanned QR code for pairing
  Future<DevicePairing> processScannedQR(String qrData) async {
    return await _authService.processScannedQR(qrData);
  }

  // Private methods

  /// Load device information
  Future<void> _loadDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceInfoJson = prefs.getString(_keyDeviceInfo);
    
    if (deviceInfoJson != null) {
      try {
        final deviceInfoMap = jsonDecode(deviceInfoJson) as Map<String, dynamic>;
        _localDeviceInfo = DeviceInfo.fromJson(deviceInfoMap);
        return;
      } catch (e) {
        debugPrint('Error loading device info: $e');
      }
    }
    
    // Create new device info
    await _createDeviceInfo();
  }

  /// Create new device information
  Future<void> _createDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceName = 'BizSync Device';
    String deviceType = 'unknown';
    String platform = 'unknown';
    
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        deviceType = 'mobile';
        platform = 'android';
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final linuxInfo = await deviceInfoPlugin.linuxInfo;
        deviceName = linuxInfo.name;
        deviceType = 'desktop';
        platform = 'linux';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
    
    _localDeviceInfo = DeviceInfo(
      deviceId: _authService.deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
      platform: platform,
      appVersion: '1.0.0',
      lastSeen: DateTime.now(),
      isOnline: true,
      supportedTransports: ['bluetooth', 'wifiDirect', 'mdns'],
    );
    
    // Save device info
    final prefs = await SharedPreferences.getInstance();
    final deviceInfoJson = jsonEncode(_localDeviceInfo!.toJson());
    await prefs.setString(_keyDeviceInfo, deviceInfoJson);
  }

  /// Initialize available transports
  Future<void> _initializeTransports() async {
    // Register transport factories
    P2PTransportFactory.registerTransport(
      TransportType.bluetooth,
      () => BluetoothTransport(),
    );
    
    P2PTransportFactory.registerTransport(
      TransportType.wifiDirect,
      () => WiFiDirectTransport(),
    );
    
    P2PTransportFactory.registerTransport(
      TransportType.mdns,
      () => MDNSTransport(),
    );
    
    // Initialize available transports
    final availableTypes = await P2PTransportFactory.getAvailableTransports();
    
    for (final transportType in availableTypes) {
      final transport = P2PTransportFactory.createTransport(transportType);
      if (transport != null) {
        await transport.initialize();
        _transports[transportType] = transport;
        debugPrint('Initialized transport: $transportType');
      }
    }
  }

  /// Set up message handling between transports and sync engine
  void _setupMessageHandling() {
    for (final transport in _transports.values) {
      // Listen to incoming data
      transport.receiveData().listen((packet) {
        _handleIncomingData(packet);
      });
      
      // Listen to connection state changes
      transport.connectionStateChanges().listen((connection) {
        _connectionController.add(connection);
      });
    }
  }

  /// Start discovery on a specific transport
  void _startTransportDiscovery(P2PTransport transport, Duration timeout) {
    transport.startDiscovery(timeout: timeout).listen(
      (device) {
        _discoveryController.add(device);
      },
      onError: (error) {
        debugPrint('Discovery error on ${transport.transportType}: $error');
      },
    );
  }

  /// Handle incoming data packets
  void _handleIncomingData(P2PDataPacket packet) async {
    try {
      // Parse sync message
      final message = _parseSyncMessage(packet.data);
      
      switch (message.type) {
        case SyncMessageType.syncRequest:
          await _handleSyncRequest(message, packet.senderId);
          break;
        case SyncMessageType.dataChunk:
          await _handleDataChunk(message, packet.senderId);
          break;
        case SyncMessageType.acknowledgment:
          await _handleAcknowledgment(message);
          break;
        default:
          debugPrint('Unhandled sync message type: ${message.type}');
      }
      
    } catch (e) {
      debugPrint('Error handling incoming data: $e');
    }
  }

  /// Parse sync message from data
  SyncMessage _parseSyncMessage(Uint8List data) {
    final json = utf8.decode(data);
    final messageMap = jsonDecode(json) as Map<String, dynamic>;
    return SyncMessage.fromJson(messageMap);
  }

  /// Handle sync request message
  Future<void> _handleSyncRequest(SyncMessage message, String fromDeviceId) async {
    // Implementation would handle incoming sync requests
    debugPrint('Received sync request from: $fromDeviceId');
  }

  /// Handle data chunk message
  Future<void> _handleDataChunk(SyncMessage message, String fromDeviceId) async {
    // Implementation would handle incoming data chunks
    debugPrint('Received data chunk from: $fromDeviceId');
  }

  /// Handle acknowledgment message
  Future<void> _handleAcknowledgment(SyncMessage message) async {
    // Implementation would handle acknowledgments
    debugPrint('Received acknowledgment: ${message.messageId}');
  }

  /// Get all active connections across all transports
  List<P2PConnection> _getActiveConnections() {
    final connections = <P2PConnection>[];
    
    for (final transport in _transports.values) {
      connections.addAll(transport.getActiveConnections());
    }
    
    return connections;
  }

  /// Set up connection monitoring
  void _setupConnectionMonitoring(P2PConnection connection) {
    // Monitor connection health and handle disconnections
    // Implementation would set up periodic health checks
  }

  /// Set session timeout
  void _setSessionTimeout(String sessionId) {
    _sessionTimers[sessionId]?.cancel();
    
    _sessionTimers[sessionId] = Timer(_sessionTimeout, () {
      final session = _activeSessions[sessionId];
      if (session?.state == SyncSessionState.active) {
        cancelSyncSession(sessionId);
      }
    });
  }

  /// Notify session participants
  Future<void> _notifySessionParticipants(SyncSession session) async {
    // Implementation would send session start notifications
    debugPrint('Notifying session participants: ${session.participantDeviceIds}');
  }

  /// Notify session cancellation
  Future<void> _notifySessionCancellation(SyncSession session) async {
    // Implementation would send session cancellation notifications
    debugPrint('Notifying session cancellation: ${session.sessionId}');
  }

  /// Parse transport type from string
  TransportType _parseTransportType(String transportName) {
    switch (transportName.toLowerCase()) {
      case 'bluetooth':
        return TransportType.bluetooth;
      case 'wifidirect':
        return TransportType.wifiDirect;
      case 'mdns':
        return TransportType.mdns;
      default:
        return TransportType.bluetooth; // Default fallback
    }
  }
}